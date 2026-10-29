/**
 * @description   Parses uploaded Excel/CSV JSON, validates rows, and inserts Offline
 *                Campaign records with partial success support.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class OfflineCampaignUploadService {
  public static final Set<String> DEPARTMENT_VALUES = new Set<String>{
    'High Mast & Polygonal',
    'Steel Pipes',
    'Crash Barrier',
    'Steel Tubular Poles',
    'Polymer',
    'HDPE',
    'Transmission & Telecom Tower',
    'Pre Engineering Building',
    'Solar Structure',
    'Railway Electrification Structure',
    'Enquiry'
  };

  public class UploadRow {
    @AuraEnabled public String rowKey;
    @AuraEnabled public String recordName;
    @AuraEnabled public String email;
    @AuraEnabled public String phone;
    @AuraEnabled public String department;
    @AuraEnabled public Boolean active;
  }

  public class RowResult {
    @AuraEnabled public String rowKey;
    @AuraEnabled public Boolean success;
    @AuraEnabled public String errors;
    @AuraEnabled public Id recordId;
  }

  public class InsertSummary {
    @AuraEnabled public Integer totalCount;
    @AuraEnabled public Integer successCount;
    @AuraEnabled public Integer failedCount;
    @AuraEnabled public List<RowResult> rowResults;
    @AuraEnabled public List<String> errorSummary;
  }

  public class PicklistOption {
    @AuraEnabled public String label;
    @AuraEnabled public String value;
  }

  /**
   * @description Returns sorted department picklist options allowed for offline campaign uploads.
   * @return List of PicklistOption values from DEPARTMENT_VALUES.
   */
  public static List<PicklistOption> getDepartmentOptions() {
    List<PicklistOption> options = new List<PicklistOption>();
    for (String value : new List<String>(DEPARTMENT_VALUES)) {
      PicklistOption option = new PicklistOption();
      option.label = value;
      option.value = value;
      options.add(option);
    }
    options.sort(new PicklistOptionComparator());
    return options;
  }

  /**
   * @description Deserializes uploaded offline campaign row JSON into UploadRow DTOs.
   * @param rowsJson JSON array of upload rows from the LWC.
   * @return List of UploadRow values ready for validation and insert.
   */
  public static List<UploadRow> parseUploadRows(String rowsJson) {
    if (String.isBlank(rowsJson)) {
      throw new AuraHandledException('No rows were provided for insert.');
    }
    try {
      return (List<UploadRow>) JSON.deserialize(rowsJson, List<UploadRow>.class);
    } catch (Exception ex) {
      throw new AuraHandledException('Invalid row data: ' + ex.getMessage());
    }
  }

  /**
   * @description Validates upload rows and inserts Offline_Campaign__c records with partial-success support.
   * @param rows UploadRow DTOs to validate and insert.
   * @return InsertSummary with per-row results and aggregated error summary.
   */
  public static InsertSummary insertRows(List<UploadRow> rows) {
    return insertRows(rows, null);
  }

  /**
   * @description Validates upload rows and inserts Offline_Campaign__c records with partial-success support.
   * @param rows UploadRow DTOs to validate and insert.
   * @param groupList Group or list name applied to every inserted record.
   * @return InsertSummary with per-row results and aggregated error summary.
   */
  public static InsertSummary insertRows(List<UploadRow> rows, String groupList) {
    if (rows == null || rows.isEmpty()) {
      throw new AuraHandledException('No rows were provided for insert.');
    }

    String normalizedGroupList = normalizeGroupList(groupList);

    InsertSummary summary = new InsertSummary();
    summary.totalCount = rows.size();
    summary.successCount = 0;
    summary.failedCount = 0;
    summary.rowResults = new List<RowResult>();
    summary.errorSummary = new List<String>();

    List<Offline_Campaign__c> recordsToInsert = new List<Offline_Campaign__c>();
    Map<Integer, UploadRow> indexToRow = new Map<Integer, UploadRow>();

    for (Integer index = 0; index < rows.size(); index++) {
      UploadRow row = rows[index];
      RowResult validationResult = validateRow(row);
      if (!validationResult.success) {
        summary.failedCount++;
        summary.rowResults.add(validationResult);
        addErrorSummary(summary.errorSummary, validationResult.errors);
        continue;
      }

      recordsToInsert.add(buildRecord(row, normalizedGroupList));
      indexToRow.put(recordsToInsert.size() - 1, row);
    }

    if (!recordsToInsert.isEmpty()) {
      Database.SaveResult[] saveResults = Database.insert(recordsToInsert, false);
      for (Integer index = 0; index < saveResults.size(); index++) {
        Database.SaveResult saveResult = saveResults[index];
        UploadRow sourceRow = indexToRow.get(index);
        RowResult rowResult = new RowResult();
        rowResult.rowKey = sourceRow.rowKey;

        if (saveResult.isSuccess()) {
          rowResult.success = true;
          rowResult.recordId = saveResult.getId();
          summary.successCount++;
        } else {
          rowResult.success = false;
          rowResult.errors = formatSaveErrors(saveResult.getErrors());
          summary.failedCount++;
          addErrorSummary(summary.errorSummary, rowResult.errors);
        }
        summary.rowResults.add(rowResult);
      }
    }

    return summary;
  }

  /**
   * @description Validates a single upload row for required name and optional email/phone/department formats.
   * @param row Upload row to validate; may be null.
   * @return RowResult indicating success or concatenated validation errors.
   */
  @TestVisible
  static RowResult validateRow(UploadRow row) {
    RowResult result = new RowResult();
    result.rowKey = row == null ? null : row.rowKey;
    result.success = true;

    List<String> errors = new List<String>();
    if (row == null) {
      errors.add('Name: Row is empty.');
      result.success = false;
      result.errors = String.join(errors, ' ');
      return result;
    }

    if (String.isBlank(row.recordName)) {
      errors.add('Name: Name is required.');
    } else if (row.recordName.length() > 80) {
      errors.add('Name: Name cannot exceed 80 characters.');
    }

    if (String.isNotBlank(row.email) && !isValidEmail(row.email)) {
      errors.add('Email: Invalid email format.');
    }

    if (String.isNotBlank(row.phone) && !isValidPhone(row.phone)) {
      errors.add('Phone: Invalid phone format.');
    }

    if (String.isNotBlank(row.department) && !DEPARTMENT_VALUES.contains(row.department)) {
      errors.add('Department: Invalid picklist value.');
    }

    if (!errors.isEmpty()) {
      result.success = false;
      result.errors = String.join(errors, ' ');
    }

    return result;
  }

  /**
   * @description Maps a validated UploadRow into an Offline_Campaign__c record marked Active.
   * @param row Validated upload row source values.
   * @return Offline_Campaign__c ready for Database.insert.
   */
  @TestVisible
  static Offline_Campaign__c buildRecord(UploadRow row) {
    return buildRecord(row, null);
  }

  @TestVisible
  static Offline_Campaign__c buildRecord(UploadRow row, String groupList) {
    Offline_Campaign__c record = new Offline_Campaign__c();
    record.Name = row.recordName.trim();
    record.Email__c = String.isBlank(row.email) ? null : row.email.trim();
    record.Phone__c = String.isBlank(row.phone) ? null : row.phone.trim();
    record.Department__c = String.isBlank(row.department) ? null : row.department.trim();
    record.Group_List__c = String.isBlank(groupList) ? null : groupList.trim();
    record.Active__c = true;
    return record;
  }

  @TestVisible
  static String normalizeGroupList(String groupList) {
    if (String.isBlank(groupList)) {
      throw new AuraHandledException('Group / List is required.');
    }

    String normalizedGroupList = groupList.trim();
    if (normalizedGroupList.length() > 255) {
      throw new AuraHandledException('Group / List cannot exceed 255 characters.');
    }
    return normalizedGroupList;
  }

  /**
   * @description Returns true when the phone has at least 10 digits after stripping non-digits.
   * @param phone Candidate phone string.
   * @return True if the phone format is acceptable.
   */
  @TestVisible
  static Boolean isValidPhone(String phone) {
    if (String.isBlank(phone)) {
      return false;
    }
    String digitsOnly = phone.replaceAll('[^0-9]', '');
    return digitsOnly.length() >= 10;
  }

  /**
   * @description Returns true when the email matches a basic regex pattern.
   * @param email Candidate email string.
   * @return True if the email format is acceptable.
   */
  @TestVisible
  static Boolean isValidEmail(String email) {
    if (String.isBlank(email)) {
      return false;
    }
    return Pattern.matches(
      '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$',
      email.trim()
    );
  }

  /**
   * @description Formats Database.Error entries into a space-joined field-labeled message string.
   * @param errors SaveResult error list from a failed insert.
   * @return Human-readable error string for the row result.
   */
  @TestVisible
  static String formatSaveErrors(List<Database.Error> errors) {
    List<String> messages = new List<String>();
    for (Database.Error error : errors) {
      String fieldLabel = mapFieldToLabel(error.getFields());
      messages.add(fieldLabel + ': ' + error.getMessage());
    }
    return String.join(messages, ' ');
  }

  /**
   * @description Maps the first API field name from a Database.Error to a user-facing label.
   * @param fields Field API names from Database.Error.getFields().
   * @return Friendly field label, or Record when no field is present.
   */
  private static String mapFieldToLabel(List<String> fields) {
    if (fields == null || fields.isEmpty()) {
      return 'Record';
    }
    String fieldName = fields[0];
    if (fieldName == 'Name') {
      return 'Name';
    }
    if (fieldName == 'Email__c') {
      return 'Email';
    }
    if (fieldName == 'Phone__c') {
      return 'Phone';
    }
    if (fieldName == 'Department__c') {
      return 'Department';
    }
    if (fieldName == 'Active__c') {
      return 'Active';
    }
    if (fieldName == 'Group_List__c') {
      return 'Group / List';
    }
    return fieldName;
  }

  /**
   * @description Adds a unique trimmed error string to the insert summary list.
   * @param summary Mutable list of unique error summary strings.
   * @param errors Error text to add when non-blank and not already present.
   */
  private static void addErrorSummary(List<String> summary, String errors) {
    if (String.isBlank(errors)) {
      return;
    }
    String trimmed = errors.trim();
    if (!summary.contains(trimmed)) {
      summary.add(trimmed);
    }
  }

  private class PicklistOptionComparator implements Comparator<PicklistOption> {
    /**
     * @description Compares picklist options by label for ascending sort order.
     * @param left Left PicklistOption operand.
     * @param right Right PicklistOption operand.
     * @return Negative, zero, or positive comparison result.
     */
    public Integer compare(PicklistOption left, PicklistOption right) {
      if (left == null && right == null) {
        return 0;
      }
      if (left == null) {
        return -1;
      }
      if (right == null) {
        return 1;
      }
      return left.label.compareTo(right.label);
    }
  }
}