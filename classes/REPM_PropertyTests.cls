@IsTest
private class REPM_PropertyTests {
    private static final String TINY_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    @IsTest
    static void pagesAndFiltersOnTheServer() {
        List<Property__c> properties = new List<Property__c>();
        for (Integer index = 0; index < 26; index++) {
            Property__c property = REPM_TestDataFactory.buildProperty('Paged ' + index, 'Available');
            property.Rent__c = 1000 + index;
            properties.add(property);
        }
        Property__c furnished = REPM_TestDataFactory.buildProperty('Furnished House', 'Available');
        furnished.Rent__c = 1500;
        furnished.Furnishing_Status__c = 'Furnished';
        furnished.Location__Latitude__s = 30.2672;
        furnished.Location__Longitude__s = -97.7431;
        properties.add(furnished);

        Property__c unfurnished = REPM_TestDataFactory.buildProperty('Unfurnished House', 'Occupied');
        unfurnished.Rent__c = 4000;
        unfurnished.Furnishing_Status__c = 'Unfurnished';
        unfurnished.Location__Latitude__s = 19.0760;
        unfurnished.Location__Longitude__s = 72.8777;
        properties.add(unfurnished);
        insert properties;

        REPM_PropertyController.PropertyPage firstPage = REPM_PropertyController.getProperties(0, null, null, null, null, null, null, null);
        Assert.areEqual(25, firstPage.records.size(), 'The first page should contain 25 properties.');
        Assert.areEqual(28, firstPage.totalCount);
        Assert.areEqual(1, firstPage.pageNumber);
        Assert.areEqual(2, firstPage.totalPages);

        REPM_PropertyController.PropertyPage secondPage = REPM_PropertyController.getProperties(2, null, null, null, null, null, null, null);
        Assert.areEqual(3, secondPage.records.size());

        REPM_PropertyController.PropertyPage available = REPM_PropertyController.getProperties(
            1,
            1200,
            1800,
            'Available',
            'Furnished',
            null,
            null,
            null
        );
        Assert.areEqual(1, available.totalCount);
        Assert.areEqual('Furnished House', available.records[0].name);

        REPM_PropertyController.PropertyPage nearby = REPM_PropertyController.getProperties(1, null, null, null, null, 30.2672, -97.7431, 20);
        Assert.areEqual(1, nearby.totalCount);
        Assert.areEqual('Furnished House', nearby.records[0].name);
        Assert.isNotNull(nearby.records[0].distanceKm);

        try {
            REPM_PropertyController.getProperties(1, 10, 1, null, null, null, null, null);
            Assert.fail('A reversed rent range should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
        try {
            REPM_PropertyController.getProperties(1, null, null, null, null, null, null, 5);
            Assert.fail('Distance without a location should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
        try {
            REPM_PropertyController.getProperties(1, null, null, 'Bad', null, null, null, null);
            Assert.fail('An unknown status should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
        try {
            REPM_PropertyController.getProperties(1, null, null, null, null, null, null, -1);
            Assert.fail('A negative distance should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
        try {
            REPM_PropertyController.getProperties(500, null, null, null, null, null, null, null);
            Assert.fail('Paging past 2,000 rows should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
    }

    @IsTest
    static void createRequiresAnImageAndStoresFiles() {
        try {
            REPM_PropertyController.createProperty(sampleProperty(), new List<REPM_FilePayload>());
            Assert.fail('A property without an image should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }

        REPM_FilePayload png = new REPM_FilePayload();
        png.fileName = 'photos/front.png';
        png.base64Data = 'data:image/png;base64,' + TINY_PNG;
        png.contentType = 'image/png';
        REPM_FilePayload second = new REPM_FilePayload();
        second.fileName = 'kitchen';
        second.base64Data = TINY_PNG;
        second.contentType = 'image/jpeg';

        Test.startTest();
        Id propertyId = REPM_PropertyController.createProperty(sampleProperty(), new List<REPM_FilePayload>{ png, second });
        Test.stopTest();

        Property__c saved = [SELECT Images_Uploaded__c FROM Property__c WHERE Id = :propertyId];
        Assert.isTrue(saved.Images_Uploaded__c);
        Assert.areEqual(2, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :propertyId]);

        Property__c location = REPM_PropertyController.getPropertyLocation(propertyId);
        Assert.areEqual(propertyId, location.Id);
        Assert.isNull(REPM_PropertyController.getPropertyLocation(null));
    }

    @IsTest
    static void rejectsInvalidImagesAndGeocodesWhenTheServiceResponds() {
        REPM_FilePayload document = new REPM_FilePayload();
        document.fileName = 'notes.pdf';
        document.base64Data = TINY_PNG;
        document.contentType = 'application/pdf';
        try {
            REPM_PropertyController.createProperty(sampleProperty(), new List<REPM_FilePayload>{ document });
            Assert.fail('Non-image files should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }

        REPM_TriggerBypass.runGeocodeInTests = true;
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock());
        REPM_FilePayload png = new REPM_FilePayload();
        png.fileName = 'front.png';
        png.base64Data = TINY_PNG;
        png.contentType = 'image/png';

        Test.startTest();
        Id propertyId = REPM_PropertyController.createProperty(sampleProperty(), new List<REPM_FilePayload>{ png });
        Test.stopTest();

        Property__c saved = [
            SELECT Location__Latitude__s, Location__Longitude__s
            FROM Property__c
            WHERE Id = :propertyId
        ];
        Assert.areEqual(12.9716, saved.Location__Latitude__s);
        Assert.areEqual(77.5946, saved.Location__Longitude__s);
    }

    @IsTest
    static void propertyCanBeSavedWhenGeocodingFails() {
        REPM_TriggerBypass.runGeocodeInTests = true;
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock(500, 'unavailable'));
        REPM_FilePayload png = new REPM_FilePayload();
        png.fileName = 'front.png';
        png.base64Data = TINY_PNG;
        png.contentType = 'image/png';

        Test.startTest();
        Id propertyId = REPM_PropertyController.createProperty(sampleProperty(), new List<REPM_FilePayload>{ png });
        Test.stopTest();

        Property__c saved = [SELECT Location__Latitude__s FROM Property__c WHERE Id = :propertyId];
        Assert.isNull(saved.Location__Latitude__s);
    }

    @IsTest
    static void manualGeocodeUpdatesTheMapLocation() {
        Property__c property = REPM_TestDataFactory.insertProperty('Map House', 'Available');
        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock(200, '[]'));
        try {
            REPM_PropertyController.geocodeProperty(property.Id);
            Assert.fail('An empty geocode result should be reported.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }

        Test.setMock(HttpCalloutMock.class, new REPM_GeocodeHttpMock());
        Test.startTest();
        Property__c geocoded = REPM_PropertyController.geocodeProperty(property.Id);
        Test.stopTest();
        Assert.areEqual(12.9716, geocoded.Location__Latitude__s);
    }

    private static Property__c sampleProperty() {
        Property__c property = REPM_TestDataFactory.buildProperty('Created House', 'Available');
        property.Images_Uploaded__c = false;
        return property;
    }
}
