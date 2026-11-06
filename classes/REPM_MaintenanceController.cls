/**
 * Maintenance request list and create. Vendor assignment is handled by the before-insert trigger.
 */
public with sharing class REPM_MaintenanceController {
    public class RequestRow {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String propertyName;
        @AuraEnabled
        public String vendorName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String description;
    }

    public class RequestPage {
        @AuraEnabled
        public List<RequestRow> records;
        @AuraEnabled
        public Integer totalCount;
        @AuraEnabled
        public Integer pageNumber;
        @AuraEnabled
        public Integer pageSize;
        @AuraEnabled
        public Integer totalPages;
    }

    @AuraEnabled
    public static RequestPage getRequests(Integer pageNumber) {
        try {
            Integer safePage = REPM_Constants.pageNumber(pageNumber);
            Integer offsetSize = REPM_Constants.offset(safePage);
            if (offsetSize > REPM_Constants.MAX_OFFSET) {
                throw REPM_Constants.auraError('Narrow the list to move past 2,000 maintenance requests.');
            }
            Integer pageSize = REPM_Constants.PAGE_SIZE;
            Integer totalCount = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Maintenance_Request__c',
                new Map<String, Object>(),
                AccessLevel.USER_MODE
            );
            List<Maintenance_Request__c> requests = Database.queryWithBinds(
                'SELECT Id, Name, Status__c, Description__c, Property__r.Name, Vendor__r.Name ' +
                    'FROM Maintenance_Request__c ORDER BY CreatedDate DESC, Name DESC LIMIT :pageSize OFFSET :offsetSize',
                new Map<String, Object>{ 'pageSize' => pageSize, 'offsetSize' => offsetSize },
                AccessLevel.USER_MODE
            );
            RequestPage page = new RequestPage();
            page.records = new List<RequestRow>();
            for (Maintenance_Request__c request : requests) {
                RequestRow row = new RequestRow();
                row.id = request.Id;
                row.name = request.Name;
                row.propertyName = request.Property__r == null ? null : request.Property__r.Name;
                row.vendorName = request.Vendor__r == null ? null : request.Vendor__r.Name;
                row.status = request.Status__c;
                row.description = request.Description__c;
                page.records.add(row);
            }
            page.totalCount = totalCount;
            page.pageNumber = safePage;
            page.pageSize = pageSize;
            page.totalPages = REPM_Constants.pageCount(totalCount);
            return page;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(ex.getMessage());
        }
    }

    @AuraEnabled
    public static RequestRow createRequest(Id propertyId, String status, String description) {
        try {
            if (propertyId == null) {
                throw REPM_Constants.auraError('Property is required.');
            }
            if (String.isNotBlank(status) && !REPM_Constants.MAINTENANCE_STATUSES.contains(status)) {
                throw REPM_Constants.auraError('Maintenance status is not valid.');
            }
            Maintenance_Request__c request = new Maintenance_Request__c(
                Property__c = propertyId,
                Status__c = String.isBlank(status) ? REPM_Constants.MAINT_OPEN : status,
                Description__c = description
            );
            Database.insert(new List<Maintenance_Request__c>{ request }, AccessLevel.USER_MODE);
            List<Maintenance_Request__c> saved = [
                SELECT Id, Name, Status__c, Description__c, Property__r.Name, Vendor__r.Name
                FROM Maintenance_Request__c
                WHERE Id = :request.Id
                WITH USER_MODE
                LIMIT 1
            ];
            if (saved.isEmpty()) {
                throw REPM_Constants.auraError('The maintenance request was saved but could not be reloaded.');
            }
            RequestRow row = new RequestRow();
            row.id = saved[0].Id;
            row.name = saved[0].Name;
            row.propertyName = saved[0].Property__r == null ? null : saved[0].Property__r.Name;
            row.vendorName = saved[0].Vendor__r == null ? null : saved[0].Vendor__r.Name;
            row.status = saved[0].Status__c;
            row.description = saved[0].Description__c;
            return row;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(ex.getMessage());
        }
    }
}
