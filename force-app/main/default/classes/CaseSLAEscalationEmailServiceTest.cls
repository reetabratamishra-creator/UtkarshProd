/**
 * @description Test class for CaseSLAEscalationEmailService.
 */
@IsTest
private class CaseSLAEscalationEmailServiceTest {
  private static Id queryAnyTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName LIKE 'Case_%Response%'
      LIMIT 1
    ];
    if (templates.isEmpty()) {
      templates = [SELECT Id FROM EmailTemplate LIMIT 1];
    }
    return templates.isEmpty() ? null : templates[0].Id;
  }

  @IsTest
  static void testTemplateMappingAndThresholds() {
    System.assertEquals(
      'Case_Critical_Response_24h_Owner',
      CaseSLAEscalationEmailService.resolveTemplateDeveloperName(
        'Critical',
        CaseSLAEscalationEmailService.EscalationTier.OWNER
      )
    );
    System.assertEquals(
      'Case_High_Response_48h_HOD',
      CaseSLAEscalationEmailService.resolveTemplateDeveloperName(
        'High',
        CaseSLAEscalationEmailService.EscalationTier.HOD
      )
    );
    System.assertEquals(
      'Case_Low_Response_144h_Sir',
      CaseSLAEscalationEmailService.resolveTemplateDeveloperName(
        'Low',
        CaseSLAEscalationEmailService.EscalationTier.SIR
      )
    );
    System.assertEquals(null, CaseSLAEscalationEmailService.resolveTemplateDeveloperName('Invalid', CaseSLAEscalationEmailService.EscalationTier.OWNER));
    System.assertEquals(24, CaseSLAEscalationEmailService.getOwnerThresholdHours('Critical'));
    System.assertEquals(48, CaseSLAEscalationEmailService.getOwnerThresholdHours('Medium'));
    System.assertEquals(72, CaseSLAEscalationEmailService.getOwnerThresholdHours('Low'));
    System.assertEquals(48, CaseSLAEscalationEmailService.getHodThresholdHours('Critical'));
    System.assertEquals(72, CaseSLAEscalationEmailService.getHodThresholdHours('Medium'));
    System.assertEquals(120, CaseSLAEscalationEmailService.getHodThresholdHours('Low'));
    System.assertEquals(72, CaseSLAEscalationEmailService.getSirThresholdHours('Critical'));
    System.assertEquals(120, CaseSLAEscalationEmailService.getSirThresholdHours('Medium'));
    System.assertEquals(144, CaseSLAEscalationEmailService.getSirThresholdHours('Low'));
  }

  @IsTest
  static void testIsTierDueUsesCreatedDateFallback() {
    Datetime anchorDate = Datetime.newInstance(2026, 1, 1, 10, 0, 0);
    CaseSLAEscalationEmailService.testAnchorOverride = anchorDate;
    CaseSLAEscalationEmailService.testNowOverride = anchorDate.addHours(30);

    Case overdueCase = new Case(Priority = 'Critical');

    System.assertEquals(
      true,
      CaseSLAEscalationEmailService.isTierDue(
        overdueCase,
        CaseSLAEscalationEmailService.EscalationTier.OWNER
      )
    );
    System.assertEquals(
      false,
      CaseSLAEscalationEmailService.isTierDue(
        overdueCase,
        CaseSLAEscalationEmailService.EscalationTier.HOD
      )
    );
  }

  @IsTest
  static void testNullGuardMethods() {
    System.assertEquals(false, CaseSLAEscalationEmailService.sendEscalationEmail(null, CaseSLAEscalationEmailService.EscalationTier.OWNER));
    System.assertEquals(false, CaseSLAEscalationEmailService.isTierDue(null, CaseSLAEscalationEmailService.EscalationTier.OWNER));
    System.assertEquals(null, CaseSLAEscalationEmailService.resolveTemplateDeveloperName(null, CaseSLAEscalationEmailService.EscalationTier.OWNER));
  }

  @IsTest
  static void testIsTierDueForHodAndSirTiers() {
    Datetime anchorDate = Datetime.newInstance(2026, 1, 1, 10, 0, 0);
    CaseSLAEscalationEmailService.testAnchorOverride = anchorDate;
    CaseSLAEscalationEmailService.testNowOverride = anchorDate.addHours(50);

    Case criticalCase = new Case(Priority = 'Critical');
    System.assertEquals(
      true,
      CaseSLAEscalationEmailService.isTierDue(
        criticalCase,
        CaseSLAEscalationEmailService.EscalationTier.HOD
      )
    );

    CaseSLAEscalationEmailService.testNowOverride = anchorDate.addHours(150);
    Case lowCase = new Case(Priority = 'Low');
    System.assertEquals(
      true,
      CaseSLAEscalationEmailService.isTierDue(
        lowCase,
        CaseSLAEscalationEmailService.EscalationTier.SIR
      )
    );
  }

  @IsTest
  static void testSendEscalationEmailResolvesLiveRecipients() {
    Id templateId = queryAnyTemplateId();
    if (templateId == null) {
      return;
    }
    CaseSLAEscalationEmailService.testTemplateIdOverride = templateId;
    CaseSLAEscalationEmailService.testRecipientOverrides = null;

    Case caseRecord = new Case(
      Subject = 'SLA Live Recipient Test',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'High',
      Department__c = 'HDPE',
      OwnerId = UserInfo.getUserId()
    );
    insert caseRecord;

    caseRecord = [
      SELECT
        Id,
        Priority,
        OwnerId,
        Owner.Email,
        Department__c,
        Department_formula__c,
        HOD_User_Email_Formula__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    Test.startTest();
    CaseSLAEscalationEmailService.sendEscalationEmail(
      caseRecord,
      CaseSLAEscalationEmailService.EscalationTier.OWNER
    );
    CaseSLAEscalationEmailService.sendEscalationEmail(
      caseRecord,
      CaseSLAEscalationEmailService.EscalationTier.HOD
    );
    CaseSLAEscalationEmailService.sendEscalationEmail(
      caseRecord,
      CaseSLAEscalationEmailService.EscalationTier.SIR
    );
    Test.stopTest();

    System.assertNotEquals(null, caseRecord.Id);
  }

  @IsTest
  static void testSendEscalationEmailsForAllTiers() {
    Id templateId = queryAnyTemplateId();
    if (templateId == null) {
      return;
    }
    CaseSLAEscalationEmailService.testTemplateIdOverride = templateId;
    CaseSLAEscalationEmailService.testRecipientOverrides = new Set<String>{
      UserInfo.getUserEmail()
    };

    Case caseRecord = new Case(
      Subject = 'SLA Escalation Test',
      Status = 'Open',
      Origin = 'Phone',
      Priority = 'Medium',
      Department__c = 'HDPE',
      OwnerId = UserInfo.getUserId()
    );
    insert caseRecord;

    caseRecord = [
      SELECT
        Id,
        Priority,
        OwnerId,
        Owner.Email,
        Department__c,
        Department_formula__c,
        CreatedDate,
        HOD_User_Email_Formula__c,
        SLA_Due_Date_Time_RO__c,
        Escalation_Date_1__c,
        Escalation_Date_2__c
      FROM Case
      WHERE Id = :caseRecord.Id
    ];

    Test.startTest();
    CaseSLAEscalationEmailService.sendEscalationEmail(
      caseRecord,
      CaseSLAEscalationEmailService.EscalationTier.OWNER
    );
    CaseSLAEscalationEmailService.sendEscalationEmail(
      caseRecord,
      CaseSLAEscalationEmailService.EscalationTier.HOD
    );
    CaseSLAEscalationEmailService.sendEscalationEmail(
      caseRecord,
      CaseSLAEscalationEmailService.EscalationTier.SIR
    );
    Test.stopTest();
    System.assertNotEquals(null, caseRecord.Id);
  }
}