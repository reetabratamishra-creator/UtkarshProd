/**
 * @description   Aggregates Opportunity product categories for use in messaging
 *                templates.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_OpportunityProductCategoryService {
  public static String resolveAggregatedCategories(Opportunity opportunityRecord) {
    return resolveAggregatedCategories(opportunityRecord, ';');
  }

  public static String resolveAggregatedCategories(
    Opportunity opportunityRecord,
    String delimiter
  ) {
    if (opportunityRecord == null || opportunityRecord.Id == null) {
      return '';
    }

    List<String> categories = new List<String>();
    Set<String> seen = new Set<String>();

    for (Product_Category__c productCategoryRecord : [
      SELECT Product_Category__c
      FROM Product_Category__c
      WHERE
        Opportunity__c = :opportunityRecord.Id
        AND Product_Category__c != NULL
      ORDER BY CreatedDate ASC
    ]) {
      String categoryValue = productCategoryRecord.Product_Category__c.trim();
      if (String.isBlank(categoryValue) || seen.contains(categoryValue)) {
        continue;
      }
      seen.add(categoryValue);
      categories.add(categoryValue);
    }

    if (!categories.isEmpty()) {
      return String.join(categories, delimiter);
    }

    return opportunityRecord.Product_Category__c == null
      ? ''
      : opportunityRecord.Product_Category__c.trim();
  }
}