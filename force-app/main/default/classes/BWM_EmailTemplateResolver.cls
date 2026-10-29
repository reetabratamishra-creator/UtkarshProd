/**
 * @description   Resolves BWM_Email_Template_Mapping__mdt for Lead/Opportunity email
 *                trigger points.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailTemplateResolver {
  private static Map<String, List<BWM_Email_Template_Mapping__mdt>> mappingsByTriggerPoint =
    new Map<String, List<BWM_Email_Template_Mapping__mdt>>();

  public class ResolveResult {
    public BWM_Email_Template_Mapping__mdt mapping;
    public Boolean shouldSend = false;
    public String skipReason;
  }

  public static ResolveResult resolve(String triggerPoint, SObject record) {
    return resolve(triggerPoint, record, null);
  }

  public static ResolveResult resolve(
    String triggerPoint,
    SObject record,
    String stageAtAction
  ) {
    ResolveResult result = new ResolveResult();

    if (String.isBlank(triggerPoint)) {
      result.skipReason = 'Trigger point is required.';
      return result;
    }
    if (record == null) {
      result.skipReason = 'Record is null.';
      return result;
    }

    if (triggerPoint == BWM_EmailConstants.TRIGGER_LEAD_CREATE) {
      return resolveForLeadCreate((Lead) record);
    }

    String validationMessage = validateRecordForTrigger(
      triggerPoint,
      record,
      stageAtAction
    );
    if (String.isNotBlank(validationMessage)) {
      result.skipReason = validationMessage;
      return result;
    }

    String departmentName = resolveDepartmentName(record);
    List<BWM_Email_Template_Mapping__mdt> mappings = queryAllMappings(
      triggerPoint
    );
    if (mappings.isEmpty()) {
      result.skipReason = 'No active email template mapping found.';
      return result;
    }

    BWM_Email_Template_Mapping__mdt mapping = selectMapping(
      mappings,
      record,
      departmentName,
      null
    );
    if (mapping != null) {
      result.mapping = mapping;
      result.shouldSend = true;
      return result;
    }

    result.skipReason =
      'No active email mapping matched this department: ' +
      String.valueOf(departmentName);
    return result;
  }

  private static String resolveDepartmentName(SObject record) {
    if (record instanceof Lead) {
      return ((Lead) record).Department_Name__c;
    }
    if (record instanceof Opportunity) {
      return ((Opportunity) record).Department_Name__c;
    }
    return null;
  }

  public static ResolveResult resolveForLeadCreate(Lead leadRecord) {
    ResolveResult result = new ResolveResult();

    if (leadRecord == null) {
      result.skipReason = 'Lead record is null.';
      return result;
    }
    if (leadRecord.Status != BWM_EmailConstants.STAGE_PROSPECT) {
      result.skipReason = 'Lead stage is not Prospect.';
      return result;
    }

    List<BWM_Email_Template_Mapping__mdt> mappings = queryAllMappings(
      BWM_EmailConstants.TRIGGER_LEAD_CREATE
    );
    BWM_Email_Template_Mapping__mdt mapping = selectLeadCreateMapping(
      mappings,
      leadRecord
    );
    if (mapping != null) {
      result.mapping = mapping;
      result.shouldSend = true;
      return result;
    }

    result.skipReason = 'No active email mapping matched this lead.';
    return result;
  }

  private static List<BWM_Email_Template_Mapping__mdt> queryAllMappings(
    String triggerPoint
  ) {
    if (mappingsByTriggerPoint.containsKey(triggerPoint)) {
      return mappingsByTriggerPoint.get(triggerPoint);
    }

    List<BWM_Email_Template_Mapping__mdt> mappings = [
      SELECT
        Trigger_Point__c,
        Object_Type__c,
        Record_Stage__c,
        Lead_Source__c,
        Department_Mode__c,
        Department_Value__c,
        Lost_Reason__c,
        Lost_Reason_Group__c,
        Template_Name__c,
        Template_Id__c,
        Sender_Type__c,
        Recipient_Type__c,
        Subject_Template__c,
        Body_Template__c,
        Delay_Hours__c,
        Is_Active__c,
        Priority__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Brochure_Attachment_Mode__c
      FROM BWM_Email_Template_Mapping__mdt
      WHERE Is_Active__c = TRUE AND Trigger_Point__c = :triggerPoint
      ORDER BY Priority__c ASC NULLS LAST
    ];
    mappingsByTriggerPoint.put(triggerPoint, mappings);
    return mappings;
  }

  private static BWM_Email_Template_Mapping__mdt queryMappingForTriggerPoint(
    String triggerPoint
  ) {
    List<BWM_Email_Template_Mapping__mdt> mappings = queryAllMappings(
      triggerPoint
    );
    return mappings.isEmpty() ? null : mappings[0];
  }

  private static String validateRecordForTrigger(
    String triggerPoint,
    SObject record,
    String stageAtAction
  ) {
    if (record instanceof Lead) {
      return validateLeadTrigger(triggerPoint, (Lead) record, stageAtAction);
    }
    if (record instanceof Opportunity) {
      return validateOpportunityTrigger(triggerPoint, (Opportunity) record);
    }
    if (record instanceof Account) {
      return validateAccountTrigger(triggerPoint);
    }
    return 'Unsupported object type.';
  }

  private static String validateLeadTrigger(
    String triggerPoint,
    Lead leadRecord,
    String stageAtAction
  ) {
    if (
      triggerPoint == BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT &&
      !isLeadStageForCallbackTrigger(
        leadRecord,
        BWM_EmailConstants.STAGE_PROSPECT,
        stageAtAction
      )
    ) {
      return 'Lead stage must be Prospect.';
    }
    if (
      triggerPoint == BWM_EmailConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING &&
      !isLeadStageForCallbackTrigger(
        leadRecord,
        BWM_EmailConstants.STAGE_PROSPECTING,
        stageAtAction
      )
    ) {
      return 'Lead stage must be Prospecting.';
    }
    if (
      triggerPoint ==
      BWM_EmailConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING &&
      leadRecord.Status != BWM_EmailConstants.STAGE_PROSPECT &&
      leadRecord.Status != BWM_EmailConstants.STAGE_PROSPECTING
    ) {
      return 'Lead stage must be Prospect or Prospecting for details-not-received email.';
    }
    if (triggerPoint.contains('Prospect') && !triggerPoint.contains('Prospecting')) {
      if (
        triggerPoint.contains('Lost') &&
        leadRecord.Status != BWM_EmailConstants.STAGE_PROSPECT &&
        leadRecord.Status != 'Lost'
      ) {
        return 'Lead stage must be Prospect for lost email.';
      }
    }
    if (triggerPoint.contains('Prospecting')) {
      if (
        triggerPoint.contains('Lost') &&
        leadRecord.Status != BWM_EmailConstants.STAGE_PROSPECTING &&
        leadRecord.Status != 'Lost'
      ) {
        return 'Lead stage must be Prospecting for lost email.';
      }
    }
    return validateLostReasonForTrigger(
      triggerPoint,
      leadRecord.Lost_Reason__c,
      false
    );
  }

  private static Boolean isLeadStageForCallbackTrigger(
    Lead leadRecord,
    String expectedStage,
    String stageAtAction
  ) {
    if (leadRecord.Status == expectedStage) {
      return true;
    }

    return String.isNotBlank(stageAtAction) && stageAtAction == expectedStage;
  }

  private static String validateOpportunityTrigger(
    String triggerPoint,
    Opportunity opportunityRecord
  ) {
    if (triggerPoint == BWM_EmailConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_NURTURE) {
        return 'Opportunity stage must be Nurture.';
      }
    }
    if (
      triggerPoint ==
      BWM_EmailConstants.TRIGGER_OPPORTUNITY_DETAILS_NOT_RECEIVED_NURTURE &&
      opportunityRecord.StageName != BWM_EmailConstants.STAGE_NURTURE
    ) {
      return 'Opportunity stage must be Nurture for details-not-received email.';
    }
    if (triggerPoint == BWM_EmailConstants.TRIGGER_OPPORTUNITY_DEALER_ENQUIRY) {
      if (
        !isDealerEnquiryEligibleDepartment(opportunityRecord.Department_Name__c)
      ) {
        return 'Department must be Enquiry or a gen/tower department.';
      }
      if (
        !BWM_EmailConstants.PHONE_OPPORTUNITY_SOURCES.contains(
          opportunityRecord.LeadSource
        ) &&
        opportunityRecord.LeadSource !=
        BWM_EmailConstants.OPP_SOURCE_INBOUND_EMAIL
      ) {
        return 'Lead source must be phone call or inbound email.';
      }
    }
    if (triggerPoint.contains('_Nurture') && triggerPoint.contains('Lost')) {
      if (
        opportunityRecord.StageName != BWM_EmailConstants.STAGE_NURTURE &&
        opportunityRecord.StageName != BWM_EmailConstants.STAGE_CLOSED_LOST
      ) {
        return 'Opportunity stage must be Nurture for lost email.';
      }
    }
    if (
      triggerPoint.contains('_Negotiation') &&
      triggerPoint.contains('Lost')
    ) {
      if (
        opportunityRecord.StageName != BWM_EmailConstants.STAGE_NEGOTIATION &&
        opportunityRecord.StageName != BWM_EmailConstants.STAGE_CLOSED_LOST
      ) {
        return 'Opportunity stage must be Negotiation for lost email.';
      }
    }
    if (
      triggerPoint == BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_TENDER_UPDATE
    ) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_NEGOTIATION) {
        return 'Opportunity stage must be Negotiation.';
      }
      if (opportunityRecord.Sub_Stage__c != BWM_EmailConstants.SUB_STAGE_TENDER) {
        return 'Sub Stage must be Tender.';
      }
    }
    if (
      triggerPoint == BWM_EmailConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS
    ) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_NEGOTIATION) {
        return 'Opportunity stage must be Negotiation.';
      }
      if (
        opportunityRecord.Sub_Stage__c != BWM_EmailConstants.SUB_STAGE_ACTIVE &&
        opportunityRecord.Sub_Stage__c != BWM_EmailConstants.SUB_STAGE_BUDGETARY
      ) {
        return 'Sub Stage must be Active or Budgetary.';
      }
    }
    if (triggerPoint == BWM_EmailConstants.TRIGGER_OPP_TASK_CALLBACK_NEGOTIATION) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_NEGOTIATION) {
        return 'Opportunity stage must be Negotiation.';
      }
    }
    if (triggerPoint == BWM_EmailConstants.TRIGGER_OPP_TASK_CALLBACK_NURTURE) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_NURTURE) {
        return 'Opportunity stage must be Nurture.';
      }
    }
    if (
      triggerPoint == BWM_EmailConstants.TRIGGER_OPP_NEGOTIATION_STAGE_UPDATE
    ) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_NEGOTIATION) {
        return 'Opportunity stage must be Negotiation.';
      }
      if (
        opportunityRecord.Customer_Journey__c !=
        BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
      ) {
        return 'Customer Journey must be Direct Business.';
      }
      if (
        opportunityRecord.Sub_Stage__c != BWM_EmailConstants.SUB_STAGE_ACTIVE &&
        opportunityRecord.Sub_Stage__c != BWM_EmailConstants.SUB_STAGE_BUDGETARY
      ) {
        return 'Sub Stage must be Active or Budgetary.';
      }
    }
    if (
      triggerPoint == BWM_EmailConstants.TRIGGER_OPP_CLOSED_WON_REFER_DEALER
    ) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_CLOSED_WON) {
        return 'Opportunity stage must be Closed Won.';
      }
      if (
        opportunityRecord.Customer_Journey__c !=
        BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
      ) {
        return 'Customer Journey must be Refer to Dealer.';
      }
    }
    if (
      triggerPoint == BWM_EmailConstants.TRIGGER_OPP_CLOSED_WON_DIRECT_BUSINESS
    ) {
      if (opportunityRecord.StageName != BWM_EmailConstants.STAGE_CLOSED_WON) {
        return 'Opportunity stage must be Closed Won.';
      }
      if (
        opportunityRecord.Customer_Journey__c !=
        BWM_EmailConstants.CUSTOMER_JOURNEY_DIRECT
      ) {
        return 'Customer Journey must be Direct Business.';
      }
    }
    if (triggerPoint == BWM_EmailConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER) {
      if (
        opportunityRecord.Customer_Journey__c !=
        BWM_EmailConstants.CUSTOMER_JOURNEY_REFER_DEALER
      ) {
        return 'Customer Journey must be Refer to Dealer.';
      }
      if (opportunityRecord.DealerAccount__c == null) {
        return 'Dealer account is required.';
      }
    }
    if (triggerPoint == BWM_EmailConstants.TRIGGER_OPP_QUOTE_EXPIRY_REMINDER) {
      if (opportunityRecord.IsClosed) {
        return 'Opportunity must be open.';
      }
      if (opportunityRecord.Quotation_Date__c == null) {
        return 'Quotation Date is required.';
      }
      return null;
    }
    return validateLostReasonForTrigger(
      triggerPoint,
      opportunityRecord.Lost_Reason__c,
      true
    );
  }

  private static String validateAccountTrigger(String triggerPoint) {
    if (triggerPoint != BWM_EmailConstants.TRIGGER_DEALER_MONTHLY_UPDATE) {
      return 'Unsupported account trigger point.';
    }
    return null;
  }

  private static String validateLostReasonForTrigger(
    String triggerPoint,
    String lostReason,
    Boolean isOpportunity
  ) {
    if (!triggerPoint.contains('Lost')) {
      return null;
    }

    BWM_Email_Template_Mapping__mdt mapping = queryMappingForTriggerPoint(
      triggerPoint
    );
    if (mapping == null) {
      return null;
    }

    if (String.isNotBlank(mapping.Lost_Reason__c)) {
      if (mapping.Lost_Reason__c != lostReason) {
        return 'Lost reason does not match template mapping.';
      }
      return null;
    }

    if (String.isNotBlank(mapping.Lost_Reason_Group__c)) {
      Map<String, Set<String>> groups = isOpportunity
        ? BWM_EmailConstants.OPP_LOST_REASONS_BY_GROUP
        : BWM_EmailConstants.LOST_REASONS_BY_GROUP;
      Set<String> allowed = groups.get(mapping.Lost_Reason_Group__c);
      if (allowed == null || !allowed.contains(lostReason)) {
        return 'Lost reason does not match template group.';
      }
    }
    return null;
  }

  private static BWM_Email_Template_Mapping__mdt selectLeadCreateMapping(
    List<BWM_Email_Template_Mapping__mdt> mappings,
    Lead leadRecord
  ) {
    String departmentName = leadRecord.Department_Name__c;

    for (BWM_Email_Template_Mapping__mdt mapping : mappings) {
      if (!matchesLeadSourceFilter(mapping, leadRecord)) {
        continue;
      }
      if (matchesDepartment(mapping, departmentName)) {
        return mapping;
      }
    }

    return null;
  }

  private static BWM_Email_Template_Mapping__mdt selectMapping(
    List<BWM_Email_Template_Mapping__mdt> mappings,
    SObject record,
    String departmentName,
    Lead leadForSourceCheck
  ) {
    if (shouldPreferGeneralTemplate(record, departmentName)) {
      for (BWM_Email_Template_Mapping__mdt mapping : mappings) {
        if (isProductDeptMapping(mapping)) {
          continue;
        }
        if (
          mapping.Department_Mode__c == BWM_EmailConstants.DEPT_MODE_ENQUIRY_ONLY
        ) {
          continue;
        }
        if (
          leadForSourceCheck != null &&
          !matchesLeadSourceFilter(mapping, leadForSourceCheck)
        ) {
          continue;
        }
        if (isGeneralMapping(mapping)) {
          return mapping;
        }
      }
    }

    for (BWM_Email_Template_Mapping__mdt mapping : mappings) {
      if (
        leadForSourceCheck != null &&
        !matchesLeadSourceFilter(mapping, leadForSourceCheck)
      ) {
        continue;
      }
      if (matchesDepartment(mapping, departmentName)) {
        return mapping;
      }
    }

    return null;
  }

  private static Boolean shouldPreferGeneralTemplate(
    SObject record,
    String departmentName
  ) {
    if (!isProductDepartment(departmentName)) {
      return false;
    }
    return ownerMatchesCrmUserName(record);
  }

  private static Boolean isProductDepartment(String departmentName) {
    return String.isNotBlank(departmentName) &&
      BWM_EmailConstants.PRODUCT_DEPARTMENTS.contains(departmentName);
  }

  private static Boolean ownerMatchesCrmUserName(SObject record) {
    if (record == null) {
      return false;
    }

    String crmUserName;
    String ownerName;

    if (record instanceof Lead) {
      Lead leadRecord = (Lead) record;
      crmUserName = leadRecord.CRM_User_Name_Formula__c;
      ownerName = leadRecord.Owner == null ? null : leadRecord.Owner.Name;
    } else if (record instanceof Opportunity) {
      Opportunity opportunityRecord = (Opportunity) record;
      crmUserName = opportunityRecord.CRM_User_Name_Formula__c;
      ownerName = opportunityRecord.Owner == null
        ? null
        : opportunityRecord.Owner.Name;
    } else {
      return false;
    }

    return String.isNotBlank(crmUserName) &&
      String.isNotBlank(ownerName) &&
      crmUserName.trim().equalsIgnoreCase(ownerName.trim());
  }

  private static Boolean isProductDeptMapping(
    BWM_Email_Template_Mapping__mdt mapping
  ) {
    String mode = mapping.Department_Mode__c;
    return mode == BWM_EmailConstants.DEPT_MODE_PRODUCT_DEPT ||
      mode == BWM_EmailConstants.DEPT_MODE_ANY_PRODUCT;
  }

  private static Boolean isGeneralMapping(
    BWM_Email_Template_Mapping__mdt mapping
  ) {
    String mode = mapping.Department_Mode__c;
    return mode == BWM_EmailConstants.DEPT_MODE_GEN_TOWER ||
      mode == BWM_EmailConstants.DEPT_MODE_GEN_ENQUIRY_TOWER ||
      mode == BWM_EmailConstants.DEPT_MODE_ALL ||
      mode == BWM_EmailConstants.DEPT_MODE_ENQUIRY_ONLY;
  }

  private static Boolean matchesLeadSourceFilter(
    BWM_Email_Template_Mapping__mdt mapping,
    Lead leadRecord
  ) {
    return String.isBlank(mapping.Lead_Source__c) ||
      mapping.Lead_Source__c == leadRecord.LeadSource;
  }

  private static Boolean isDealerEnquiryEligibleDepartment(String departmentName) {
    return departmentName == BWM_EmailConstants.DEPT_ENQUIRY ||
      BWM_EmailConstants.GEN_TOWER_DEPARTMENTS.contains(departmentName);
  }

  private static Boolean matchesDepartment(
    BWM_Email_Template_Mapping__mdt mapping,
    String departmentName
  ) {
    String mode = mapping.Department_Mode__c;
    if (String.isBlank(mode) || mode == BWM_EmailConstants.DEPT_MODE_ALL) {
      return true;
    }
    if (mode == BWM_EmailConstants.DEPT_MODE_ENQUIRY_ONLY) {
      return departmentName == BWM_EmailConstants.DEPT_ENQUIRY;
    }
    if (
      mode == BWM_EmailConstants.DEPT_MODE_ANY_PRODUCT ||
      mode == BWM_EmailConstants.DEPT_MODE_PRODUCT_DEPT
    ) {
      return String.isNotBlank(departmentName) &&
        BWM_EmailConstants.PRODUCT_DEPARTMENTS.contains(departmentName);
    }
    if (mode == BWM_EmailConstants.DEPT_MODE_GEN_TOWER) {
      return String.isNotBlank(departmentName) &&
        BWM_EmailConstants.GEN_TOWER_DEPARTMENTS.contains(departmentName);
    }
    if (mode == BWM_EmailConstants.DEPT_MODE_GEN_ENQUIRY_TOWER) {
      return String.isNotBlank(departmentName) &&
        BWM_EmailConstants.GEN_ENQUIRY_TOWER_DEPARTMENTS.contains(departmentName);
    }
    if (mode == 'SPECIFIC') {
      return departmentName == mapping.Department_Value__c;
    }
    return true;
  }
}