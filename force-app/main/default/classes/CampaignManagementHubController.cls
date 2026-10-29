public with sharing class CampaignManagementHubController {
  private static final Map<String, String> OBJECT_CONTROLLER_BY_VALUE = new Map<String, String>{
    'Lead' => 'LeadManagementController',
    'Opportunity' => 'DealerOpportunityManagementController',
    'Account' => 'AccountManagementController',
    'Contact' => 'ContactManagementController',
    'Offline_Campaign' => 'OfflineCampaignManagementController'
  };

  @AuraEnabled(cacheable=true)
  public static List<CampaignObjectOption> getCampaignObjectOptions() {
    List<CampaignObjectOption> options = new List<CampaignObjectOption>();
    List<String> orderedObjectValues = new List<String>{
      'Lead',
      'Opportunity',
      'Account',
      'Contact',
      'Offline_Campaign'
    };

    for (String objectValue : orderedObjectValues) {
      String controllerName = OBJECT_CONTROLLER_BY_VALUE.get(objectValue);
      if (userHasApexClassAccess(controllerName)) {
        options.add(new CampaignObjectOption(objectValue, getObjectLabel(objectValue)));
      }
    }
    return options;
  }

  private static String getObjectLabel(String objectValue) {
    if (objectValue == 'Lead') {
      return 'Lead';
    }
    if (objectValue == 'Opportunity') {
      return 'Opportunity';
    }
    if (objectValue == 'Account') {
      return 'Account';
    }
    if (objectValue == 'Contact') {
      return 'Contact';
    }
    if (objectValue == 'Offline_Campaign') {
      return 'Offline Campaign';
    }
    return objectValue;
  }

  private static Boolean userHasApexClassAccess(String className) {
    List<ApexClass> classes = [
      SELECT Id
      FROM ApexClass
      WHERE Name = :className
      LIMIT 1
    ];
    if (classes.isEmpty()) {
      return false;
    }

    Set<Id> permissionSetIds = new Set<Id>();
    for (PermissionSetAssignment assignment : [
      SELECT PermissionSetId
      FROM PermissionSetAssignment
      WHERE AssigneeId = :UserInfo.getUserId()
    ]) {
      permissionSetIds.add(assignment.PermissionSetId);
    }

    User currentUser = [
      SELECT ProfileId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    for (PermissionSet profilePermissionSet : [
      SELECT Id
      FROM PermissionSet
      WHERE IsOwnedByProfile = TRUE AND ProfileId = :currentUser.ProfileId
      LIMIT 1
    ]) {
      permissionSetIds.add(profilePermissionSet.Id);
    }

    if (permissionSetIds.isEmpty()) {
      return false;
    }

    Integer accessCount = [
      SELECT COUNT()
      FROM SetupEntityAccess
      WHERE SetupEntityId = :classes[0].Id AND ParentId IN :permissionSetIds
    ];
    return accessCount > 0;
  }

  public class CampaignObjectOption {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;

    public CampaignObjectOption(String optionValue, String optionLabel) {
      value = optionValue;
      label = optionLabel;
    }
  }
}