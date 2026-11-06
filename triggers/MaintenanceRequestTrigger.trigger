trigger MaintenanceRequestTrigger on Maintenance_Request__c(before insert) {
    REPM_MaintenanceTriggerHandler.assignVendors(Trigger.new);
}
