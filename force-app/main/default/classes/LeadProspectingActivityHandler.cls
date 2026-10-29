public with sharing class LeadProspectingActivityHandler {

    public static void updateProspectingActivityDate(
        List<Lead> newLeads,
        Map<Id, Lead> oldMap
    ){

        System.debug('===== START LeadProspectingActivityHandler =====');
        System.debug('Total Leads Received: ' + newLeads.size());
        System.debug('Old Map Is Null: ' + (oldMap == null));

        for(Lead ld : newLeads){

            System.debug('----------------------------------------');
            System.debug('Processing Lead Id: ' + ld.Id);
            System.debug('Lead Name: ' + ld.Name);
            System.debug('Current Status: ' + ld.Status);

            if(oldMap == null){

                System.debug('INSERT Operation Detected');

                if(ld.Status == 'Prospecting'){

                    System.debug('Lead inserted with Prospecting status');
                    System.debug('Setting Last_Prospecting_Activity__c to current datetime');

                    ld.Last_Prospecting_Activity__c = System.now();

                    System.debug('Last_Prospecting_Activity__c Updated To: '
                        + ld.Last_Prospecting_Activity__c);
                }
                else{

                    System.debug('Lead inserted but status is not Prospecting');
                    System.debug('No update required');
                }

                continue;
            }

            Lead oldLead = oldMap.get(ld.Id);

            System.debug('UPDATE Operation Detected');
            System.debug('Old Status: ' + oldLead.Status);
            System.debug('New Status: ' + ld.Status);

            if(
                oldLead.Status != 'Prospecting'
                &&
                ld.Status == 'Prospecting'
            ){

                System.debug('Lead moved INTO Prospecting status');

                ld.Last_Prospecting_Activity__c = System.now();

                System.debug('Updated Last_Prospecting_Activity__c: '
                    + ld.Last_Prospecting_Activity__c);

                ld.Prospecting_Escalation_24_Sent__c = false;
                System.debug('Reset Prospecting_Escalation_24_Sent__c to FALSE');

                ld.Prospecting_Escalation_48_Sent__c = false;
                System.debug('Reset Prospecting_Escalation_48_Sent__c to FALSE');

                ld.Prospecting_Escalation_72_Sent__c = false;
                System.debug('Reset Prospecting_Escalation_72_Sent__c to FALSE');
            }

            else if(
                oldLead.Status == 'Prospecting'
                &&
                ld.Status == 'Prospecting'
            ){

                System.debug('Lead remains in Prospecting status');
                System.debug('Updating Last_Prospecting_Activity__c');

                ld.Last_Prospecting_Activity__c = System.now();

                System.debug('New Last_Prospecting_Activity__c Value: '
                    + ld.Last_Prospecting_Activity__c);
            }
            else{

                System.debug('No Prospecting status change detected');
                System.debug('No field updates performed');
            }
        }

        System.debug('===== END LeadProspectingActivityHandler =====');
    }
}