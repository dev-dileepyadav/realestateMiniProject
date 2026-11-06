/**
 * Sends the one-month and one-day lease expiry emails.
 * Flags are updated only after Salesforce accepts the email.
 */
public without sharing class REPM_LeaseReminderBatch implements Database.Batchable<SObject> {
    @TestVisible
    private static Integer emailsSent = 0;

    public Database.QueryLocator start(Database.BatchableContext context) {
        Date monthAway = Date.today().addMonths(1);
        Date dayAway = Date.today().addDays(1);
        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    Name,
                    End_Date__c,
                    Reminder_Month_Sent__c,
                    Reminder_Day_Sent__c,
                    Tenant__r.Name,
                    Tenant__r.Email__c,
                    Property__r.Name
                FROM Lease_Agreement__c
                WHERE
                    (End_Date__c = :monthAway
                    AND Reminder_Month_Sent__c = FALSE)
                    OR (End_Date__c = :dayAway
                    AND Reminder_Day_Sent__c = FALSE)
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        Date monthAway = Date.today().addMonths(1);
        Date dayAway = Date.today().addDays(1);
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<Lease_Agreement__c> updates = new List<Lease_Agreement__c>();

        for (Lease_Agreement__c lease : (List<Lease_Agreement__c>) scope) {
            String email = lease.Tenant__r == null ? null : lease.Tenant__r.Email__c;
            if (String.isBlank(email)) {
                continue;
            }
            Boolean monthReminder = lease.End_Date__c == monthAway && lease.Reminder_Month_Sent__c == false;
            Boolean dayReminder = lease.End_Date__c == dayAway && lease.Reminder_Day_Sent__c == false;
            if (!monthReminder && !dayReminder) {
                continue;
            }

            String tenantName = String.isBlank(lease.Tenant__r.Name) ? 'Tenant' : lease.Tenant__r.Name;
            String propertyName = lease.Property__r == null ? 'your property' : lease.Property__r.Name;
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setToAddresses(new List<String>{ email });
            message.setSaveAsActivity(false);
            if (dayReminder) {
                message.setSubject('Lease agreement expires tomorrow');
                message.setPlainTextBody(
                    'Hello ' +
                        tenantName +
                        ',\n\nYour lease agreement ' +
                        lease.Name +
                        ' for ' +
                        propertyName +
                        ' expires tomorrow (' +
                        String.valueOf(lease.End_Date__c) +
                        ').\n\nPlease contact the property manager if you need to renew or move out.'
                );
            } else {
                message.setSubject('Lease agreement expires in one month');
                message.setPlainTextBody(
                    'Hello ' +
                        tenantName +
                        ',\n\nYour lease agreement ' +
                        lease.Name +
                        ' for ' +
                        propertyName +
                        ' will expire on ' +
                        String.valueOf(lease.End_Date__c) +
                        ' (one month from today).\n\nPlease contact the property manager to discuss renewal.'
                );
            }
            messages.add(message);

            Lease_Agreement__c updateRow = new Lease_Agreement__c(Id = lease.Id);
            if (monthReminder) {
                updateRow.Reminder_Month_Sent__c = true;
            }
            if (dayReminder) {
                updateRow.Reminder_Day_Sent__c = true;
            }
            updates.add(updateRow);
        }

        if (messages.isEmpty()) {
            return;
        }
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages, false);
        List<Lease_Agreement__c> successful = new List<Lease_Agreement__c>();
        for (Integer index = 0; index < results.size(); index++) {
            if (results[index].isSuccess()) {
                successful.add(updates[index]);
                emailsSent++;
            }
        }
        if (!successful.isEmpty()) {
            update successful;
        }
    }

    public void finish(Database.BatchableContext context) {
    }
}
