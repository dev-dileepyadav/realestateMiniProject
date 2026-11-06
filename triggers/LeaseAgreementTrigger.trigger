trigger LeaseAgreementTrigger on Lease_Agreement__c(before update, after insert, after update, after delete) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        REPM_LeaseTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        REPM_LeaseTriggerHandler.afterChange(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isDelete) {
        REPM_LeaseTriggerHandler.afterChange(Trigger.old);
    }
}
