public without sharing class BWM_EmailDailyScheduler implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(new BWM_EmailQuoteExpiryReminderBatch(), 50);
  }
}