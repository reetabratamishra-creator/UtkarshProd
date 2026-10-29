public without sharing class BWM_MessagingProductBriefService {
  private static Map<String, BWM_Department_Brochure__mdt> briefByDepartment;

  public static String resolvePlainText(SObject record) {
    BWM_Department_Brochure__mdt row = resolveRow(record);
    return row == null ? '' : nullToEmpty(row.Product_Brief__c).trim();
  }

  @TestVisible
  static void setBriefMapForTest(
    Map<String, BWM_Department_Brochure__mdt> values
  ) {
    briefByDepartment = values == null
      ? new Map<String, BWM_Department_Brochure__mdt>()
      : values;
  }

  @TestVisible
  static void clearCache() {
    briefByDepartment = null;
  }

  private static BWM_Department_Brochure__mdt resolveRow(SObject record) {
    String departmentName = resolveDepartmentName(record);
    if (String.isBlank(departmentName)) {
      return null;
    }

    loadBriefs();
    return briefByDepartment.get(departmentName);
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

  private static void loadBriefs() {
    if (briefByDepartment != null) {
      return;
    }

    briefByDepartment = new Map<String, BWM_Department_Brochure__mdt>();
    for (BWM_Department_Brochure__mdt row : [
      SELECT Department_Name__c, Product_Brief__c
      FROM BWM_Department_Brochure__mdt
    ]) {
      if (String.isNotBlank(row.Product_Brief__c)) {
        briefByDepartment.put(row.Department_Name__c, row);
      }
    }
  }

  private static String nullToEmpty(String value) {
    return value == null ? '' : value;
  }
}