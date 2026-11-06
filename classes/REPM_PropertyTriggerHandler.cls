/**
 * Creates a lease-generation task when a tenant is assigned and queues address geocoding.
 * without sharing so the assignment task is created for every property the user can edit.
 */
public without sharing class REPM_PropertyTriggerHandler {
    public static void afterInsert(List<Property__c> properties) {
        createLeaseTasks(properties, null);
        enqueueGeocoding(properties, null);
    }

    public static void afterUpdate(List<Property__c> properties, Map<Id, Property__c> oldMap) {
        createLeaseTasks(properties, oldMap);
        enqueueGeocoding(properties, oldMap);
    }

    private static void createLeaseTasks(List<Property__c> properties, Map<Id, Property__c> oldMap) {
        if (REPM_TriggerBypass.skipLeaseTask) {
            return;
        }
        Set<Id> tenantIds = new Set<Id>();
        List<Property__c> assigned = new List<Property__c>();
        for (Property__c property : properties) {
            Id previousTenant = oldMap == null ? null : oldMap.get(property.Id).Tenant__c;
            if (property.Tenant__c != null && property.Tenant__c != previousTenant) {
                assigned.add(property);
                tenantIds.add(property.Tenant__c);
            }
        }
        if (assigned.isEmpty()) {
            return;
        }

        Map<Id, Tenant__c> tenants = new Map<Id, Tenant__c>([SELECT Id, Name FROM Tenant__c WHERE Id IN :tenantIds]);
        List<Task> tasks = new List<Task>();
        for (Property__c property : assigned) {
            Tenant__c tenant = tenants.get(property.Tenant__c);
            String tenantName = tenant == null ? 'the assigned tenant' : tenant.Name;
            tasks.add(
                new Task(
                    Subject = REPM_Constants.TASK_SUBJECT,
                    Status = 'Not Started',
                    Priority = 'High',
                    WhatId = property.Id,
                    ActivityDate = Date.today().addDays(3),
                    OwnerId = UserInfo.getUserId(),
                    Description = 'Generate the lease agreement for ' +
                        tenantName +
                        ' on property ' +
                        property.Name +
                        '.'
                )
            );
        }
        insert tasks;
    }

    private static void enqueueGeocoding(List<Property__c> properties, Map<Id, Property__c> oldMap) {
        if (!REPM_TriggerBypass.geocodeEnabled()) {
            return;
        }
        List<Id> propertyIds = new List<Id>();
        for (Property__c property : properties) {
            Property__c previous = oldMap == null ? null : oldMap.get(property.Id);
            if (!addressChanged(property, previous)) {
                continue;
            }
            if (previous == null && property.Location__Latitude__s != null && property.Location__Longitude__s != null) {
                continue;
            }
            propertyIds.add(property.Id);
        }
        if (!propertyIds.isEmpty()) {
            System.enqueueJob(new REPM_PropertyGeocodeQueueable(propertyIds));
        }
    }

    private static Boolean addressChanged(Property__c current, Property__c previous) {
        if (previous == null) {
            return true;
        }
        return current.Address__c != previous.Address__c ||
            current.City__c != previous.City__c ||
            current.State__c != previous.State__c ||
            current.Postal_Code__c != previous.Postal_Code__c ||
            current.Country__c != previous.Country__c;
    }
}
