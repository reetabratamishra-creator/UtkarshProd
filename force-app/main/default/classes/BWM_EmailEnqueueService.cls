/**
 * @description   Enqueues BWM_EmailQueueable jobs for auto and campaign email sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_EmailEnqueueService {
  public static final String BYPASS_PERMISSION = 'BWM_Bypass_Auto_Messaging';

  /**
   * @description Enqueues email requests on BWM_EmailQueueable, or skips with a warning if queueable limits are reached.
   * @param requests List of BWM_EmailRequest payloads to process asynchronously.
   */
  public static void enqueue(List<BWM_EmailRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }

    if (FeatureManagement.checkPermission(BYPASS_PERMISSION)) {
      System.debug(
        LoggingLevel.WARN,
        'BWM email skipped: running user has ' + BYPASS_PERMISSION + '.'
      );
      return;
    }

    if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
      System.debug(
        LoggingLevel.WARN,
        'BWM email skipped: queueable limit reached in this transaction.'
      );
      return;
    }

    System.enqueueJob(new BWM_EmailQueueable(requests));
  }

  /**
   * @description Builds lead-create email requests for the given Lead Ids and enqueues them.
   * @param leadIds Lead record Ids that triggered create-time email.
   */
  public static void enqueueLeadCreate(List<Id> leadIds) {
    List<BWM_EmailRequest> requests = new List<BWM_EmailRequest>();
    for (Id leadId : leadIds) {
      requests.add(
        new BWM_EmailRequest(leadId, BWM_EmailConstants.TRIGGER_LEAD_CREATE)
      );
    }
    enqueue(requests);
  }

  /**
   * @description Enqueues a single email request for the given record and trigger point.
   * @param recordId Id of the Lead or Opportunity (or related record) to email.
   * @param triggerPoint Journey/trigger key identifying which email path to run.
   */
  public static void enqueue(Id recordId, String triggerPoint) {
    enqueue(
      new List<BWM_EmailRequest>{
        new BWM_EmailRequest(recordId, triggerPoint)
      }
    );
  }
}