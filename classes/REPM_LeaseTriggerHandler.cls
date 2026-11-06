/**
 * Keeps property occupancy aligned with the lease that is active today
 * and resets reminder flags when an end date changes.
 */
public without sharing class REPM_LeaseTriggerHandler {
    public static void beforeUpdate(List<Lease_Agreement__c> leases, Map<Id, Lease_Agreement__c> oldMap) {
        for (Lease_Agreement__c lease : leases) {
            if (lease.End_Date__c != oldMap.get(lease.Id).End_Date__c) {
                lease.Reminder_Month_Sent__c = false;
                lease.Reminder_Day_Sent__c = false;
            }
        }
    }

    public static void afterChange(List<Lease_Agreement__c> leases) {
        if (REPM_TriggerBypass.skipOccupancySync || leases == null) {
            return;
        }
        Set<Id> propertyIds = new Set<Id>();
        for (Lease_Agreement__c lease : leases) {
            if (lease.Property__c != null) {
                propertyIds.add(lease.Property__c);
            }
        }
        syncOccupancy(propertyIds);
    }

    public static void syncOccupancy(Set<Id> propertyIds) {
        if (propertyIds == null || propertyIds.isEmpty()) {
            return;
        }
        Date today = Date.today();
        Map<Id, Lease_Agreement__c> activeByProperty = new Map<Id, Lease_Agreement__c>();
        for (Lease_Agreement__c lease : [
            SELECT Id, Property__c, Tenant__c
            FROM Lease_Agreement__c
            WHERE Property__c IN :propertyIds AND Start_Date__c <= :today AND End_Date__c >= :today
            ORDER BY Start_Date__c DESC, CreatedDate DESC
        ]) {
            if (!activeByProperty.containsKey(lease.Property__c)) {
                activeByProperty.put(lease.Property__c, lease);
            }
        }

        List<Property__c> updates = new List<Property__c>();
        for (Id propertyId : propertyIds) {
            Lease_Agreement__c activeLease = activeByProperty.get(propertyId);
            Property__c property = new Property__c(Id = propertyId);
            if (activeLease == null) {
                property.Status__c = REPM_Constants.AVAILABLE;
                property.Tenant__c = null;
            } else {
                property.Status__c = REPM_Constants.OCCUPIED;
                property.Tenant__c = activeLease.Tenant__c;
            }
            updates.add(property);
        }

        // System occupancy updates are not a new tenant assignment, so they must not open another lease task.
        REPM_TriggerBypass.skipLeaseTask = true;
        try {
            update updates;
        } finally {
            REPM_TriggerBypass.skipLeaseTask = false;
        }
    }
}
