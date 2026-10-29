/**
 * @description   Test class for OfflineCampaignUploadService parse, validate, and
 *                insert scenarios.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class OfflineCampaignUploadServiceTest {
  @IsTest
  static void getDepartmentOptionsReturnsAllValues() {
    Test.startTest();
    List<OfflineCampaignUploadService.PicklistOption> options = OfflineCampaignUploadService.getDepartmentOptions();
    Test.stopTest();

    System.assertEquals(
      OfflineCampaignUploadService.DEPARTMENT_VALUES.size(),
      options.size()
    );
  }

  @IsTest
  static void insertRowsCreatesValidRecords() {
    OfflineCampaignUploadService.UploadRow row = new OfflineCampaignUploadService.UploadRow();
    row.rowKey = 'row-1';
    row.recordName = 'Offline Campaign One';
    row.email = 'user@example.com';
    row.phone = '9876543210';
    row.department = 'Enquiry';
    row.active = true;

    Test.startTest();
    OfflineCampaignUploadService.InsertSummary summary = OfflineCampaignUploadService.insertRows(
      new List<OfflineCampaignUploadService.UploadRow>{ row },
      'North Region List'
    );
    Test.stopTest();

    System.assertEquals(1, summary.totalCount);
    System.assertEquals(1, summary.successCount);
    System.assertEquals(0, summary.failedCount);

    Offline_Campaign__c record = [
      SELECT Name, Email__c, Phone__c, Department__c, Active__c, Group_List__c
      FROM Offline_Campaign__c
      LIMIT 1
    ];
    System.assertEquals('Offline Campaign One', record.Name);
    System.assertEquals('user@example.com', record.Email__c);
    System.assertEquals('9876543210', record.Phone__c);
    System.assertEquals('Enquiry', record.Department__c);
    System.assertEquals(true, record.Active__c);
    System.assertEquals('North Region List', record.Group_List__c);
  }

  @IsTest
  static void insertRowsRequiresGroupList() {
    OfflineCampaignUploadService.UploadRow row = new OfflineCampaignUploadService.UploadRow();
    row.rowKey = 'row-1';
    row.recordName = 'Offline Campaign One';

    Boolean threw = false;
    Test.startTest();
    try {
      OfflineCampaignUploadService.insertRows(
        new List<OfflineCampaignUploadService.UploadRow>{ row },
        '   '
      );
    } catch (Exception ex) {
      threw = true;
      System.assert(
        ex instanceof AuraHandledException,
        'Expected AuraHandledException, got: ' + ex.getTypeName()
      );
    }
    Test.stopTest();
    System.assert(threw);
  }

  @IsTest
  static void insertRowsReturnsValidationErrors() {
    OfflineCampaignUploadService.UploadRow row = new OfflineCampaignUploadService.UploadRow();
    row.rowKey = 'row-1';
    row.recordName = '';
    row.email = 'invalid-email';
    row.department = 'Invalid Department';

    Test.startTest();
    OfflineCampaignUploadService.InsertSummary summary = OfflineCampaignUploadService.insertRows(
      new List<OfflineCampaignUploadService.UploadRow>{ row },
      'Validation Group'
    );
    Test.stopTest();

    System.assertEquals(1, summary.totalCount);
    System.assertEquals(0, summary.successCount);
    System.assertEquals(1, summary.failedCount);
    System.assertEquals(1, summary.rowResults.size());
    System.assert(
      summary.rowResults[0].errors.contains('Name:'),
      'Expected name validation error'
    );
    System.assert(
      summary.rowResults[0].errors.contains('Email:'),
      'Expected email validation error'
    );
    System.assert(
      summary.rowResults[0].errors.contains('Department:'),
      'Expected department validation error'
    );
  }

  @IsTest
  static void controllerDelegatesToService() {
    OfflineCampaignUploadService.UploadRow row = new OfflineCampaignUploadService.UploadRow();
    row.rowKey = 'row-1';
    row.recordName = 'Controller Row';
    row.department = 'HDPE';

    Test.startTest();
    List<OfflineCampaignUploadService.PicklistOption> options = OfflineCampaignUploadController.getDepartmentOptions();
    OfflineCampaignUploadService.InsertSummary summary = OfflineCampaignUploadController.insertOfflineCampaignRows(
      JSON.serialize(new List<OfflineCampaignUploadService.UploadRow>{ row }),
      'Controller Group'
    );
    Test.stopTest();

    System.assert(!options.isEmpty());
    System.assertEquals(1, summary.successCount);
  }

  @IsTest
  static void parseUploadRowsDeserializesLwcPayload() {
    String rowsJson =
      '[{"rowKey":"row-1","recordName":"Anshita","email":"anshita.chanda@halsaglobal.io",' +
      '"phone":"7980828320","department":"HDPE","active":true}]';

    Test.startTest();
    List<OfflineCampaignUploadService.UploadRow> rows = OfflineCampaignUploadService.parseUploadRows(
      rowsJson
    );
    OfflineCampaignUploadService.InsertSummary summary = OfflineCampaignUploadService.insertRows(
      rows,
      'Upload Group A'
    );
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals('Anshita', rows[0].recordName);
    System.assertEquals(1, summary.successCount);
  }

  @IsTest
  static void parseUploadRowsRejectsBlankAndInvalidJson() {
    Boolean blankThrew = false;
    Boolean invalidThrew = false;

    Test.startTest();
    try {
      OfflineCampaignUploadService.parseUploadRows('');
    } catch (Exception ex) {
      blankThrew = true;
      System.assert(ex instanceof AuraHandledException);
    }

    try {
      OfflineCampaignUploadService.parseUploadRows('{invalid-json');
    } catch (Exception ex) {
      invalidThrew = true;
      System.assert(ex instanceof AuraHandledException);
    }
    Test.stopTest();

    System.assert(blankThrew);
    System.assert(invalidThrew);
  }

  @IsTest
  static void insertRowsRequiresData() {
    Boolean threw = false;
    Test.startTest();
    try {
      OfflineCampaignUploadService.insertRows(new List<OfflineCampaignUploadService.UploadRow>());
    } catch (Exception ex) {
      threw = true;
      System.assert(ex instanceof AuraHandledException);
    }
    Test.stopTest();
    System.assert(threw);
  }

  @IsTest
  static void validateRowChecksEmailPhoneAndNameLength() {
    OfflineCampaignUploadService.UploadRow row = new OfflineCampaignUploadService.UploadRow();
    row.rowKey = 'row-2';
    row.recordName = 'X'.repeat(81);
    row.email = 'bad-email';
    row.phone = '-1';
    row.department = 'HDPE';

    OfflineCampaignUploadService.RowResult result = OfflineCampaignUploadService.validateRow(row);
    System.assertEquals(false, result.success);
    System.assert(result.errors.contains('Name:'));
    System.assert(result.errors.contains('Email:'));
    System.assert(result.errors.contains('Phone:'));
  }

  @IsTest
  static void isValidEmailHandlesBlankAndValidValues() {
    System.assertEquals(false, OfflineCampaignUploadService.isValidEmail(null));
    System.assertEquals(false, OfflineCampaignUploadService.isValidEmail('invalid'));
    System.assertEquals(true, OfflineCampaignUploadService.isValidEmail('valid@example.com'));
  }
}