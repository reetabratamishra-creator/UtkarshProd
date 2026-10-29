/**
 * @description   Test class for BWM_CampaignJourneyParamService parameter validation
 *                scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class BWM_CampaignJourneyParamServiceTest {
  @IsTest
  static void ownerMatchesCrmUserNameForLeadAndOpportunity() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Lead.class
    );
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Opportunity.class
    );
    Contact contactRecord = new Contact(LastName = 'No CRM ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));

    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.ownerMatchesCrmUserName(leadRecord)
    );
    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.ownerMatchesCrmUserName(opportunityRecord)
    );
    System.assertEquals(
      false,
      BWM_CampaignJourneyParamService.ownerMatchesCrmUserName(contactRecord)
    );
  }

  @IsTest
  static void applySecondaryContactOverrideUpdatesParamsFourThroughSix() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Lead.class
    );
    List<String> params = new List<String>{
      'Owner',
      'Owner Phone',
      'Owner Email',
      'Rudra Narayan Chakraborty',
      '9999999999',
      'rudra@test.com'
    };

    List<String> updated = BWM_CampaignJourneyParamService.applySecondaryContactOverride(
      leadRecord,
      params
    );

    System.assertEquals('Sudip Datta', updated[3]);
    System.assertEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE,
      updated[4]
    );
    System.assertEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL,
      updated[5]
    );
  }

  @IsTest
  static void applyRcsBodyDataOverrideUpdatesSecondaryContactFields() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Lead.class
    );
    Map<String, Object> bodyData = new Map<String, Object>{
      'Lead_owner' => 'Sudip Datta',
      'Department_crm_phone' => '9999999999',
      'Department_crm_email' => 'crm@test.com'
    };

    Map<String, Object> updated = BWM_CampaignJourneyParamService.applyRcsBodyDataOverride(
      leadRecord,
      bodyData
    );

    System.assertEquals('Sudip Datta', updated.get('Lead_owner'));
    System.assertEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE,
      updated.get('Department_crm_phone')
    );
    System.assertEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL,
      updated.get('Department_crm_email')
    );
  }

  /**
   * Scenario: Blank {{4}}/{{5}}/{{6}} (CRM fields empty) are filled with corporate
   *           defaults so WhatsApp does not show literal 4/5/6.
   */
  @IsTest
  static void applyCampaignContactParamFixes_FillsBlankSecondarySlots() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Lead.class
    );
    List<String> params = new List<String>{
      'Sudip Datta',
      '9830453567',
      'customersupport@utkarshindia.in',
      '',
      '',
      ''
    };

    List<String> updated = BWM_CampaignJourneyParamService.applyCampaignContactParamFixes(
      leadRecord,
      params
    );

    System.assertEquals('Sudip Datta', updated[0]);
    System.assertEquals('', updated[3]);
    System.assertEquals('', updated[4]);
    System.assertEquals('', updated[5]);
  }

  /**
   * Scenario: Dual-contact journeys mapped with only Param1–3 are padded to 6 and
   *           secondary slots filled so WhatsApp does not show literal 4/5/6.
   */
  @IsTest
  static void applyCampaignContactParamFixes_PadsThreeParamsToSix() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Lead.class
    );
    List<String> params = new List<String>{
      'Sudip Datta',
      '9830453567',
      'customersupport@utkarshindia.in'
    };

    List<String> updated = BWM_CampaignJourneyParamService.applyCampaignContactParamFixes(
      leadRecord,
      params
    );

    System.assertEquals(6, updated.size());
    System.assertEquals('', updated[3]);
    System.assertEquals('', updated[4]);
    System.assertEquals('', updated[5]);
  }

  /**
   * Scenario: Literal "4"/"5"/"6" secondary values are treated as missing and replaced.
   */
  @IsTest
  static void applyCampaignContactParamFixes_ReplacesLiteralIndexes() {
    Lead leadRecord = new Lead(LastName = 'Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), Company = 'Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
    List<String> params = new List<String>{
      'Sudip Datta',
      '9830453567',
      'customersupport@utkarshindia.in',
      '4',
      '5',
      '6'
    };

    List<String> updated = BWM_CampaignJourneyParamService.applyCampaignContactParamFixes(
      leadRecord,
      params
    );

    System.assertEquals('', updated[3]);
    System.assertEquals('', updated[4]);
    System.assertEquals('', updated[5]);
  }

  /**
   * Scenario: fillBlank alone does not pad short lists (padding is via applyCampaign*).
   */
  @IsTest
  static void fillBlankSecondaryContactParams_LeavesShortListsUnchanged() {
    List<String> params = new List<String>{ 'A', 'B', 'C' };
    List<String> updated = BWM_CampaignJourneyParamService.fillBlankSecondaryContactParams(
      null,
      params,
      null
    );
    System.assertEquals(3, updated.size());
    System.assertEquals('A', updated[0]);
  }

  @IsTest
  static void isDualCorporateSupportPhoneTemplateDetectsEnquiryGenLayout() {
    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Param1_Field__c = BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1,
      Param2_Field__c = BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_2
    );
    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.isDualCorporateSupportPhoneTemplate(mapping)
    );
  }

  @IsTest
  static void applyMessagingContactParamFixesReplacesRudraWhenOwnerMatchesCrm() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta","Phone":"9830453567","Email":"owner@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Param4_Field__c = BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_NAME_1,
      Param5_Field__c = BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1,
      Param6_Field__c = BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_EMAIL_1
    );
    List<String> params = new List<String>{
      'Sudip Datta',
      '9830453567',
      'owner@test.com',
      BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_1_DEFAULT,
      '9830481380',
      BWM_MessagingConstants.FALLBACK_CONTACT_EMAIL
    };

    List<String> updated = BWM_CampaignJourneyParamService.applyMessagingContactParamFixes(
      leadRecord,
      params,
      mapping
    );

    System.assertEquals('Sudip Datta', updated[3]);
    System.assertEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE,
      updated[4]
    );
    System.assertEquals(
      BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL,
      updated[5]
    );
    System.assert(!updated.contains(BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_1_DEFAULT));
  }

  @IsTest
  static void applyMessagingContactParamFixesKeepsRudraPhonesOnEnquiryGenTemplate() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Param1_Field__c = BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1,
      Param2_Field__c = BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_2
    );
    List<String> params = new List<String>{ '9830481380', '9830367173' };

    List<String> updated = BWM_CampaignJourneyParamService.applyMessagingContactParamFixes(
      leadRecord,
      params,
      mapping
    );

    System.assertEquals('9830481380', updated[0]);
    System.assertEquals('9830367173', updated[1]);
  }

  @IsTest
  static void isProspectEnqDeptOwnerContactTemplateDetectsProspectEnqDeptJourney() {
    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Journey_Name__c = 'prospect_enq_dept',
      Param5_Field__c = 'Owner.Name'
    );
    System.assertEquals(
      true,
      BWM_CampaignJourneyParamService.isProspectEnqDeptOwnerContactTemplate(mapping)
    );
  }

  @IsTest
  static void applyMessagingContactParamFixesKeepsOwnerContactOnProspectEnqDept() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"Status":"Prospect","Department_Name__c":"High Mast & Polygonal","CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta","Phone":"9830453567","Email":"sudip@test.com"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Journey_Name__c = 'prospect_enq_dept',
      Param4_Field__c = 'Department_Name__c',
      Param5_Field__c = 'Owner.Name',
      Param6_Field__c = 'Owner.Phone',
      Param7_Field__c = 'Owner.Email'
    );
    List<String> params = new List<String>{
      'High Mast & Polygonal',
      'High Mast & Polygonal',
      'Product brief text',
      'High Mast & Polygonal',
      'Sudip Datta',
      '9830453567',
      'sudip@test.com'
    };

    List<String> updated = BWM_CampaignJourneyParamService.applyMessagingContactParamFixes(
      leadRecord,
      params,
      mapping
    );

    System.assertEquals('High Mast & Polygonal', updated[3]);
    System.assertEquals('Sudip Datta', updated[4]);
    System.assertEquals('9830453567', updated[5]);
    System.assertEquals('sudip@test.com', updated[6]);
    System.assert(
      !updated.contains(BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE)
    );
    System.assert(
      !updated.contains(BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL)
    );
  }

  @IsTest
  static void applyCampaignContactParamFixesDoesNotFillProspectEnqDeptSecondarySlots() {
    Lead leadRecord = (Lead) JSON.deserialize(
      '{"CRM_User_Name_Formula__c":"Sudip Datta","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Lead.class
    );
    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Journey_Name__c = 'prospect_enq_dept'
    );
    List<String> params = new List<String>{
      'Crash Barrier',
      'Crash Barrier',
      'Brief',
      'Crash Barrier',
      'Sudip Datta',
      '9830453567',
      'sudip@test.com'
    };

    List<String> updated = BWM_CampaignJourneyParamService.applyCampaignContactParamFixes(
      leadRecord,
      params,
      mapping
    );

    System.assertEquals('Sudip Datta', updated[4]);
    System.assertEquals('9830453567', updated[5]);
    System.assertEquals('sudip@test.com', updated[6]);
  }

  @IsTest
  static void applyMessagingContactParamFixesDoesNotPadThreeParamJourneys() {
    Opportunity opportunityRecord = (Opportunity) JSON.deserialize(
      '{"StageName":"Nurture","Owner":{"attributes":{"type":"User"},"Name":"Sudip Datta"}}',
      Opportunity.class
    );
    BWM_Template_Mapping__mdt mapping = new BWM_Template_Mapping__mdt(
      Journey_Name__c = 'nurture_assign_team',
      Param1_Field__c = 'Owner.Name',
      Param2_Field__c = 'Owner.Phone',
      Param3_Field__c = 'Owner.Email'
    );
    List<String> params = new List<String>{
      'Sudip Datta',
      '9830453567',
      'sudip@test.com'
    };

    List<String> updated = BWM_CampaignJourneyParamService.applyMessagingContactParamFixes(
      opportunityRecord,
      params,
      mapping
    );

    System.assertEquals(3, updated.size());
    System.assertEquals('Sudip Datta', updated[0]);
    System.assertEquals('9830453567', updated[1]);
    System.assertEquals('sudip@test.com', updated[2]);
  }
}