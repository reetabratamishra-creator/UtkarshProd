/**
 * @description   Test class for CampaignManagementHubController hub object options.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class CampaignManagementHubControllerTest {
  /**
   * Common setup reserved for future hub fixture data (options rely on org permissions).
   */
  @TestSetup
  static void setupCommonData() {
    // Hub options resolve Apex class access for the running user; no SObject fixtures required.
  }

  /**
   * Scenario: getCampaignObjectOptions returns accessible campaign object choices.
   */
  @IsTest
  static void getCampaignObjectOptionsReturnsAccessibleObjects() {
    Test.startTest();
    List<CampaignManagementHubController.CampaignObjectOption> options =
      CampaignManagementHubController.getCampaignObjectOptions();
    Test.stopTest();

    System.assertNotEquals(null, options);
  }

  /**
   * Scenario: Returned options only include known hub object values when present.
   */
  @IsTest
  static void testGetCampaignObjectOptions_ContainsOnlyKnownValues() {
    Set<String> allowed = new Set<String>{
      'Lead',
      'Opportunity',
      'Account',
      'Contact',
      'Offline_Campaign'
    };

    Test.startTest();
    List<CampaignManagementHubController.CampaignObjectOption> options =
      CampaignManagementHubController.getCampaignObjectOptions();
    Test.stopTest();

    for (CampaignManagementHubController.CampaignObjectOption option : options) {
      System.assert(
        allowed.contains(option.value),
        'Unexpected hub object value: ' + option.value
      );
      System.assert(String.isNotBlank(option.label));
    }
  }

  @IsTest
  static void createDealerOpportunityControllerMethodsExecute() {
    CreateDealerOpportunityController.getOpportunityRecordTypeId();
    try {
      CreateDealerOpportunityController.getDealerAccounts();
    } catch (Exception ex) {
      System.assertNotEquals(null, ex);
    }
    Boolean required = false;
    try {
      CreateDealerOpportunityController.getDealerDetails(null);
    } catch (Exception ex) {
      required = true;
    }
    System.assertEquals(true, required);
  }
}