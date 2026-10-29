/**
 * @description Confirms Enquiry is included with tower departments for gen email/journey.
 */
@IsTest
private class BWM_EnquiryTowerDeptTest {
  @IsTest
  static void genTowerDepartmentsIncludeEnquiry() {
    System.assertEquals(
      true,
      BWM_EmailConstants.GEN_TOWER_DEPARTMENTS.contains(
        BWM_EmailConstants.DEPT_ENQUIRY
      )
    );
    System.assertEquals(
      true,
      BWM_MessagingConstants.GEN_TOWER_DEPARTMENTS.contains(
        BWM_MessagingConstants.DEPT_ENQUIRY
      )
    );
    System.assert(
      BWM_MessagingConstants.GEN_TOWER_DEPARTMENTS_CSV.startsWith('Enquiry,')
    );
    for (
      String departmentName : new List<String>{
        'Transmission & Telecom Tower',
        'Pre Engineering Building',
        'Railway Electrification Structure'
      }
    ) {
      System.assertEquals(
        true,
        BWM_EmailConstants.GEN_TOWER_DEPARTMENTS.contains(departmentName)
      );
      System.assertEquals(
        true,
        BWM_MessagingConstants.GEN_TOWER_DEPARTMENTS.contains(departmentName)
      );
    }
  }
}