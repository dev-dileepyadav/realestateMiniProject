/**
 * Tenant list and create actions. A tenant can be related to many properties through lease agreements.
 */
public with sharing class REPM_TenantController {
    public class TenantPage {
        @AuraEnabled
        public List<Tenant__c> records;
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
    public static TenantPage getTenants(Integer pageNumber) {
        try {
            Integer safePage = REPM_Constants.pageNumber(pageNumber);
            Integer offsetSize = REPM_Constants.offset(safePage);
            if (offsetSize > REPM_Constants.MAX_OFFSET) {
                throw REPM_Constants.auraError('Narrow the list to move past 2,000 tenants.');
            }
            Integer pageSize = REPM_Constants.PAGE_SIZE;
            Integer totalCount = Database.countQueryWithBinds('SELECT COUNT() FROM Tenant__c', new Map<String, Object>(), AccessLevel.USER_MODE);
            List<Tenant__c> records = Database.queryWithBinds(
                'SELECT Id, Name, Phone_Number__c, Email__c FROM Tenant__c ORDER BY Name ASC, Id ASC LIMIT :pageSize OFFSET :offsetSize',
                new Map<String, Object>{ 'pageSize' => pageSize, 'offsetSize' => offsetSize },
                AccessLevel.USER_MODE
            );
            TenantPage page = new TenantPage();
            page.records = records;
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
    public static Id createTenant(String name, String phone, String email) {
        try {
            if (String.isBlank(name)) {
                throw REPM_Constants.auraError('Tenant name is required.');
            }
            Tenant__c tenant = new Tenant__c(Name = name.trim(), Phone_Number__c = phone, Email__c = email);
            Database.insert(new List<Tenant__c>{ tenant }, AccessLevel.USER_MODE);
            return tenant.Id;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(ex.getMessage());
        }
    }
}
