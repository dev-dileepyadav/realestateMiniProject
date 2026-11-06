@IsTest
private class REPM_AutomationTests {
    @IsTest
    static void assigningATenantCreatesOneLeaseTask() {
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Avery Stone', 'avery@example.com');
        Tenant__c replacement = REPM_TestDataFactory.insertTenant('Blake Stone', 'blake@example.com');
        List<Property__c> properties = new List<Property__c>();
        for (Integer index = 0; index < 50; index++) {
            properties.add(REPM_TestDataFactory.buildProperty('Assigned ' + index, 'Available'));
        }
        insert properties;
        for (Property__c property : properties) {
            property.Tenant__c = tenant.Id;
        }

        Test.startTest();
        update properties;
        Test.stopTest();

        Assert.areEqual(50, [SELECT COUNT() FROM Task WHERE Subject = :REPM_Constants.TASK_SUBJECT]);

        properties[0].Rent__c = 2600;
        update properties[0];
        Assert.areEqual(50, [SELECT COUNT() FROM Task WHERE Subject = :REPM_Constants.TASK_SUBJECT]);

        properties[0].Tenant__c = replacement.Id;
        update properties[0];
        Assert.areEqual(51, [SELECT COUNT() FROM Task WHERE WhatId = :properties[0].Id OR Subject = :REPM_Constants.TASK_SUBJECT]);
    }

    @IsTest
    static void geocodeQueueableStoresCoordinatesAndSkipsKnownLocations() {
        Assert.areEqual('', REPM_GeocodingService.buildAddress(null));
        Assert.isNull(REPM_GeocodingService.geocodeAddress(' '));

        Property__c ready = REPM_TestDataFactory.buildProperty('Already Mapped', 'Available');
        ready.Location__Latitude__s = 1;
        ready.Location__Longitude__s = 2;
        Property__c pending = REPM_TestDataFactory.buildProperty('Needs Map', 'Available');
        REPM_TriggerBypass.runGeocodeInTests = true;
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock());

        Test.startTest();
        insert new List<Property__c>{ ready, pending };
        Test.stopTest();

        Map<Id, Property__c> saved = new Map<Id, Property__c>(
            [SELECT Name, Location__Latitude__s, Location__Longitude__s FROM Property__c WHERE Id IN :new Set<Id>{ ready.Id, pending.Id }]
        );
        Assert.areEqual(1, saved.get(ready.Id).Location__Latitude__s);
        Assert.areEqual(12.9716, saved.get(pending.Id).Location__Latitude__s);
        Assert.areEqual(77.5946, saved.get(pending.Id).Location__Longitude__s);

        new REPM_PropertyGeocodeQueueable(new List<Id>()).execute(null);
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock(200, '[{"display_name":"missing"}]'));
        Assert.isNull(REPM_GeocodingService.geocodeAddress('100 Market Street, Austin'));
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock(500, 'unavailable'));
        try {
            REPM_GeocodingService.geocodeAddress('100 Market Street, Austin');
            Assert.fail('A failed geocode response should raise an exception.');
        } catch (CalloutException ex) {
            Assert.isTrue(ex.getMessage().contains('status'));
        }
    }

    @IsTest
    static void geocodeQueueableChainsRemainingIds() {
        List<Property__c> properties = new List<Property__c>();
        for (Integer index = 0; index < 11; index++) {
            properties.add(REPM_TestDataFactory.buildProperty('Chain ' + index, 'Available'));
        }
        insert properties;
        List<Id> propertyIds = new List<Id>();
        for (Property__c property : properties) {
            propertyIds.add(property.Id);
        }
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock());

        Test.startTest();
        System.enqueueJob(new REPM_PropertyGeocodeQueueable(propertyIds));
        Test.stopTest();

        Assert.areEqual(10, [SELECT COUNT() FROM Property__c WHERE Location__Latitude__s != NULL AND Id IN :propertyIds]);
    }

    @IsTest
    static void rentEditsDoNotGeocode() {
        Property__c property = REPM_TestDataFactory.insertProperty('Editable House', 'Available');
        REPM_TriggerBypass.runGeocodeInTests = true;
        property.Rent__c = 3100;

        Test.startTest();
        update property;
        Test.stopTest();

        Assert.isNull([SELECT Location__Latitude__s FROM Property__c WHERE Id = :property.Id].Location__Latitude__s);
    }

    @IsTest
    static void addressChangesAreGeocoded() {
        Property__c property = REPM_TestDataFactory.insertProperty('Moving House', 'Available');
        REPM_TriggerBypass.runGeocodeInTests = true;
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock());
        property.City__c = 'Dallas';

        Test.startTest();
        update property;
        Test.stopTest();

        Assert.areEqual(12.9716, [SELECT Location__Latitude__s FROM Property__c WHERE Id = :property.Id].Location__Latitude__s);
    }

    @IsTest
    static void maintenanceAssignsTheLeastLoadedVendorInBulk() {
        Vendor__c first = REPM_TestDataFactory.insertVendor('Alpha Vendor');
        Vendor__c second = REPM_TestDataFactory.insertVendor('Beta Vendor');
        Property__c property = REPM_TestDataFactory.insertProperty('Service House', 'Available');
        Id busier = first.Id < second.Id ? second.Id : first.Id;
        Id quieter = first.Id < second.Id ? first.Id : second.Id;

        List<Maintenance_Request__c> existing = new List<Maintenance_Request__c>();
        existing.add(new Maintenance_Request__c(Property__c = property.Id, Vendor__c = busier, Status__c = 'Open', Description__c = 'Open work'));
        existing.add(
            new Maintenance_Request__c(Property__c = property.Id, Vendor__c = quieter, Status__c = 'Completed', Description__c = 'Finished work')
        );
        insert existing;

        Maintenance_Request__c manual = new Maintenance_Request__c(
            Property__c = property.Id,
            Vendor__c = busier,
            Status__c = 'In Progress',
            Description__c = 'Keep this vendor'
        );
        Maintenance_Request__c automatic = new Maintenance_Request__c(
            Property__c = property.Id,
            Status__c = 'Open',
            Description__c = 'Assign automatically'
        );
        insert new List<Maintenance_Request__c>{ manual, automatic };

        Assert.areEqual(busier, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :manual.Id].Vendor__c);
        Assert.areEqual(quieter, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :automatic.Id].Vendor__c);

        List<Maintenance_Request__c> bulkRequests = new List<Maintenance_Request__c>();
        for (Integer index = 0; index < 200; index++) {
            bulkRequests.add(new Maintenance_Request__c(Property__c = property.Id, Status__c = 'Open', Description__c = 'Bulk ' + index));
        }
        insert bulkRequests;
        Integer firstCount = [SELECT COUNT() FROM Maintenance_Request__c WHERE Vendor__c = :first.Id AND Status__c IN ('Open', 'In Progress')];
        Integer secondCount = [SELECT COUNT() FROM Maintenance_Request__c WHERE Vendor__c = :second.Id AND Status__c IN ('Open', 'In Progress')];
        Assert.isTrue(Math.abs(firstCount - secondCount) <= 2, 'Bulk requests should stay balanced across vendors.');

        Maintenance_Request__c unassigned = new Maintenance_Request__c(Property__c = property.Id, Status__c = 'Open');
        delete [SELECT Id FROM Vendor__c];
        insert unassigned;
        Assert.isNull([SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :unassigned.Id].Vendor__c);
    }
}
