/**
 * @description Verifies dealer_sales_assign WhatsApp Dear/header uses Dealer name
 *              and customer detail params are not overwritten by CRM secondary contact.
 */
@IsTest
private class BWM_DealerSalesAssignHeaderTest {
  @IsTest
  static void referToDealerHeaderUsesDealerAccountName() {
    BWM_Template_Mapping__mdt mapping = [
      SELECT
        WhatsApp_Header_Format__c,
        WhatsApp_Header_Value_Field__c,
        Recipient_Type__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Opportunity_Refer_To_Dealer'
      LIMIT 1
    ];

    System.assertEquals(
      'DealerAccount__r.Name',
      mapping.WhatsApp_Header_Value_Field__c,
      'Dear/header must map to Dealer Account Name.'
    );

    Account dealerAccount = new Account(
      Name = 'Expected Dealer Name ' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
    );
    Map<String, Schema.RecordTypeInfo> accountTypes = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    if (accountTypes.containsKey('Dealer')) {
      dealerAccount.RecordTypeId = accountTypes.get('Dealer').getRecordTypeId();
    } else if (accountTypes.containsKey('Dealer_Account')) {
      dealerAccount.RecordTypeId = accountTypes.get('Dealer_Account').getRecordTypeId();
    }
    insert as system dealerAccount;

    Account customerAccount = new Account(Name = 'Customer Co');
    insert as system customerAccount;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Refer Dealer Header Opp',
      AccountId = customerAccount.Id,
      StageName = BWM_MessagingConstants.STAGE_NURTURE,
      Customer_Journey__c = BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER,
      DealerAccount__c = dealerAccount.Id,
      Department_Name__c = 'Steel Pipes',
      CloseDate = Date.today().addDays(14)
    );
    insert as system opportunityRecord;
    opportunityRecord = BWM_RecordQueryService.queryOpportunity(opportunityRecord.Id);

    System.assertEquals(
      dealerAccount.Name,
      BWM_FieldValueResolver.resolveRecord(
        opportunityRecord,
        mapping.WhatsApp_Header_Value_Field__c
      ),
      'Resolved Dear value must be dealer name, not Steel Pipes.'
    );
  }

  @IsTest
  static void referToDealerKeepsCustomerEmailCityStateWhenOwnerMatchesCrm() {
    BWM_JourneyDefinitionService.clearCache();
    BWM_Template_Mapping__mdt mapping = [
      SELECT
        Journey_Name__c,
        Trigger_Point__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c,
        WhatsApp_Template_Name__c,
        RCS_Template_Name__c,
        SMS_Template_Name__c,
        WhatsApp_Header_Format__c,
        WhatsApp_Header_Value_Field__c,
        Brochure_Attachment_Mode__c,
        Include_Brochure_Header__c
      FROM BWM_Template_Mapping__mdt
      WHERE DeveloperName = 'Opportunity_Refer_To_Dealer'
      LIMIT 1
    ];
    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.isDealerSalesAssignTemplate(mapping)
    );

    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"Contact_Person_Name__c":"Test Contact","Phone__c":"7980828320","Email__c":"anshita.chanda@halsaglobal.io","City__c":"Kolkata","State__c":"West Bengal","CRM_User_Name_Formula__c":"Sreya Banerjee","Account":{"attributes":{"type":"Account"},"Name":"Test Company"},"Owner":{"attributes":{"type":"User"},"Name":"Sreya Banerjee","Phone":"9000000000","Email":"sreya@test.com"},"DealerAccount__r":{"attributes":{"type":"Account"},"Name":"Test HM Dealer"}}',
      Opportunity.class
    );

    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      opportunityRecord,
      mapping
    );
    params = BWM_CampaignJourneyParamService.applyMessagingContactParamFixes(
      opportunityRecord,
      params,
      mapping
    );

    System.assertEquals('Test Contact', params[0]);
    System.assertEquals('Test Company', params[1]);
    System.assertEquals('7980828320', params[2]);
    System.assertEquals('anshita.chanda@halsaglobal.io', params[3]);
    System.assertEquals('Kolkata', params[4]);
    System.assertEquals('West Bengal', params[5]);
    System.assertNotEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE,
      params[4],
      'City must not be replaced by central CRM phone.'
    );
    System.assertNotEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL,
      params[5],
      'State must not be replaced by central CRM email.'
    );
    System.assertNotEquals(
      'Sreya Banerjee',
      params[3],
      'Email must not be replaced by Owner name.'
    );
  }
}