@IsTest
private class REPM_PortfolioTests {
    @IsTest
    static void tenantsCanBeListedAndCreated() {
        REPM_TestDataFactory.insertTenant('Harper Diaz', 'harper@example.com');
        REPM_TenantController.TenantPage page = REPM_TenantController.getTenants(null);
        Assert.areEqual(1, page.totalCount);
        Assert.areEqual(25, page.pageSize);
        Assert.areEqual('Harper Diaz', page.records[0].Name);

        Id createdId = REPM_TenantController.createTenant('Indigo Shah', '5550133', 'indigo@example.com');
        Assert.areEqual('Indigo Shah', [SELECT Name FROM Tenant__c WHERE Id = :createdId].Name);
        try {
            REPM_TenantController.createTenant(' ', null, null);
            Assert.fail('A blank tenant name should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
        try {
            REPM_TenantController.getTenants(500);
            Assert.fail('Paging past 2,000 tenants should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
    }

    @IsTest
    static void maintenanceCanBeListedAndCreated() {
        Vendor__c vendor = REPM_TestDataFactory.insertVendor('Northwind Repairs');
        Property__c property = REPM_TestDataFactory.insertProperty('Maintained House', 'Occupied');
        REPM_MaintenanceController.RequestRow created = REPM_MaintenanceController.createRequest(property.Id, 'Open', 'Replace the lobby light.');

        Assert.areEqual(vendor.Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :created.id].Vendor__c);
        Assert.areEqual('Northwind Repairs', created.vendorName);
        REPM_MaintenanceController.RequestPage page = REPM_MaintenanceController.getRequests(1);
        Assert.areEqual(1, page.totalCount);
        Assert.areEqual('Replace the lobby light.', page.records[0].description);

        try {
            REPM_MaintenanceController.createRequest(null, 'Open', null);
            Assert.fail('A property is required.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
        try {
            REPM_MaintenanceController.createRequest(property.Id, 'Blocked', null);
            Assert.fail('An unknown status should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
    }

    @IsTest
    static void dashboardSummarizesThePortfolio() {
        REPM_DashboardController.DashboardData emptyData = REPM_DashboardController.getDashboard();
        Assert.areEqual(0, emptyData.totalProperties);
        Assert.areEqual(0, emptyData.occupancyRate);
        Assert.areEqual(4, emptyData.maintenanceByStatus.size());

        Property__c occupied = REPM_TestDataFactory.insertProperty('Occupied House', 'Occupied');
        REPM_TestDataFactory.insertProperty('Available House', 'Available');
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Jordan Blake', 'jordan@example.com');
        REPM_TestDataFactory.insertLease(occupied.Id, tenant.Id, Date.today().addDays(-5), Date.today().addDays(15));
        REPM_TestDataFactory.insertLease(
            [SELECT Id FROM Property__c WHERE Name = 'Available House' LIMIT 1]
            .Id,
            tenant.Id,
            Date.today().addDays(40),
            Date.today().addDays(90)
        );
        insert new List<Maintenance_Request__c>{
            new Maintenance_Request__c(Property__c = occupied.Id, Status__c = 'Open', Description__c = 'Open item'),
            new Maintenance_Request__c(Property__c = occupied.Id, Status__c = 'Completed', Description__c = 'Done item')
        };

        REPM_DashboardController.DashboardData data = REPM_DashboardController.getDashboard();
        Assert.areEqual(2, data.totalProperties);
        Assert.areEqual(50, data.occupancyRate);
        Assert.areEqual(1, data.expiringCount);
        Assert.areEqual(1, data.expiringLeases.size());
        Map<String, Integer> byStatus = new Map<String, Integer>();
        for (REPM_DashboardController.StatusCount row : data.maintenanceByStatus) {
            byStatus.put(row.status, row.count);
        }
        Assert.areEqual(1, byStatus.get('Open'));
        Assert.areEqual(1, byStatus.get('Completed'));
        Assert.areEqual(0, byStatus.get('Cancelled'));
    }
}
