/**
 * @description   AuraEnabled API for Offline Campaign search and
 *                Journey/WhatsApp/RCS/SMS/Email sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class OfflineCampaignManagementController {
  /**
   * @description Searches active Offline_Campaign__c records by optional name, phone, email, and department.
   * @param searchTerm Optional Name LIKE filter.
   * @param phoneFilter Optional Phone__c LIKE filter.
   * @param emailFilter Optional Email__c LIKE filter.
   * @param departmentFilter Optional Department__c LIKE filter.
   * @return Matching Offline_Campaign__c records ordered by CreatedDate descending (max 5000).
   */
  @AuraEnabled
  public static List<Offline_Campaign__c> searchOfflineCampaigns(
    String searchTerm,
    String phoneFilter,
    String emailFilter,
    String departmentFilter
  ) {
    String namePattern = String.isNotBlank(searchTerm)
      ? '%' + searchTerm.trim() + '%'
      : null;
    String phonePattern = String.isNotBlank(phoneFilter)
      ? '%' + phoneFilter.trim() + '%'
      : null;
    String emailPattern = String.isNotBlank(emailFilter)
      ? '%' + emailFilter.trim() + '%'
      : null;
    String departmentPattern = String.isNotBlank(departmentFilter)
      ? '%' + departmentFilter.trim() + '%'
      : null;

    String soql =
      'SELECT Id, Name, Phone__c, Email__c, Department__c, Active__c, CreatedDate FROM Offline_Campaign__c WHERE Active__c = true';
    if (namePattern != null) {
      soql += ' AND Name LIKE :namePattern';
    }
    if (phonePattern != null) {
      soql += ' AND Phone__c LIKE :phonePattern';
    }
    if (emailPattern != null) {
      soql += ' AND Email__c LIKE :emailPattern';
    }
    if (departmentPattern != null) {
      soql += ' AND Department__c LIKE :departmentPattern';
    }
    soql += ' ORDER BY CreatedDate DESC LIMIT 5000';
    return Database.query(soql);
  }

  /**
   * @description Sends Infobip campaign email to the selected Offline Campaign records.
   * @param offlineCampaignIds Offline_Campaign__c Ids to send email to.
   * @param infobipTemplateId Infobip email template identifier.
   * @return SendCampaignEmailResult from BWM_CampaignEmailService.
   */
  @AuraEnabled
  public static BWM_CampaignEmailService.SendCampaignEmailResult sendOfflineCampaignEmail(
    List<Id> offlineCampaignIds,
    String infobipTemplateId
  ) {
    try {
      return BWM_CampaignEmailService.sendToOfflineCampaigns(
        offlineCampaignIds,
        infobipTemplateId
      );
    } catch (Exception ex) {
      throw new AuraHandledException(ex.getMessage());
    }
  }

  @AuraEnabled
  public static BWM_CampaignEmailService.SendCampaignEmailResult sendOfflineCampaignEmailScheduled(
    List<Id> offlineCampaignIds,
    String infobipTemplateId,
    String scheduledDateTime
  ) {
    BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
    try {
      return sendOfflineCampaignEmail(offlineCampaignIds, infobipTemplateId);
    } finally {
      BWM_CampaignScheduleContext.clear();
    }
  }

  /**
   * @description Loads Bluewave/Infobip email template options for the Offline Campaign UI.
   * @return List of TemplateOption values from BWM_InfobipEmailTemplateService.
   */
  @AuraEnabled
  public static List<BWM_InfobipEmailTemplateService.TemplateOption> getBluewaveEmailTemplates() {
    try {
      return BWM_InfobipEmailTemplateService.fetchTemplates();
    } catch (Exception ex) {
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * @description Returns active campaign journey options for Offline Campaign sends.
   * @return List of JourneyOption values from BWM_JourneyDefinitionService.
   */
  @AuraEnabled
  public static List<BWM_JourneyDefinitionService.JourneyOption> getCampaignJourneys() {
    return BWM_JourneyDefinitionService.fetchActiveJourneys();
  }

  /**
   * @description Starts the selected campaign journey for the given Offline Campaign records.
   * @param offlineCampaignIds Offline_Campaign__c Ids to enroll in the journey.
   * @param journeyName Name of the journey definition to send.
   * @return SendJourneyResult from BWM_CampaignJourneyService.
   */
  @AuraEnabled
  public static BWM_JourneyDefinitionService.SendJourneyResult sendOfflineCampaignJourney(
    List<Id> offlineCampaignIds,
    String journeyName
  ) {
    return BWM_CampaignJourneyService.sendToOfflineCampaigns(
      offlineCampaignIds,
      journeyName
    );
  }

  /**
   * @description Starts the selected campaign journey at the given UTC schedule time.
   * @param offlineCampaignIds Offline Campaign Ids to enroll in the journey.
   * @param journeyName Name of the journey definition to send.
   * @param scheduledDateTime UTC timestamp yyyy-MM-ddTHH:mm:ssZ written to scheduledatetime.
   * @return SendJourneyResult from BWM_CampaignJourneyService.
   */
  @AuraEnabled
  public static BWM_JourneyDefinitionService.SendJourneyResult sendOfflineCampaignJourneyScheduled(
    List<Id> offlineCampaignIds,
    String journeyName,
    String scheduledDateTime
  ) {
    return BWM_CampaignJourneyService.sendToOfflineCampaigns(
      offlineCampaignIds,
      journeyName,
      scheduledDateTime
    );
  }

  /**
   * @description Loads approved WhatsApp template options for Offline Campaign sends.
   * @return List of WhatsAppTemplateOption values.
   */
  @AuraEnabled
  public static List<LeadManagementWhatsAppService.WhatsAppTemplateOption> getWhatsAppTemplates() {
    return LeadManagementWhatsAppService.fetchApprovedTemplates();
  }

  /**
   * @description Sends a WhatsApp template message to the selected Offline Campaign records.
   * @param offlineCampaignIds Offline_Campaign__c Ids to message.
   * @param templateName Approved WhatsApp template name.
   * @return SendWhatsAppResult with send outcome details.
   */
  @AuraEnabled
  public static LeadManagementWhatsAppService.SendWhatsAppResult sendOfflineCampaignWhatsApp(
    List<Id> offlineCampaignIds,
    String templateName
  ) {
    return OfflineCampaignManagementWhatsAppService.sendToOfflineCampaigns(
      offlineCampaignIds,
      templateName
    );
  }

  /**
   * @description Loads approved RCS template options for Offline Campaign sends.
   * @return List of RcsTemplateOption values.
   */
  @AuraEnabled
  public static List<LeadManagementRcsService.RcsTemplateOption> getRcsTemplates() {
    return LeadManagementRcsService.fetchApprovedTemplates();
  }

  /**
   * @description Sends an RCS template message to the selected Offline Campaign records.
   * @param offlineCampaignIds Offline_Campaign__c Ids to message.
   * @param templateName Approved RCS template name.
   * @return SendRcsResult with send outcome details.
   */
  @AuraEnabled
  public static OfflineCampaignManagementRcsService.SendRcsResult sendOfflineCampaignRcs(
    List<Id> offlineCampaignIds,
    String templateName
  ) {
    return OfflineCampaignManagementRcsService.sendToOfflineCampaigns(
      offlineCampaignIds,
      templateName
    );
  }

  @AuraEnabled
  public static OfflineCampaignManagementRcsService.SendRcsResult sendOfflineCampaignRcsScheduled(
    List<Id> offlineCampaignIds,
    String templateName,
    String scheduledDateTime
  ) {
    BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
    try {
      return sendOfflineCampaignRcs(offlineCampaignIds, templateName);
    } finally {
      BWM_CampaignScheduleContext.clear();
    }
  }

  /**
   * @description Loads approved SMS template options for Offline Campaign sends.
   * @return List of SmsTemplateOption values.
   */
  @AuraEnabled
  public static List<BWM_SmsTemplateService.SmsTemplateOption> getSmsTemplates() {
    return BWM_SmsTemplateService.fetchApprovedTemplates();
  }

  /**
   * @description Sends an SMS template message to the selected Offline Campaign records.
   * @param offlineCampaignIds Offline_Campaign__c Ids to message.
   * @param templateName Approved SMS template name.
   * @return SendSmsResult with send outcome details.
   */
  @AuraEnabled
  public static OfflineCampaignManagementSmsService.SendSmsResult sendOfflineCampaignSms(
    List<Id> offlineCampaignIds,
    String templateName
  ) {
    return OfflineCampaignManagementSmsService.sendToOfflineCampaigns(
      offlineCampaignIds,
      templateName
    );
  }

  @AuraEnabled
  public static OfflineCampaignManagementSmsService.SendSmsResult sendOfflineCampaignSmsScheduled(
    List<Id> offlineCampaignIds,
    String templateName,
    String scheduledDateTime
  ) {
    BWM_CampaignScheduleContext.setScheduledDateTime(scheduledDateTime);
    try {
      return sendOfflineCampaignSms(offlineCampaignIds, templateName);
    } finally {
      BWM_CampaignScheduleContext.clear();
    }
  }
}