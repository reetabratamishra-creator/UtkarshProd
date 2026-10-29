/**
 * @description   Builds and sends the Unolo client visit Journey for first Task Logs on a Punch.
 * @author        Anshita Chanda
 * @date          2026-08-13
 */
public without sharing class BWM_TaskLogUnoloJourneyService {
  public static final String JOURNEY_NAME = 'unolo_client_visit';
  public static final String TRIGGER_POINT = 'Task_Log_Unolo_Client_Visit';
  public static final String WHATSAPP_TEMPLATE_NAME = 'unolo_client_visit';
  public static final String RCS_TEMPLATE_NAME = 'unolo_client_visit';

  private static final String DOCUMENT_URL =
    'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Document/Utkarsh/corporate_brochure_2026(16).pdf';
  private static final String DOCUMENT_FILE_NAME = 'corporate_brochure_2026(16).pdf';

  /**
   * @description Sends the Unolo journey for each Task Log Id after validating account phone.
   * @param taskLogIds Task Log record Ids to message.
   */
  public static void sendForTaskLogIds(List<Id> taskLogIds) {
    if (taskLogIds == null || taskLogIds.isEmpty()) {
      return;
    }

    BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
    if (settings == null || settings.Is_Enabled__c != true) {
      return;
    }

    Map<Id, Task_Log__c> taskLogById = new Map<Id, Task_Log__c>(
      [
        SELECT
          Id,
          Account__c,
          Punch_Record__c,
          OwnerId,
          Owner.Name,
          Owner.Phone,
          Owner.Email
        FROM Task_Log__c
        WHERE Id IN :taskLogIds
      ]
    );
    if (taskLogById.isEmpty()) {
      return;
    }

    Set<Id> accountIds = new Set<Id>();
    for (Task_Log__c taskLogRecord : taskLogById.values()) {
      if (taskLogRecord.Account__c != null) {
        accountIds.add(taskLogRecord.Account__c);
      }
    }

    Map<Id, Account> accountById = new Map<Id, Account>(
      [
        SELECT Id, Phone, Department_Name__c
        FROM Account
        WHERE Id IN :accountIds
      ]
    );

    String successCode = String.isBlank(settings.Journey_Success_Code__c)
      ? '200'
      : settings.Journey_Success_Code__c;
    List<Message_Log__c> logsToInsert = new List<Message_Log__c>();

    for (Id taskLogId : taskLogIds) {
      Task_Log__c taskLogRecord = taskLogById.get(taskLogId);
      if (taskLogRecord == null || taskLogRecord.Account__c == null) {
        continue;
      }

      Account accountRecord = accountById.get(taskLogRecord.Account__c);
      if (accountRecord == null) {
        continue;
      }

      String phoneNumber = resolveAccountPhone(accountRecord, settings);
      if (String.isBlank(phoneNumber)) {
        continue;
      }

      try {
        String payload = buildPayload(taskLogRecord, accountRecord, phoneNumber);
        HttpResponse response = BWM_MessagingCallout.send(payload);
        BWM_ApiResponse apiResponse = BWM_ApiResponse.parse(response, successCode);
        logsToInsert.add(
          BWM_MessageLogService.buildLogForRecord(
            taskLogRecord,
            TRIGGER_POINT,
            BWM_MessagingConstants.CHANNEL_JOURNEY,
            JOURNEY_NAME,
            phoneNumber,
            apiResponse.isSuccess
              ? BWM_MessagingConstants.LOG_STATUS_SENT
              : BWM_MessagingConstants.LOG_STATUS_FAILED,
            apiResponse,
            BWM_MessagingCallout.buildRequestCurl(payload),
            payload
          )
        );
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'Unolo journey failed for Task Log ' +
            taskLogId +
            ': ' +
            ex.getMessage()
        );
      }
    }

    BWM_MessageLogService.insertLogs(logsToInsert);
  }

  /**
   * @description Builds the Bluewave Journey payload for the Unolo client visit template.
   * @param taskLogRecord Task Log providing owner details.
   * @param accountRecord Account providing department and phone details.
   * @param phoneNumber Formatted recipient phone number.
   * @return Serialized Journey API payload.
   */
  @TestVisible
  static String buildPayload(
    Task_Log__c taskLogRecord,
    Account accountRecord,
    String phoneNumber
  ) {
    String departmentName = nullToDisplayValue(accountRecord.Department_Name__c);
    String ownerName = nullToDisplayValue(taskLogRecord.Owner.Name);
    String ownerPhone = nullToDisplayValue(taskLogRecord.Owner.Phone);
    String ownerEmail = nullToDisplayValue(taskLogRecord.Owner.Email);

    Map<String, Object> bodyData = new Map<String, Object>{
      '{{1}}' => departmentName,
      '{{2}}' => departmentName,
      '{{3}}' => ownerName,
      '{{4}}' => ownerPhone,
      '{{5}}' => ownerEmail
    };

    Map<String, Object> payload = new Map<String, Object>{
      'channel' => BWM_MessagingConstants.CHANNEL_JOURNEY,
      'to' => new List<String>{ phoneNumber },
      'content' => new Map<String, Object>{
        'data' => new Map<String, Object>{
          'journeyname' => JOURNEY_NAME,
          'journeypayload' => new Map<String, Object>{
            'nodes' => new Map<String, Object>{
              '1' => buildWhatsAppNode(
                departmentName,
                ownerName,
                ownerPhone,
                ownerEmail
              ),
              '2' => buildRcsNode(bodyData)
            }
          }
        }
      }
    };

    return JSON.serialize(payload);
  }

  @TestVisible
  static String resolveAccountPhone(
    Account accountRecord,
    BWM_Messaging_Settings__mdt settings
  ) {
    if (accountRecord == null || String.isBlank(accountRecord.Phone)) {
      return null;
    }

    return BWM_PhoneFormatter.formatForMessaging(
      accountRecord.Phone,
      settings == null ? null : settings.Default_Country_Code__c
    );
  }

  private static Map<String, Object> buildWhatsAppNode(
    String departmentName,
    String ownerName,
    String ownerPhone,
    String ownerEmail
  ) {
    return new Map<String, Object>{
      'templateType' => 'WHATSAPP',
      'data' => new Map<String, Object>{
        'templateName' => WHATSAPP_TEMPLATE_NAME,
        'headerFormat' => 'DOCUMENT',
        'headerVariables' => new List<Object>{
          new Map<String, Object>{
            'index' => 1,
            'type' => 'static',
            'value' => DOCUMENT_URL,
            'format' => 'document',
            'fileName' => DOCUMENT_FILE_NAME
          }
        },
        'bodyVariables' => new List<Object>{
          buildBodyVariable(1, departmentName),
          buildBodyVariable(2, departmentName),
          buildBodyVariable(3, ownerName),
          buildBodyVariable(4, ownerPhone),
          buildBodyVariable(5, ownerEmail)
        },
        'buttonVariables' => new List<Object>(),
        'carouselCards' => new List<Object>(),
        'limitedTimeOffer' => null
      }
    };
  }

  private static Map<String, Object> buildRcsNode(Map<String, Object> bodyData) {
    return new Map<String, Object>{
      'templateType' => 'RCSMESSAGE',
      'data' => new Map<String, Object>{
        'templateName' => RCS_TEMPLATE_NAME,
        'headerData' => new Map<String, Object>(),
        'bodyData' => bodyData,
        'footerData' => new Map<String, Object>(),
        'cardData' => new List<Object>()
      }
    };
  }

  private static Map<String, Object> buildBodyVariable(
    Integer index,
    String value
  ) {
    return new Map<String, Object>{
      'index' => index,
      'type' => 'static',
      'value' => value,
      'format' => '{{' + String.valueOf(index) + '}}'
    };
  }

  private static String nullToDisplayValue(String rawValue) {
    return String.isBlank(rawValue) ? 'NA' : rawValue.trim();
  }
}