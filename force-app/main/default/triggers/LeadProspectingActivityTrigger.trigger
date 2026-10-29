/**
 * @description Deprecated duplicate Lead before-trigger.
 *              Prospecting activity logic runs from LeadTrigger only
 *              (single-trigger best practice).
 */
trigger LeadProspectingActivityTrigger on Lead (before insert, before update) {
  // Intentionally empty — LeadTrigger → LeadProspectingActivityHandler.
}