/**
 * Corrects property occupancy when a lease starts or ends without a later edit.
 */
public without sharing class REPM_OccupancySyncBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        Date today = Date.today();
        String occupied = REPM_Constants.OCCUPIED;
        return Database.getQueryLocator(
            [
                SELECT Property__c
                FROM Lease_Agreement__c
                WHERE
                    Property__c != NULL
                    AND ((Start_Date__c <= :today
                    AND End_Date__c >= :today
                    AND Property__r.Status__c != :occupied)
                    OR (End_Date__c < :today
                    AND Property__r.Status__c = :occupied))
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        Set<Id> propertyIds = new Set<Id>();
        for (Lease_Agreement__c lease : (List<Lease_Agreement__c>) scope) {
            propertyIds.add(lease.Property__c);
        }
        REPM_LeaseTriggerHandler.syncOccupancy(propertyIds);
    }

    public void finish(Database.BatchableContext context) {
    }
}
