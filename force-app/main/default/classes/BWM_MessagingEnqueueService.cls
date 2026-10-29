/**
 * @description   Enqueues BWM_MessagingQueueable for messaging sends, with Future
 *                fallback when queueable governor limits are reached.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_MessagingEnqueueService {
  /**
   * @description Enqueues messaging requests on a queueable, or falls back to Future when queueable limits are hit.
   * @param requests List of BWM_MessagingRequest payloads to process asynchronously.
   */
  public static void enqueue(List<BWM_MessagingRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }

    if (
      FeatureManagement.checkPermission(BWM_EmailEnqueueService.BYPASS_PERMISSION)
    ) {
      System.debug(
        LoggingLevel.WARN,
        'BWM messaging skipped: running user has ' +
          BWM_EmailEnqueueService.BYPASS_PERMISSION +
          '.'
      );
      return;
    }

    if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
      System.enqueueJob(new BWM_MessagingQueueable(requests));
      return;
    }

    BWM_MessagingFutureDispatcher.dispatch(requests);
  }

  /**
   * @description Builds lead-create messaging requests for the given Lead Ids and enqueues them.
   * @param leadIds Lead record Ids that triggered create-time messaging.
   */
  public static void enqueueLeadCreate(List<Id> leadIds) {
    List<BWM_MessagingRequest> requests = new List<BWM_MessagingRequest>();
    for (Id leadId : leadIds) {
      requests.add(
        new BWM_MessagingRequest(leadId, BWM_MessagingConstants.TRIGGER_LEAD_CREATE)
      );
    }
    enqueue(requests);
  }

  /**
   * @description Enqueues a single messaging request for the given record and trigger point.
   * @param recordId Id of the Lead or Opportunity (or related record) to message.
   * @param triggerPoint Journey/trigger key identifying which messaging path to run.
   */
  public static void enqueue(Id recordId, String triggerPoint) {
    enqueue(
      new List<BWM_MessagingRequest>{
        new BWM_MessagingRequest(recordId, triggerPoint)
      }
    );
  }
}