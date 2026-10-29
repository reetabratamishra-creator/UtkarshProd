/**
 * @description   Test-only DML helper. Inserts/updates/deletes in system mode
 *                so profile FLS/CRUD cannot fail production validation, and
 *                stamps unique Name/Email/Phone values to avoid duplicate-rule
 *                clashes with org data and other tests.
 * @author        Anshita Chanda
 * @date          2026-08-19
 */
@IsTest
public class BWM_TestDml {
  private static Integer sequence = 0;

  /**
   * @description Unique token for this test transaction.
   * @return Unique alphanumeric string.
   */
  public static String token() {
    sequence++;
    return String.valueOf(Math.abs(Crypto.getRandomInteger())) +
      String.valueOf(Datetime.now().getTime()).right(5) +
      String.valueOf(sequence);
  }

  /**
   * @description Stamps unique Name/Email/Phone-style field values on a record.
   * @param record Record to uniquify.
   */
  public static void stampUnique(SObject record) {
    if (record == null) {
      return;
    }
    String typeName = String.valueOf(record.getSObjectType());
    if (
      typeName == 'User' ||
      typeName == 'Group' ||
      typeName == 'Profile' ||
      typeName == 'PermissionSet'
    ) {
      return;
    }

    String uniqueToken = token();
    Map<String, Schema.SObjectField> fieldMap = record.getSObjectType()
      .getDescribe()
      .fields.getMap();
    stampTextField(record, fieldMap, 'Name', uniqueToken, false);
    stampTextField(record, fieldMap, 'LastName', uniqueToken, false);
    stampTextField(record, fieldMap, 'Company', uniqueToken, false);
    stampTextField(record, fieldMap, 'Company_Name__c', uniqueToken, false);
    stampTextField(record, fieldMap, 'Email', uniqueToken, true);
    stampTextField(record, fieldMap, 'Phone', uniqueToken, false);
    stampTextField(record, fieldMap, 'MobilePhone', uniqueToken, false);
    stampTextField(record, fieldMap, 'Phone__c', uniqueToken, false);
  }

  /**
   * @description Stamps unique values on each record in the list.
   * @param records Records to uniquify.
   */
  public static void stampUnique(List<SObject> records) {
    if (records == null) {
      return;
    }
    for (SObject record : records) {
      stampUnique(record);
    }
  }

  /**
   * @description Inserts a record in system mode after uniquifying identity fields.
   * @param record Record to insert.
   */
  public static void insertSys(SObject record) {
    stampUnique(record);
    insertAllowDuplicate(record);
  }

  /**
   * @description Inserts records in system mode after uniquifying identity fields.
   * @param records Records to insert.
   */
  public static void insertSys(List<SObject> records) {
    stampUnique(records);
    insertAllowDuplicate(records);
  }

  /**
   * @description Updates a record in system mode.
   * @param record Record to update.
   */
  public static void updateSys(SObject record) {
    update as system record;
  }

  /**
   * @description Updates records in system mode.
   * @param records Records to update.
   */
  public static void updateSys(List<SObject> records) {
    update as system records;
  }

  /**
   * @description Deletes a record in system mode.
   * @param record Record to delete.
   */
  public static void deleteSys(SObject record) {
    delete as system record;
  }

  /**
   * @description Deletes records in system mode.
   * @param records Records to delete.
   */
  public static void deleteSys(List<SObject> records) {
    delete as system records;
  }

  private static void insertAllowDuplicate(SObject record) {
    Database.DMLOptions dmlOptions = allowDuplicateOptions();
    Database.insert(record, dmlOptions, AccessLevel.SYSTEM_MODE);
  }

  private static void insertAllowDuplicate(List<SObject> records) {
    Database.DMLOptions dmlOptions = allowDuplicateOptions();
    Database.insert(records, dmlOptions, AccessLevel.SYSTEM_MODE);
  }

  private static Database.DMLOptions allowDuplicateOptions() {
    Database.DMLOptions dmlOptions = new Database.DMLOptions();
    dmlOptions.DuplicateRuleHeader.AllowSave = true;
    dmlOptions.optAllOrNone = true;
    return dmlOptions;
  }

  private static void stampTextField(
    SObject record,
    Map<String, Schema.SObjectField> fieldMap,
    String fieldName,
    String uniqueToken,
    Boolean isEmail
  ) {
    if (!fieldMap.containsKey(fieldName)) {
      return;
    }
    Object rawValue = record.get(fieldName);
    if (rawValue == null) {
      return;
    }
    String value = String.valueOf(rawValue);
    if (String.isBlank(value) || value.contains(uniqueToken)) {
      return;
    }
    if (isEmail && value.contains('@')) {
      record.put(
        fieldName,
        value.substringBefore('@') + '+' + uniqueToken + '@' + value.substringAfter('@')
      );
      return;
    }
    if (fieldName.contains('Phone')) {
      String digits = uniqueToken.replaceAll('[^0-9]', '');
      digits = (digits + '9123456789').left(10);
      if (digits.startsWith('0')) {
        digits = '9' + digits.right(9);
      }
      record.put(fieldName, digits);
      return;
    }
    record.put(fieldName, value + ' ' + uniqueToken);
  }
}