/**
 * @description   Sends the daily consolidated "Project Opportunity Created" emails
 *                to HODs and CRM Heads (one email per recipient, listing all
 *                their new Project Opportunities).
 *
 *                STANDALONE: does not depend on any new method in
 *                OpportunityAssignmentEmailHandler. It only reads that class's
 *                public constants (template names, sender address, record type).
 *
 *                Recipient logic is the SAME as OpportunityAssignmentEmailHandler:
 *                  HOD      : Opportunity.HOD_User_Email_Formula__c,
 *                             else Department_HOD_Person__mdt (by Department_Name__c)
 *                  CRM Head : Opportunity.CRM_User_Email_Formula__c,
 *                             else Department_CRM_Person__mdt (by Department_Name__c)
 *
 *                One WorkItem = ONE email. Run with scope 5 (one sendEmail call each).
 *
 * REQUIRES two checkbox fields on Opportunity (default unchecked):
 *   Project_Created_HOD_Sent_c__c
 *   Project_Created_CRM_Sent_c__c
 */
public without sharing class ProjectOpportunityCreatedDigestBatch implements Database.Batchable<ProjectOpportunityCreatedDigestBatch.WorkItem> {
  // Only opportunities created within this many days are considered, so the first
  // run never emails the whole history. Unsent ones are retried inside this window.
  private static final Integer LOOKBACK_DAYS = 2;

  private static Map<String, String> hodEmailByDepartment;
  private static Map<String, String> crmEmailByDepartment;

  public class WorkItem {
    public String recipientEmail;
    public String templateName;
    public Boolean isHod; // true = HOD item, false = CRM Head item
    public List<Opportunity> opps;
  }

  // ===========================================================================
  // BATCH
  // ===========================================================================

  public Iterable<WorkItem> start(Database.BatchableContext context) {
    Datetime cutoff = System.now().addDays(-LOOKBACK_DAYS);
    String projectRecordType = OpportunityAssignmentEmailHandler.PROJECT_RECORD_TYPE_DEVELOPER_NAME;

    List<Opportunity> candidates = [
      SELECT
        Id,
        Name,
        OwnerId,
        Owner.Name,
        CreatedDate,
        Department_Name__c,
        CRM_User_Email_Formula__c,
        HOD_User_Email_Formula__c,
        Project_Created_HOD_Sent_c__c,
        Project_Created_CRM_Sent_c__c
      FROM Opportunity
      WHERE
        RecordType.DeveloperName = :projectRecordType
        AND CreatedDate >= :cutoff
        AND (
          Project_Created_HOD_Sent_c__c = FALSE
          OR Project_Created_CRM_Sent_c__c = FALSE
        )
      ORDER BY CreatedDate
    ];

    List<Opportunity> hodPending = new List<Opportunity>();
    List<Opportunity> crmPending = new List<Opportunity>();
    for (Opportunity opp : candidates) {
      if (!opp.Project_Created_HOD_Sent_c__c) {
        hodPending.add(opp);
      }
      if (!opp.Project_Created_CRM_Sent_c__c) {
        crmPending.add(opp);
      }
    }

    List<WorkItem> items = new List<WorkItem>();
    addItems(
      items,
      groupByEmail(hodPending, true),
      OpportunityAssignmentEmailHandler.TEMPLATE_HOD_PROJECT_CREATED,
      true
    );
    addItems(
      items,
      groupByEmail(crmPending, false),
      OpportunityAssignmentEmailHandler.TEMPLATE_CRM_HEAD_OPPORTUNITY_CREATED,
      false
    );
    return items;
  }

  public void execute(Database.BatchableContext context, List<WorkItem> scope) {
    // Resolve once per chunk (not once per email) to save SOQL queries.
    Id oweaId = getOrgWideEmailAddressId();
    Map<String, Id> templateIdByName = new Map<String, Id>();

    // One record per Opportunity, because it can be in a HOD item and a CRM item
    // of the same chunk.
    Map<Id, Opportunity> updatesById = new Map<Id, Opportunity>();

    for (WorkItem item : scope) {
      if (!templateIdByName.containsKey(item.templateName)) {
        templateIdByName.put(item.templateName, getTemplateId(item.templateName));
      }

      Boolean sent = false;
      try {
        sent = sendDigest(item, templateIdByName.get(item.templateName), oweaId);
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'Created digest failed for ' + item.recipientEmail + ': ' + ex.getMessage()
        );
      }
      if (!sent) {
        continue; // flag stays false => retried on the next run
      }

      for (Opportunity opp : item.opps) {
        Opportunity updateRecord = updatesById.containsKey(opp.Id)
          ? updatesById.get(opp.Id)
          : new Opportunity(Id = opp.Id);
        if (item.isHod) {
          updateRecord.Project_Created_HOD_Sent_c__c = true;
        } else {
          updateRecord.Project_Created_CRM_Sent_c__c = true;
        }
        updatesById.put(opp.Id, updateRecord);
      }
    }

    if (!updatesById.isEmpty()) {
      Database.update(updatesById.values(), false);
    }
  }

  public void finish(Database.BatchableContext context) {
  }

  // ===========================================================================
  // GROUPING + RECIPIENT RESOLUTION (same logic as OpportunityAssignmentEmailHandler)
  // ===========================================================================

  private static void addItems(
    List<WorkItem> target,
    Map<String, List<Opportunity>> oppsByEmail,
    String templateName,
    Boolean isHod
  ) {
    for (String email : oppsByEmail.keySet()) {
      WorkItem item = new WorkItem();
      item.recipientEmail = email;
      item.templateName = templateName;
      item.isHod = isHod;
      item.opps = oppsByEmail.get(email);
      target.add(item);
    }
  }

  // Groups opportunities by resolved recipient email. Opportunities with no
  // resolvable email are skipped (stay unflagged => retried on the next run).
  private static Map<String, List<Opportunity>> groupByEmail(
    List<Opportunity> opps,
    Boolean forHod
  ) {
    Map<String, List<Opportunity>> oppsByEmail = new Map<String, List<Opportunity>>();
    for (Opportunity opp : opps) {
      String email = forHod ? resolveHodEmail(opp) : resolveCrmHeadEmail(opp);
      if (String.isBlank(email)) {
        System.debug(
          (forHod ? 'HOD' : 'CRM Head') +
            ' email not resolved for Opportunity ' +
            opp.Id +
            ' (Department_Name__c=' +
            opp.Department_Name__c +
            ')'
        );
        continue;
      }
      String key = email.trim().toLowerCase();
      if (!oppsByEmail.containsKey(key)) {
        oppsByEmail.put(key, new List<Opportunity>());
      }
      oppsByEmail.get(key).add(opp);
    }
    return oppsByEmail;
  }

  private static String resolveHodEmail(Opportunity opp) {
    if (opp == null) {
      return null;
    }
    if (String.isNotBlank(opp.HOD_User_Email_Formula__c)) {
      return opp.HOD_User_Email_Formula__c.trim();
    }
    return lookupDepartmentEmail(opp.Department_Name__c, getHodEmailByDepartment());
  }

  private static String resolveCrmHeadEmail(Opportunity opp) {
    if (opp == null) {
      return null;
    }
    if (String.isNotBlank(opp.CRM_User_Email_Formula__c)) {
      return opp.CRM_User_Email_Formula__c.trim();
    }
    return lookupDepartmentEmail(opp.Department_Name__c, getCrmEmailByDepartment());
  }

  private static String lookupDepartmentEmail(
    String departmentName,
    Map<String, String> emailByDepartment
  ) {
    if (
      String.isBlank(departmentName) ||
      emailByDepartment == null ||
      emailByDepartment.isEmpty()
    ) {
      return null;
    }
    return emailByDepartment.get(departmentName.trim().toLowerCase());
  }

  private static Map<String, String> getHodEmailByDepartment() {
    if (hodEmailByDepartment != null) {
      return hodEmailByDepartment;
    }
    hodEmailByDepartment = new Map<String, String>();
    for (Department_HOD_Person__mdt record : [
      SELECT Department_Name__c, HOD_Person_Email__c
      FROM Department_HOD_Person__mdt
    ]) {
      if (
        String.isBlank(record.Department_Name__c) ||
        String.isBlank(record.HOD_Person_Email__c)
      ) {
        continue;
      }
      hodEmailByDepartment.put(
        record.Department_Name__c.trim().toLowerCase(),
        record.HOD_Person_Email__c.trim()
      );
    }
    return hodEmailByDepartment;
  }

  private static Map<String, String> getCrmEmailByDepartment() {
    if (crmEmailByDepartment != null) {
      return crmEmailByDepartment;
    }
    crmEmailByDepartment = new Map<String, String>();
    for (Department_CRM_Person__mdt record : [
      SELECT Department_Name__c, CRM_Person_Email__c
      FROM Department_CRM_Person__mdt
    ]) {
      if (
        String.isBlank(record.Department_Name__c) ||
        String.isBlank(record.CRM_Person_Email__c)
      ) {
        continue;
      }
      crmEmailByDepartment.put(
        record.Department_Name__c.trim().toLowerCase(),
        record.CRM_Person_Email__c.trim()
      );
    }
    return crmEmailByDepartment;
  }

  // ===========================================================================
  // SENDING
  // ===========================================================================

  private static Id getTemplateId(String developerName) {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0].Id;
  }

  private static Id getOrgWideEmailAddressId() {
    List<OrgWideEmailAddress> owea = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE Address = :OpportunityAssignmentEmailHandler.ORG_WIDE_SENDER_EMAIL
      LIMIT 1
    ];
    return owea.isEmpty() ? null : owea[0].Id;
  }

  // Sends ONE email to one recipient. Subject / intro come from the existing template
  // (rendered against the first opportunity); a table of ALL opportunities is added,
  // and the template's "Regards" closing is moved to the end, after the table.
  // Returns true only when Salesforce accepted the email.
  private static Boolean sendDigest(WorkItem item, Id templateId, Id oweaId) {
    if (
      item == null ||
      item.opps == null ||
      item.opps.isEmpty() ||
      String.isBlank(item.recipientEmail) ||
      templateId == null
    ) {
      System.debug('Digest skipped (missing data or template) for ' + item.recipientEmail);
      return false;
    }

    Messaging.SingleEmailMessage mail;
    try {
      mail = Messaging.renderStoredEmailTemplate(templateId, null, item.opps[0].Id);
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Digest template render failed: ' + e.getMessage());
      return false;
    }

    mail.setTargetObjectId(null);
    mail.setToAddresses(new List<String>{ item.recipientEmail.trim() });
    mail.setSaveAsActivity(false);
    mail.setTreatTargetObjectAsRecipient(false);
    if (oweaId != null) {
      mail.setOrgWideEmailAddressId(oweaId);
    }

    Integer total = item.opps.size();
    String baseSubject = String.isBlank(mail.getSubject())
      ? 'Project Opportunity Created'
      : mail.getSubject();
    mail.setSubject(baseSubject + ' (' + total + ' Opportunities)');

    String rawHtml = String.isNotBlank(mail.getHtmlBody())
      ? mail.getHtmlBody()
      : (String.isNotBlank(mail.getPlainTextBody())
          ? mail.getPlainTextBody().replace('\n', '<br/>')
          : '');
    List<String> htmlParts = splitClosingHtml(rawHtml);
    mail.setHtmlBody(
      htmlParts[0] +
      '<br/><p><b>New Project Opportunities (' + total + '):</b></p>' +
      buildHtmlTable(item.opps) +
      '<br/>' + htmlParts[1]
    );

    List<String> textParts = splitClosingText(mail.getPlainTextBody());
    mail.setPlainTextBody(
      textParts[0] +
      '\n\nNew Project Opportunities (' + total + '):\n' +
      buildText(item.opps) +
      '\n\n' + textParts[1]
    );

    try {
      List<Messaging.SendEmailResult> results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ mail },
        false
      );
      if (!results[0].isSuccess()) {
        System.debug(LoggingLevel.ERROR, 'Digest send failed: ' + results[0].getErrors());
      }
      return results[0].isSuccess();
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Digest send error: ' + e.getMessage());
      return false;
    }
  }

  // Splits a rendered HTML body into [intro, closing] at the last "Regards".
  private static List<String> splitClosingHtml(String html) {
    if (String.isBlank(html)) {
      return new List<String>{ '', '' };
    }
    String lower = html.toLowerCase();
    Integer idx = lower.lastIndexOf('regards');
    if (idx < 0) {
      return new List<String>{ html, '' };
    }
    Integer blockStart = Math.max(lower.lastIndexOf('<p', idx), lower.lastIndexOf('<div', idx));
    Integer lastClose = Math.max(lower.lastIndexOf('</p>', idx), lower.lastIndexOf('</div>', idx));
    Integer cut = (blockStart >= 0 && blockStart > lastClose) ? blockStart : idx;
    return new List<String>{ html.substring(0, cut), html.substring(cut) };
  }

  private static List<String> splitClosingText(String text) {
    if (String.isBlank(text)) {
      return new List<String>{ '', '' };
    }
    Integer idx = text.toLowerCase().lastIndexOf('regards');
    if (idx < 0) {
      return new List<String>{ text, '' };
    }
    return new List<String>{ text.substring(0, idx), text.substring(idx) };
  }

  private static String buildHtmlTable(List<Opportunity> opps) {
    String baseUrl = URL.getOrgDomainUrl().toExternalForm();
    String html =
      '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;font-size:13px;">' +
      '<tr style="background:#f3f3f3;">' +
      '<th>#</th><th>Opportunity</th><th>Department</th><th>Assigned To</th><th>Created</th>' +
      '</tr>';
    Integer rowNumber = 1;
    for (Opportunity opp : opps) {
      String oppName = String.isBlank(opp.Name) ? String.valueOf(opp.Id) : opp.Name;
      String department = opp.Department_Name__c != null ? opp.Department_Name__c : '';
      String ownerName = opp.Owner != null && opp.Owner.Name != null ? opp.Owner.Name : '';
      String createdOn = opp.CreatedDate != null
        ? opp.CreatedDate.format('dd MMM yyyy HH:mm')
        : '';
      html +=
        '<tr>' +
        '<td>' + rowNumber + '</td>' +
        '<td><a href="' + baseUrl + '/' + opp.Id + '">' + oppName.escapeHtml4() + '</a></td>' +
        '<td>' + department.escapeHtml4() + '</td>' +
        '<td>' + ownerName.escapeHtml4() + '</td>' +
        '<td>' + createdOn + '</td>' +
        '</tr>';
      rowNumber++;
    }
    return html + '</table>';
  }

  private static String buildText(List<Opportunity> opps) {
    String baseUrl = URL.getOrgDomainUrl().toExternalForm();
    List<String> lines = new List<String>();
    Integer rowNumber = 1;
    for (Opportunity opp : opps) {
      lines.add(
        rowNumber + '. ' + opp.Name + ' | ' +
        (opp.Department_Name__c != null ? opp.Department_Name__c : '') + ' | assigned to ' +
        (opp.Owner != null ? opp.Owner.Name : '') + ' | ' +
        (opp.CreatedDate != null ? opp.CreatedDate.format('dd MMM yyyy HH:mm') : '') + ' | ' +
        baseUrl + '/' + opp.Id
      );
      rowNumber++;
    }
    return String.join(lines, '\n');
  }
}