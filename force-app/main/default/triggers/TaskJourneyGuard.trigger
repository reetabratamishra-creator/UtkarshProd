/**
 * @description   Before-insert Task guard trigger related to journey activity
 *                protection.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
trigger TaskJourneyGuard on Task (before insert) {
  try {
    ActivityJourneyGuardHandler.guardBeforeInsert(Trigger.new);
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'TaskJourneyGuard failed: ' +
        ex.getMessage() +
        '\nStack Trace: ' +
        ex.getStackTraceString()
    );
  }
}