/*
================================================================================================
 CLASS NAME   : IndiaMartKeywordHandler
 PURPOSE      : Entry point called from LeadTrigger (after insert / after update).

 WHAT THIS CLASS DOES:
   1. Checks the kill-switch flag "isTrigger_Active__c" on the first record of
      Custom Metadata Type "IndiaMART_Department_Verification__mdt".
      - If false -> entire feature is skipped, nothing runs.
      - If true  -> processing continues.
   2. Filters ONLY the leads present in the current trigger context (Trigger.new).
      No SOQL is done against the whole Lead table - bulkification safe.
      A lead is eligible when:
         - LeadSource = 'INDIAMART' OR 'INDIAMART V2'
         - AND (it is a brand new Insert) OR (Product_to_Purchase__c value changed on Update)
      NOTE: is_Already_Fired_IndiaMart__c does NOT block re-processing.
            If Product_to_Purchase__c changes again later, the lead is re-evaluated,
            even if it was already fired before. The checkbox is only an audit marker.
   3. Kicks off Batch Apex (NOT Queueable) for the eligible Lead Ids.
      Batch is used (with a small scope size) instead of Queueable purely because of the
      Salesforce Callout Governor Limit (100 callouts per transaction). Each lead may need
      up to ~9 Prompt Builder callouts (one per keyword group, worst case = no match found).
      A manual single Lead insert is fine either way, but a Data Loader bulk load (200 leads
      per batch) could easily cross 100 callouts in one shot if not chunked. Batch Apex lets
      us control the chunk size (scope), so each execute() call always stays under the limit.
================================================================================================
*/
/*public with sharing class IndiaMartKeywordHandler {

    // LeadSource values that qualify for this automation
    private static final Set<String> INDIAMART_SOURCES = new Set<String>{ 'INDIAMART V2', 'INDIAMART' };

    // Batch chunk size - kept small so callouts per execute() never cross the 100/transaction limit
    private static final Integer BATCH_SCOPE_SIZE = 5;


    public static void handleAfterSave(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        System.debug('=== IndiaMartKeywordHandler.handleAfterSave START | totalLeadsInContext=' + newLeads.size() + ' ===');

        try {
            // STEP 1: Kill-switch check from Custom Metadata
            IndiaMART_Department_Verification__mdt configRecord = getActiveConfigRecord();
            if (configRecord == null) {
                System.debug('IndiaMartKeywordHandler.handleAfterSave --- isTrigger_Active__c is FALSE or no CMDT record found. Skipping entirely.');
                return;
            }
            System.debug('IndiaMartKeywordHandler.handleAfterSave --- Active CMDT record found: ' + configRecord.DeveloperName);

            // STEP 2: Filter only eligible leads from Trigger.new (never query the whole Lead table)
            List<Id> eligibleLeadIds = new List<Id>();
            Boolean isInsertContext = (oldMap == null);

            for (Lead ld : newLeads) {
                if (!INDIAMART_SOURCES.contains(ld.LeadSource)) {
                    continue;
                }

                if (isInsertContext) {
                    // Brand new lead - always eligible if source matches
                    eligibleLeadIds.add(ld.Id);
                } else {
                    // Update context - only eligible if Product_to_Purchase__c actually changed
                    // (re-fires even if is_Already_Fired_IndiaMart__c was already true)
                    Lead oldLd = oldMap.get(ld.Id);
                    if (oldLd.Product_to_Purchase__c != ld.Product_to_Purchase__c) {
                        eligibleLeadIds.add(ld.Id);
                    }
                }
            }

            System.debug('IndiaMartKeywordHandler.handleAfterSave --- Eligible Lead Ids: ' + eligibleLeadIds);

            if (eligibleLeadIds.isEmpty()) {
                System.debug('IndiaMartKeywordHandler.handleAfterSave --- No eligible leads. Exiting without starting batch.');
                return;
            }

            // STEP 3: Kick off Batch Apex (handles callouts safely in small chunks)
            Database.executeBatch(new IndiaMartKeywordBatch(eligibleLeadIds), BATCH_SCOPE_SIZE);
            System.debug('IndiaMartKeywordHandler.handleAfterSave --- Batch job started for ' + eligibleLeadIds.size() + ' lead(s), scope size=' + BATCH_SCOPE_SIZE);

        } catch (Exception ex) {
            // Any failure here must NEVER break the Lead insert/update itself
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordHandler.handleAfterSave --- EXCEPTION: ' + ex.getMessage()
                + ' | Line=' + ex.getLineNumber() + ' | StackTrace=' + ex.getStackTraceString());
        }

        System.debug('=== IndiaMartKeywordHandler.handleAfterSave END ===');
    }


    private static IndiaMART_Department_Verification__mdt getActiveConfigRecord() {
        try {
            List<IndiaMART_Department_Verification__mdt> configs = [
                SELECT Id, DeveloperName, isTrigger_Active__c
                FROM IndiaMART_Department_Verification__mdt
                ORDER BY DeveloperName ASC
                LIMIT 1
            ];

            System.debug('IndiaMartKeywordHandler.getActiveConfigRecord --- CMDT query result: ' + configs);

            if (configs.isEmpty() || configs[0].isTrigger_Active__c != true) {
                return null;
            }
            return configs[0];

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordHandler.getActiveConfigRecord --- EXCEPTION: ' + ex.getMessage());
            return null;
        }
    }
}*/
/*
================================================================================================
 CLASS NAME   : IndiaMartKeywordHandler
 PURPOSE      : Entry point called from LeadTrigger (after insert / after update).

 WHAT THIS CLASS DOES:
   1. Checks the kill-switch flag "isTrigger_Active__c" on the first record of
      Custom Metadata Type "IndiaMART_Department_Verification__mdt".
      - If false -> entire feature is skipped, nothing runs.
      - If true  -> processing continues.
   2. Filters ONLY the leads present in the current trigger context (Trigger.new).
      No SOQL is done against the whole Lead table - bulkification safe.
      A lead is eligible when:
         - LeadSource = 'INDIAMART' OR 'INDIAMART V2'
         - AND (it is a brand new Insert)
               OR (on Update: Product_to_Purchase__c value changed
                   OR is_Already_Fired_IndiaMart__c is still false)
      NOTE: is_Already_Fired_IndiaMart__c does NOT block re-processing on its own.
            If Product_to_Purchase__c changes again later, the lead is re-evaluated,
            even if it was already fired before. It is also re-evaluated on any update
            as long as it has never been successfully fired yet, even if the
            Product_to_Purchase__c text itself hasn't changed. The checkbox is only
            an audit marker of "was this lead ever successfully processed".
   3. Kicks off Batch Apex (NOT Queueable) for the eligible Lead Ids.
      Batch is used (with a small scope size) instead of Queueable purely because of the
      Salesforce Callout Governor Limit (100 callouts per transaction). Each lead may need
      up to ~9 Prompt Builder callouts (one per keyword group, worst case = no match found).
      A manual single Lead insert is fine either way, but a Data Loader bulk load (200 leads
      per batch) could easily cross 100 callouts in one shot if not chunked. Batch Apex lets
      us control the chunk size (scope), so each execute() call always stays under the limit.
================================================================================================
*/
public without sharing class IndiaMartKeywordHandler {

    // LeadSource values that qualify for this automation
    private static final Set<String> INDIAMART_SOURCES = new Set<String>{ 'INDIAMART V2', 'INDIAMART' };

    // Batch chunk size - kept small so callouts per execute() never cross the 100/transaction limit
    private static final Integer BATCH_SCOPE_SIZE = 5;

    /*
    --------------------------------------------------------------------------------------------
     METHOD: handleAfterSave
     Called directly from LeadTrigger (after insert / after update).
     Decides IF this automation should run at all, and WHICH leads qualify.
    --------------------------------------------------------------------------------------------
    */
    public static void handleAfterSave(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        System.debug('=== IndiaMartKeywordHandler.handleAfterSave START | totalLeadsInContext=' + newLeads.size() + ' ===');

        try {
            // STEP 1: Kill-switch check from Custom Metadata
            IndiaMART_Department_Verification__mdt configRecord = getActiveConfigRecord();
            if (configRecord == null) {
                System.debug('IndiaMartKeywordHandler.handleAfterSave --- isTrigger_Active__c is FALSE or no CMDT record found. Skipping entirely.');
                return;
            }
            System.debug('IndiaMartKeywordHandler.handleAfterSave --- Active CMDT record found: ' + configRecord.DeveloperName);

            // STEP 2: Filter only eligible leads from Trigger.new (never query the whole Lead table)
            List<Id> eligibleLeadIds = new List<Id>();
            Boolean isInsertContext = (oldMap == null);

            for (Lead ld : newLeads) {
                if (!INDIAMART_SOURCES.contains(ld.LeadSource)) {
                    continue;
                }

                if (isInsertContext) {
                    // Brand new lead - always eligible if source matches
                    eligibleLeadIds.add(ld.Id);
                } else {
                    // Update context - eligible if:
                    //   a) Product_to_Purchase__c actually changed, OR
                    //   b) it was never successfully fired yet (is_Already_Fired_IndiaMart__c = false),
                    //      even if the description text is unchanged
                    Lead oldLd = oldMap.get(ld.Id);
                    Boolean descriptionChanged = oldLd.Product_to_Purchase__c != ld.Product_to_Purchase__c;
                    Boolean notYetFired = ld.is_Already_Fired_IndiaMart__c != true;

                    if (descriptionChanged || notYetFired) {
                        eligibleLeadIds.add(ld.Id);
                        System.debug('IndiaMartKeywordHandler.handleAfterSave --- Eligible LeadId=' + ld.Id
                            + ' | descriptionChanged=' + descriptionChanged + ' | notYetFired=' + notYetFired);
                    }
                }
            }

            System.debug('IndiaMartKeywordHandler.handleAfterSave --- Eligible Lead Ids: ' + eligibleLeadIds);

            if (eligibleLeadIds.isEmpty()) {
                System.debug('IndiaMartKeywordHandler.handleAfterSave --- No eligible leads. Exiting without starting batch.');
                return;
            }

            // STEP 3: Kick off Batch Apex (handles callouts safely in small chunks)
            Database.executeBatch(new IndiaMartKeywordBatch(eligibleLeadIds), BATCH_SCOPE_SIZE);
            System.debug('IndiaMartKeywordHandler.handleAfterSave --- Batch job started for ' + eligibleLeadIds.size() + ' lead(s), scope size=' + BATCH_SCOPE_SIZE);

        } catch (Exception ex) {
            // Any failure here must NEVER break the Lead insert/update itself
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordHandler.handleAfterSave --- EXCEPTION: ' + ex.getMessage()
                + ' | Line=' + ex.getLineNumber() + ' | StackTrace=' + ex.getStackTraceString());
        }

        System.debug('=== IndiaMartKeywordHandler.handleAfterSave END ===');
    }

    /*
    --------------------------------------------------------------------------------------------
     METHOD: getActiveConfigRecord
     Fetches the first IndiaMART_Department_Verification__mdt record and checks the
     isTrigger_Active__c checkbox. Returns null if the feature should not run.
    --------------------------------------------------------------------------------------------
    */
    private static IndiaMART_Department_Verification__mdt getActiveConfigRecord() {
        try {
            List<IndiaMART_Department_Verification__mdt> configs = [
                SELECT Id, DeveloperName, isTrigger_Active__c
                FROM IndiaMART_Department_Verification__mdt
                ORDER BY DeveloperName ASC
                LIMIT 1
            ];

            System.debug('IndiaMartKeywordHandler.getActiveConfigRecord --- CMDT query result: ' + configs);

            if (configs.isEmpty() || configs[0].isTrigger_Active__c != true) {
                return null;
            }
            return configs[0];

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IndiaMartKeywordHandler.getActiveConfigRecord --- EXCEPTION: ' + ex.getMessage());
            return null;
        }
    }
}