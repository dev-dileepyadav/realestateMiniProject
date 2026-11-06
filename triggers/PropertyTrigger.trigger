trigger PropertyTrigger on Property__c(after insert, after update) {
    if (Trigger.isInsert) {
        REPM_PropertyTriggerHandler.afterInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
        REPM_PropertyTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
