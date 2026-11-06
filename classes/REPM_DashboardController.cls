/**
 * Portfolio metrics for the property management dashboard.
 */
public with sharing class REPM_DashboardController {
    public class StatusCount {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Integer count;
        @AuraEnabled
        public Decimal percent;
    }

    public class ExpiringLease {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String propertyName;
        @AuraEnabled
        public String tenantName;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public Decimal rent;
    }

    public class DashboardData {
        @AuraEnabled
        public Integer expiringCount;
        @AuraEnabled
        public List<ExpiringLease> expiringLeases;
        @AuraEnabled
        public List<StatusCount> maintenanceByStatus;
        @AuraEnabled
        public Decimal occupancyRate;
        @AuraEnabled
        public Integer occupiedCount;
        @AuraEnabled
        public Integer availableCount;
        @AuraEnabled
        public Integer totalProperties;
    }

    @AuraEnabled
    public static DashboardData getDashboard() {
        try {
            Date today = Date.today();
            Date horizon = today.addDays(30);
            Integer expiringCount = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Lease_Agreement__c WHERE End_Date__c >= :today AND End_Date__c <= :horizon',
                new Map<String, Object>{ 'today' => today, 'horizon' => horizon },
                AccessLevel.USER_MODE
            );
            List<Lease_Agreement__c> expiring = Database.queryWithBinds(
                'SELECT Id, Name, End_Date__c, Agreed_Monthly_Rent__c, Property__r.Name, Tenant__r.Name ' +
                    'FROM Lease_Agreement__c WHERE End_Date__c >= :today AND End_Date__c <= :horizon ' +
                    'ORDER BY End_Date__c ASC, Name ASC LIMIT 200',
                new Map<String, Object>{ 'today' => today, 'horizon' => horizon },
                AccessLevel.USER_MODE
            );

            Map<String, Integer> counts = new Map<String, Integer>();
            for (String status : REPM_Constants.MAINTENANCE_STATUS_ORDER) {
                counts.put(status, 0);
            }
            Integer maintenanceTotal = 0;
            for (AggregateResult aggregate : [
                SELECT Status__c status, COUNT(Id) requestCount
                FROM Maintenance_Request__c
                WITH USER_MODE
                GROUP BY Status__c
            ]) {
                String status = (String) aggregate.get('status');
                Integer count = Integer.valueOf(String.valueOf(aggregate.get('requestCount')));
                counts.put(status, count);
                maintenanceTotal += count;
            }

            Integer occupiedCount = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Property__c WHERE Status__c = :occupied',
                new Map<String, Object>{ 'occupied' => REPM_Constants.OCCUPIED },
                AccessLevel.USER_MODE
            );
            Integer totalProperties = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Property__c',
                new Map<String, Object>(),
                AccessLevel.USER_MODE
            );

            DashboardData data = new DashboardData();
            data.expiringCount = expiringCount;
            data.expiringLeases = new List<ExpiringLease>();
            for (Lease_Agreement__c lease : expiring) {
                ExpiringLease row = new ExpiringLease();
                row.id = lease.Id;
                row.name = lease.Name;
                row.propertyName = lease.Property__r == null ? null : lease.Property__r.Name;
                row.tenantName = lease.Tenant__r == null ? null : lease.Tenant__r.Name;
                row.endDate = lease.End_Date__c;
                row.rent = lease.Agreed_Monthly_Rent__c;
                data.expiringLeases.add(row);
            }
            data.maintenanceByStatus = new List<StatusCount>();
            for (String status : REPM_Constants.MAINTENANCE_STATUS_ORDER) {
                StatusCount row = new StatusCount();
                row.status = status;
                row.count = counts.containsKey(status) ? counts.get(status) : 0;
                row.percent = maintenanceTotal == 0 ? 0 : ((Decimal) row.count / maintenanceTotal) * 100;
                data.maintenanceByStatus.add(row);
            }
            data.occupiedCount = occupiedCount;
            data.totalProperties = totalProperties;
            data.availableCount = Math.max(0, totalProperties - occupiedCount);
            data.occupancyRate = totalProperties == 0 ? 0 : (((Decimal) occupiedCount / totalProperties) * 100).setScale(1);
            return data;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(ex.getMessage());
        }
    }
}
