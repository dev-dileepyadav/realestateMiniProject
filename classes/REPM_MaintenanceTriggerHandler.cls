/**
 * Assigns each new maintenance request to the vendor with the lowest open workload.
 * Completed and cancelled requests are ignored. Ties go to the lowest vendor Id.
 * without sharing so workload is counted across the whole portfolio.
 */
public without sharing class REPM_MaintenanceTriggerHandler {
    public static void assignVendors(List<Maintenance_Request__c> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        List<Vendor__c> vendors = [SELECT Id FROM Vendor__c ORDER BY Id ASC];
        if (vendors.isEmpty()) {
            return;
        }

        Map<Id, Integer> workload = new Map<Id, Integer>();
        for (Vendor__c vendor : vendors) {
            workload.put(vendor.Id, 0);
        }
        for (AggregateResult aggregate : [
            SELECT Vendor__c vendorId, COUNT(Id) requestCount
            FROM Maintenance_Request__c
            WHERE Vendor__c IN :workload.keySet() AND Status__c IN :REPM_Constants.ACTIVE_MAINTENANCE_STATUSES
            GROUP BY Vendor__c
        ]) {
            workload.put((Id) aggregate.get('vendorId'), Integer.valueOf(String.valueOf(aggregate.get('requestCount'))));
        }

        for (Maintenance_Request__c request : requests) {
            if (request.Vendor__c != null && workload.containsKey(request.Vendor__c)) {
                workload.put(request.Vendor__c, workload.get(request.Vendor__c) + 1);
                continue;
            }
            Id selectedId;
            Integer lowest = null;
            for (Vendor__c vendor : vendors) {
                Integer current = workload.get(vendor.Id);
                if (lowest == null || current < lowest) {
                    lowest = current;
                    selectedId = vendor.Id;
                }
            }
            request.Vendor__c = selectedId;
            workload.put(selectedId, lowest + 1);
        }
    }
}
