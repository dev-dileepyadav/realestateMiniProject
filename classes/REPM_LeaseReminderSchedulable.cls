/**
 * Daily entry point for lease reminders and occupancy corrections.
 */
public with sharing class REPM_LeaseReminderSchedulable implements Schedulable {
    public void execute(SchedulableContext context) {
        Database.executeBatch(new REPM_LeaseReminderBatch(), 50);
        Database.executeBatch(new REPM_OccupancySyncBatch(), 50);
    }
}
