/**
 * @description   Before-insert Event guard trigger related to journey activity
 *                protection.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
trigger EventJourneyGuard on Event (before insert) {
  try {
    ActivityJourneyGuardHandler.guardBeforeInsert(Trigger.new);
  } catch (Exception ex) {
    System.debug(
      LoggingLevel.ERROR,
      'EventJourneyGuard failed: ' +
        ex.getMessage() +
        '\nStack Trace: ' +
        ex.getStackTraceString()
    );
  }
}