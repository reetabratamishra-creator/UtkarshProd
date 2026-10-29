/**
 * @description   Resolves active BWM_Template_Mapping__mdt entries for Lead/Opportunity
 *                messaging trigger points.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_TemplateResolver {
  private static final String CRM_DEPT_SCOPE_PREFIX = 'CRM:';
  private static Map<String, List<BWM_Template_Mapping__mdt>> mappingsByTriggerPoint =
    new Map<String, List<BWM_Template_Mapping__mdt>>();

  public class ResolveResult {
    public BWM_Template_Mapping__mdt mapping;
    public Boolean shouldSend = false;
    public String skipReason;
  }

  public static ResolveResult resolveForLeadCreate(Lead leadRecord) {
    ResolveResult result = new ResolveResult();

    if (leadRecord == null) {
      result.skipReason = 'Lead record is null.';
      return result;
    }

    if (leadRecord.Status != BWM_MessagingConstants.STAGE_PROSPECT) {
      result.skipReason = 'Lead stage is not Prospect.';
      return result;
    }

    List<BWM_Template_Mapping__mdt> mappings = queryAllMappings(
      BWM_MessagingConstants.TRIGGER_LEAD_CREATE
    );

    for (BWM_Template_Mapping__mdt mapping : mappings) {
      if (matchesLead(mapping, leadRecord)) {
        result.mapping = mapping;
        result.shouldSend = true;
        return result;
      }
    }

    result.skipReason = 'No active template mapping matched this lead.';
    return result;
  }

  public static ResolveResult resolve(String triggerPoint, SObject record) {
    return resolve(triggerPoint, record, null);
  }

  public static ResolveResult resolve(
    String triggerPoint,
    SObject record,
    String stageAtAction
  ) {
    ResolveResult result = new ResolveResult();

    if (String.isBlank(triggerPoint)) {
      result.skipReason = 'Trigger point is required.';
      return result;
    }

    if (record == null) {
      result.skipReason = 'Record is null.';
      return result;
    }

    List<BWM_Template_Mapping__mdt> mappings = queryAllMappings(triggerPoint);
    if (mappings.isEmpty()) {
      result.skipReason = 'No active template mapping found for trigger point.';
      return result;
    }

    String validationMessage = validateRecordForTrigger(
      triggerPoint,
      record,
      stageAtAction
    );
    if (String.isNotBlank(validationMessage)) {
      result.skipReason = validationMessage;
      return result;
    }

    if (record instanceof Lead) {
      Lead leadRecord = (Lead) record;
      BWM_Template_Mapping__mdt mapping = selectLeadMapping(
        mappings,
        leadRecord,
        triggerPoint
      );
      if (mapping != null) {
        result.mapping = mapping;
        result.shouldSend = true;
        return result;
      }
      result.skipReason = 'No active template mapping matched this lead department.';
      return result;
    }

    if (record instanceof Opportunity) {
      Opportunity opportunityRecord = (Opportunity) record;
      BWM_Template_Mapping__mdt mapping = selectOpportunityMapping(
        mappings,
        opportunityRecord,
        triggerPoint
      );
      if (mapping != null) {
        result.mapping = mapping;
        result.shouldSend = true;
        return result;
      }
      result.skipReason = 'No active template mapping matched this opportunity department.';
      return result;
    }

    result.mapping = mappings[0];
    result.shouldSend = true;
    return result;
  }

  private static List<BWM_Template_Mapping__mdt> queryAllMappings(
    String triggerPoint
  ) {
    if (mappingsByTriggerPoint.containsKey(triggerPoint)) {
      return mappingsByTriggerPoint.get(triggerPoint);
    }

    List<BWM_Template_Mapping__mdt> mappings = [
      SELECT
        Trigger_Point__c,
        Lead_Source__c,
        Lead_Stage__c,
        Department_Mode__c,
        Department_Value__c,
        WhatsApp_Template_Name__c,
        Journey_Name__c,
        RCS_Template_Name__c,
        SMS_Template_Name__c,
        SMS_Text_Template__c,
        Include_Brochure_Header__c,
        Is_Active__c,
        Priority__c,
        Param1_Field__c,
        Param2_Field__c,
        Param3_Field__c,
        Param4_Field__c,
        Param5_Field__c,
        Param6_Field__c,
        Param7_Field__c,
        Param8_Field__c,
        RCS_SMS_Param_Limit__c,
        WhatsApp_Header_Format__c,
        WhatsApp_Header_Value_Field__c,
        Document_Header_URL__c,
        Brochure_Attachment_Mode__c,
        Object_Type__c,
        Recipient_Type__c,
        Lost_Reason__c
      FROM BWM_Template_Mapping__mdt
      WHERE Is_Active__c = TRUE AND Trigger_Point__c = :triggerPoint
      ORDER BY Priority__c ASC NULLS LAST
    ];
    mappingsByTriggerPoint.put(triggerPoint, mappings);
    return mappings;
  }

  private static BWM_Template_Mapping__mdt queryMappingForTriggerPoint(
    String triggerPoint
  ) {
    List<BWM_Template_Mapping__mdt> mappings = queryAllMappings(triggerPoint);
    return mappings.isEmpty() ? null : mappings[0];
  }

  @TestVisible
  private static String validateRecordForTrigger(
    String triggerPoint,
    SObject record,
    String stageAtAction
  ) {
    if (record instanceof Lead) {
      return validateLeadTrigger(triggerPoint, (Lead) record, stageAtAction);
    }

    if (record instanceof Opportunity) {
      return validateOpportunityTrigger(
        triggerPoint,
        (Opportunity) record,
        stageAtAction
      );
    }

    return 'Unsupported object type for trigger point.';
  }

  @TestVisible
  private static String validateLeadTrigger(
    String triggerPoint,
    Lead leadRecord,
    String stageAtAction
  ) {
    if (
      triggerPoint == BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECT &&
      !isLeadStageForCallbackTrigger(
        leadRecord,
        BWM_MessagingConstants.STAGE_PROSPECT,
        stageAtAction
      )
    ) {
      return 'Lead stage must be Prospect for callback messaging.';
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECT
    ) {
      if (!isLeadStageForLostTrigger(leadRecord, BWM_MessagingConstants.STAGE_PROSPECT)) {
        return 'Lead stage must be Prospect for lost messaging.';
      }
      if (
        !BWM_MessagingConstants.OPP_LOST_DETAILS_NOT_RECEIVED.contains(
          leadRecord.Lost_Reason__c
        )
      ) {
        return 'Lost reason must be Customer details not received.';
      }
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_CALLBACK_PROSPECTING &&
      !isLeadStageForCallbackTrigger(
        leadRecord,
        BWM_MessagingConstants.STAGE_PROSPECTING,
        stageAtAction
      )
    ) {
      return 'Lead stage must be Prospecting for callback messaging.';
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_DETAILS_PROSPECTING
    ) {
      if (
        !isLeadStageForLostTrigger(
          leadRecord,
          BWM_MessagingConstants.STAGE_PROSPECTING
        )
      ) {
        return 'Lead stage must be Prospecting for lost messaging.';
      }
      if (
        !BWM_MessagingConstants.OPP_LOST_DETAILS_NOT_RECEIVED.contains(
          leadRecord.Lost_Reason__c
        )
      ) {
        return 'Lost reason must be Customer details not received.';
      }
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_LEAD_TASK_LOST_NOT_RESPONDING_PROSPECTING
    ) {
      if (
        !isLeadStageForLostTrigger(
          leadRecord,
          BWM_MessagingConstants.STAGE_PROSPECTING
        )
      ) {
        return 'Lead stage must be Prospecting for lost messaging.';
      }
      if (
        !BWM_MessagingConstants.LEAD_LOST_NOT_RESPONDING.contains(
          leadRecord.Lost_Reason__c
        )
      ) {
        return 'Lost reason must be Not responding.';
      }
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING &&
      leadRecord.Status != BWM_MessagingConstants.STAGE_PROSPECT &&
      leadRecord.Status != BWM_MessagingConstants.STAGE_PROSPECTING
    ) {
      return 'Lead stage must be Prospect or Prospecting for details-not-received messaging.';
    }

    return null;
  }

  @TestVisible
  private static Boolean isLeadStageForCallbackTrigger(
    Lead leadRecord,
    String expectedStage,
    String stageAtAction
  ) {
    if (leadRecord.Status == expectedStage) {
      return true;
    }

    return String.isNotBlank(stageAtAction) && stageAtAction == expectedStage;
  }

  @TestVisible
  private static Boolean isOpportunityStageForCallbackTrigger(
    Opportunity opportunityRecord,
    String expectedStage,
    String stageAtAction
  ) {
    if (opportunityRecord.StageName == expectedStage) {
      return true;
    }

    return String.isNotBlank(stageAtAction) && stageAtAction == expectedStage;
  }

  @TestVisible
  private static Boolean isLeadStageForLostTrigger(
    Lead leadRecord,
    String expectedStage
  ) {
    if (leadRecord.Status == expectedStage) {
      return true;
    }

    return leadRecord.Status == BWM_MessagingConstants.STAGE_LOST &&
      String.isNotBlank(leadRecord.Lost_Reason__c);
  }

  @TestVisible
  private static String validateOpportunityTrigger(
    String triggerPoint,
    Opportunity opportunityRecord,
    String stageAtAction
  ) {
    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE &&
      !isOpportunityStageForCallbackTrigger(
        opportunityRecord,
        BWM_MessagingConstants.STAGE_NURTURE,
        stageAtAction
      ) &&
      !isOpportunityStageForCallbackTrigger(
        opportunityRecord,
        BWM_MessagingConstants.STAGE_NEGOTIATION,
        stageAtAction
      )
    ) {
      return 'Opportunity stage must be Nurture or Negotiation for callback messaging.';
    }

    if (
      triggerPoint == BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUALIFY_NURTURE &&
      opportunityRecord.StageName != BWM_MessagingConstants.STAGE_NURTURE
    ) {
      return 'Opportunity stage must be Nurture.';
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_DETAILS_NOT_RECEIVED_NURTURE &&
      opportunityRecord.StageName != BWM_MessagingConstants.STAGE_NURTURE
    ) {
      return 'Opportunity stage must be Nurture for details-not-received messaging.';
    }

    if (
      triggerPoint == BWM_MessagingConstants.TRIGGER_OPP_LOST_DETAILS_NURTURE
    ) {
      if (!isNurtureStageForLost(opportunityRecord.StageName)) {
        return 'Opportunity stage must be Nurture for lost messaging.';
      }
      if (
        !BWM_MessagingConstants.OPP_LOST_DETAILS_NOT_RECEIVED.contains(
          opportunityRecord.Lost_Reason__c
        )
      ) {
        return 'Lost reason must be Customer details not received.';
      }
    }

    if (
      triggerPoint == BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NURTURE
    ) {
      if (!isNurtureStageForLost(opportunityRecord.StageName)) {
        return 'Opportunity stage must be Nurture for lost messaging.';
      }
      if (
        !BWM_MessagingConstants.LEAD_LOST_NOT_RESPONDING.contains(
          opportunityRecord.Lost_Reason__c
        )
      ) {
        return 'Lost reason must be Not responding.';
      }
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_OPP_LOST_NOT_RESPONDING_NEGOTIATION
    ) {
      if (!isNegotiationStageForLost(opportunityRecord.StageName)) {
        return 'Opportunity stage must be Negotiation for lost messaging.';
      }
      if (
        !BWM_MessagingConstants.LEAD_LOST_NOT_RESPONDING.contains(
          opportunityRecord.Lost_Reason__c
        )
      ) {
        return 'Lost reason must be Not responding.';
      }
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_NEGOTIATION_STALE_30_DAYS
    ) {
      if (opportunityRecord.IsClosed) {
        return 'Opportunity must be open.';
      }
      if (opportunityRecord.StageName != BWM_MessagingConstants.STAGE_NEGOTIATION) {
        return 'Opportunity stage must be Negotiation.';
      }
      if (
        opportunityRecord.Sub_Stage__c != BWM_MessagingConstants.SUB_STAGE_ACTIVE &&
        opportunityRecord.Sub_Stage__c != BWM_MessagingConstants.SUB_STAGE_BUDGETARY
      ) {
        return 'Sub Stage must be Active or Budgetary.';
      }
    }

    if (triggerPoint == BWM_MessagingConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER) {
      if (
        opportunityRecord.Customer_Journey__c !=
        BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER
      ) {
        return 'Customer Journey must be Refer to Dealer.';
      }
      if (opportunityRecord.DealerAccount__c == null) {
        return 'Dealer account is required.';
      }
    }

    if (
      triggerPoint == BWM_MessagingConstants.TRIGGER_OPP_CLOSED_WON_REFER_DEALER
    ) {
      if (opportunityRecord.StageName != BWM_MessagingConstants.STAGE_CLOSED_WON) {
        return 'Opportunity stage must be Closed Won.';
      }
      if (
        opportunityRecord.Customer_Journey__c !=
        BWM_MessagingConstants.CUSTOMER_JOURNEY_REFER_DEALER
      ) {
        return 'Customer Journey must be Refer to Dealer.';
      }
    }

    if (
      triggerPoint == BWM_MessagingConstants.TRIGGER_OPP_CLOSED_WON_DIRECT_BUSINESS
    ) {
      if (opportunityRecord.StageName != BWM_MessagingConstants.STAGE_CLOSED_WON) {
        return 'Opportunity stage must be Closed Won.';
      }
      if (
        opportunityRecord.Customer_Journey__c !=
        BWM_MessagingConstants.CUSTOMER_JOURNEY_DIRECT
      ) {
        return 'Customer Journey must be Direct Business.';
      }
    }

    if (
      triggerPoint ==
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_QUOTE_EXPIRY_REMINDER
    ) {
      if (opportunityRecord.IsClosed) {
        return 'Opportunity must be open.';
      }
      if (opportunityRecord.Quotation_Date__c == null) {
        return 'Quotation Date is required.';
      }
    }

    return null;
  }

  @TestVisible
  private static Boolean isNurtureStageForLost(String stageName) {
    return stageName == BWM_MessagingConstants.STAGE_NURTURE ||
      stageName == BWM_MessagingConstants.STAGE_CLOSED_LOST;
  }

  private static Boolean isNegotiationStageForLost(String stageName) {
    return stageName == BWM_MessagingConstants.STAGE_NEGOTIATION ||
      stageName == BWM_MessagingConstants.STAGE_CLOSED_LOST;
  }

  private static BWM_Template_Mapping__mdt selectLeadMapping(
    List<BWM_Template_Mapping__mdt> mappings,
    Lead leadRecord,
    String triggerPoint
  ) {
    String departmentName = leadRecord.Department_Name__c;

    if (shouldPreferGeneralTemplate(leadRecord, departmentName)) {
      BWM_Template_Mapping__mdt scopedMapping = selectScopedCrmHeadMapping(
        mappings,
        departmentName,
        triggerPoint,
        leadRecord
      );
      if (scopedMapping != null) {
        return scopedMapping;
      }
      for (BWM_Template_Mapping__mdt mapping : mappings) {
        if (isProductDeptMapping(mapping) || isCrmDepartmentScopedMapping(mapping)) {
          continue;
        }
        if (!stageApplies(triggerPoint, mapping, leadRecord)) {
          continue;
        }
        if (isGeneralMapping(mapping)) {
          return mapping;
        }
      }
    }

    for (BWM_Template_Mapping__mdt mapping : mappings) {
      if (!stageApplies(triggerPoint, mapping, leadRecord)) {
        continue;
      }
      if (matchesDepartment(mapping, departmentName)) {
        return mapping;
      }
    }

    return null;
  }

  private static BWM_Template_Mapping__mdt selectOpportunityMapping(
    List<BWM_Template_Mapping__mdt> mappings,
    Opportunity opportunityRecord,
    String triggerPoint
  ) {
    String departmentName = opportunityRecord.Department_Name__c;

    if (shouldPreferGeneralTemplateForOpportunity(opportunityRecord, departmentName)) {
      BWM_Template_Mapping__mdt scopedMapping = selectScopedCrmHeadMapping(
        mappings,
        departmentName,
        triggerPoint,
        opportunityRecord
      );
      if (scopedMapping != null) {
        return scopedMapping;
      }
      for (BWM_Template_Mapping__mdt mapping : mappings) {
        if (isProductDeptMapping(mapping) || isCrmDepartmentScopedMapping(mapping)) {
          continue;
        }
        if (!stageApplies(triggerPoint, mapping, opportunityRecord)) {
          continue;
        }
        if (isGeneralMapping(mapping)) {
          return mapping;
        }
      }
    }

    for (BWM_Template_Mapping__mdt mapping : mappings) {
      if (!stageApplies(triggerPoint, mapping, opportunityRecord)) {
        continue;
      }
      if (matchesDepartment(mapping, departmentName)) {
        return mapping;
      }
    }

    return null;
  }

  /**
   * Prospect and Prospecting share Lead_Details_Not_Received_Prospecting.
   * Nurture and Negotiation share Opportunity_Task_Callback_Nurture.
   * Lead_Stage__c is honored only on those two triggers, and only when it is set.
   */
  private static Boolean stageApplies(
    String triggerPoint,
    BWM_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (
      triggerPoint !=
      BWM_MessagingConstants.TRIGGER_LEAD_DETAILS_NOT_RECEIVED_PROSPECTING &&
      triggerPoint != BWM_MessagingConstants.TRIGGER_OPPORTUNITY_TASK_CALLBACK_NURTURE
    ) {
      return true;
    }
    if (mapping == null || String.isBlank(mapping.Lead_Stage__c)) {
      return true;
    }

    String stageName;
    if (record instanceof Lead) {
      stageName = ((Lead) record).Status;
    } else if (record instanceof Opportunity) {
      stageName = ((Opportunity) record).StageName;
    }
    return mapping.Lead_Stage__c == stageName;
  }

  private static Boolean shouldPreferGeneralTemplate(
    Lead leadRecord,
    String departmentName
  ) {
    if (!isProductDepartment(departmentName)) {
      return false;
    }
    return ownerMatchesCrmUserName(leadRecord);
  }

  private static Boolean shouldPreferGeneralTemplateForOpportunity(
    Opportunity opportunityRecord,
    String departmentName
  ) {
    if (!isProductDepartment(departmentName)) {
      return false;
    }
    return BWM_CampaignJourneyParamService.ownerMatchesCrmUserName(
      opportunityRecord
    );
  }

  private static Boolean isProductDepartment(String departmentName) {
    return String.isNotBlank(departmentName) &&
      BWM_MessagingConstants.PRODUCT_DEPARTMENTS.contains(departmentName);
  }

  private static Boolean ownerMatchesCrmUserName(Lead leadRecord) {
    if (leadRecord == null) {
      return false;
    }

    String crmUserName = leadRecord.CRM_User_Name_Formula__c;
    String ownerName = leadRecord.Owner == null ? null : leadRecord.Owner.Name;

    return String.isNotBlank(crmUserName) &&
      String.isNotBlank(ownerName) &&
      crmUserName.trim().equalsIgnoreCase(ownerName.trim());
  }

  private static Boolean isProductDeptMapping(BWM_Template_Mapping__mdt mapping) {
    return mapping.Department_Mode__c ==
      BWM_MessagingConstants.DEPT_MODE_ANY_PRODUCT;
  }

  private static Boolean isGeneralMapping(BWM_Template_Mapping__mdt mapping) {
    return mapping.Department_Mode__c == BWM_MessagingConstants.DEPT_MODE_LIST;
  }

  /**
   * CRM-head mappings scoped to named departments use Department_Value CRM:Dept|Dept.
   * A plain LIST is still the fallback for every other product department.
   */
  private static BWM_Template_Mapping__mdt selectScopedCrmHeadMapping(
    List<BWM_Template_Mapping__mdt> mappings,
    String departmentName,
    String triggerPoint,
    SObject record
  ) {
    if (String.isBlank(departmentName)) {
      return null;
    }

    for (BWM_Template_Mapping__mdt mapping : mappings) {
      if (!isCrmDepartmentScopedMapping(mapping)) {
        continue;
      }
      if (!stageApplies(triggerPoint, mapping, record)) {
        continue;
      }
      String departmentList = mapping.Department_Value__c.substring(
        CRM_DEPT_SCOPE_PREFIX.length()
      );
      if (matchesDepartmentList(departmentList.replace('|', ','), departmentName)) {
        return mapping;
      }
    }

    return null;
  }

  private static Boolean isCrmDepartmentScopedMapping(
    BWM_Template_Mapping__mdt mapping
  ) {
    return mapping != null &&
      isGeneralMapping(mapping) &&
      String.isNotBlank(mapping.Department_Value__c) &&
      mapping.Department_Value__c.startsWith(CRM_DEPT_SCOPE_PREFIX);
  }

  @TestVisible
  private static Boolean matchesLead(
    BWM_Template_Mapping__mdt mapping,
    Lead leadRecord
  ) {
    if (
      String.isNotBlank(mapping.Lead_Stage__c) &&
      mapping.Lead_Stage__c != leadRecord.Status
    ) {
      return false;
    }

    if (
      String.isNotBlank(mapping.Lead_Source__c) &&
      mapping.Lead_Source__c != leadRecord.LeadSource
    ) {
      return false;
    }

    return matchesDepartment(mapping, leadRecord.Department_Name__c);
  }

  @TestVisible
  private static Boolean matchesDepartment(
    BWM_Template_Mapping__mdt mapping,
    String departmentName
  ) {
    String mode = mapping.Department_Mode__c;

    if (mode == BWM_MessagingConstants.DEPT_MODE_ENQUIRY_ONLY) {
      return departmentName == BWM_MessagingConstants.DEPT_ENQUIRY;
    }

    if (mode == BWM_MessagingConstants.DEPT_MODE_ANY_PRODUCT) {
      return String.isNotBlank(departmentName) &&
        departmentName != BWM_MessagingConstants.DEPT_ENQUIRY &&
        BWM_MessagingConstants.PRODUCT_DEPARTMENTS.contains(departmentName);
    }

    if (mode == BWM_MessagingConstants.DEPT_MODE_SPECIFIC) {
      return departmentName == mapping.Department_Value__c;
    }

    if (mode == BWM_MessagingConstants.DEPT_MODE_LIST) {
      return matchesDepartmentList(mapping.Department_Value__c, departmentName);
    }

    return true;
  }

  @TestVisible
  private static Boolean matchesDepartmentList(
    String departmentValueCsv,
    String departmentName
  ) {
    if (String.isBlank(departmentValueCsv) || String.isBlank(departmentName)) {
      return false;
    }

    for (String rawValue : departmentValueCsv.split(',')) {
      if (String.isBlank(rawValue)) {
        continue;
      }
      if (rawValue.trim() == departmentName.trim()) {
        return true;
      }
    }
    return false;
  }
}