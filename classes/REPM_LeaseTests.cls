@IsTest
private class REPM_LeaseTests {
    @IsTest
    static void activeLeaseOccupiesPropertyWithoutCreatingATask() {
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Casey Ng', 'casey@example.com');
        Property__c property = REPM_TestDataFactory.insertProperty('Lease House', 'Available');

        Test.startTest();
        Lease_Agreement__c lease = REPM_TestDataFactory.insertLease(property.Id, tenant.Id, Date.today(), Date.today().addYears(1));
        Test.stopTest();

        Property__c occupied = [SELECT Status__c, Tenant__c FROM Property__c WHERE Id = :property.Id];
        Assert.areEqual('Occupied', occupied.Status__c);
        Assert.areEqual(tenant.Id, occupied.Tenant__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :property.Id]);

        REPM_LeaseController.LeasePage page = REPM_LeaseController.getLeases(1);
        Assert.areEqual(1, page.totalCount);
        Assert.areEqual(property.Name, page.records[0].propertyName);

        Lease_Agreement__c detail = REPM_LeaseController.getLease(lease.Id);
        Assert.areEqual('Active', detail.Status__c);
        Assert.isNull(REPM_LeaseController.getLease(null));
    }

    @IsTest
    static void futureAndDeletedLeasesLeaveThePropertyAvailable() {
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Drew Patel', 'drew@example.com');
        Property__c property = REPM_TestDataFactory.insertProperty('Future House', 'Available');
        Lease_Agreement__c futureLease = REPM_TestDataFactory.insertLease(
            property.Id,
            tenant.Id,
            Date.today().addDays(10),
            Date.today().addYears(1)
        );

        Property__c stillAvailable = [SELECT Status__c, Tenant__c FROM Property__c WHERE Id = :property.Id];
        Assert.areEqual('Available', stillAvailable.Status__c);
        Assert.isNull(stillAvailable.Tenant__c);

        futureLease.Start_Date__c = Date.today();
        update futureLease;
        Assert.areEqual('Occupied', [SELECT Status__c FROM Property__c WHERE Id = :property.Id].Status__c);

        delete futureLease;
        Property__c released = [SELECT Status__c, Tenant__c FROM Property__c WHERE Id = :property.Id];
        Assert.areEqual('Available', released.Status__c);
        Assert.isNull(released.Tenant__c);
    }

    @IsTest
    static void changingTheEndDateResetsReminderFlags() {
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Eden Brooks', 'eden@example.com');
        Property__c property = REPM_TestDataFactory.insertProperty('Reminder House', 'Available');
        Lease_Agreement__c lease = REPM_TestDataFactory.insertLease(property.Id, tenant.Id, Date.today(), Date.today().addMonths(6));
        lease.Reminder_Month_Sent__c = true;
        lease.Reminder_Day_Sent__c = true;
        lease.End_Date__c = lease.End_Date__c.addDays(4);

        update lease;

        lease = [SELECT Reminder_Month_Sent__c, Reminder_Day_Sent__c FROM Lease_Agreement__c WHERE Id = :lease.Id];
        Assert.isFalse(lease.Reminder_Month_Sent__c);
        Assert.isFalse(lease.Reminder_Day_Sent__c);
    }

    @IsTest
    static void createAndPdfDelivery() {
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Frankie Cole', 'frankie@example.com');
        Property__c property = REPM_TestDataFactory.insertProperty('PDF House', 'Available');
        try {
            REPM_LeaseController.createLease(
                new Lease_Agreement__c(
                    Property__c = property.Id,
                    Tenant__c = tenant.Id,
                    Agreed_Monthly_Rent__c = 10,
                    Start_Date__c = Date.today(),
                    End_Date__c = Date.today().addDays(-1)
                )
            );
            Assert.fail('An end date before the start date should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }

        Id leaseId = REPM_LeaseController.createLease(
            new Lease_Agreement__c(
                Property__c = property.Id,
                Tenant__c = tenant.Id,
                Terms__c = 'Pets require written approval.',
                Agreed_Monthly_Rent__c = 1800,
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addYears(1)
            )
        );
        String pdf = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'));

        Test.startTest();
        REPM_LeaseController.sendPdf(leaseId, 'data:application/pdf;base64,' + pdf);
        Test.stopTest();

        Assert.areEqual(1, REPM_LeaseController.emailsSent);
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :leaseId]);

        try {
            REPM_LeaseController.sendPdf(leaseId, EncodingUtil.base64Encode(Blob.valueOf('not a pdf')));
            Assert.fail('A non-PDF payload should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }

        Tenant__c noEmail = REPM_TestDataFactory.insertTenant('No Email', null);
        Id silentLease = REPM_TestDataFactory.insertLease(property.Id, noEmail.Id, Date.today(), Date.today().addMonths(3)).Id;
        try {
            REPM_LeaseController.sendPdf(silentLease, pdf);
            Assert.fail('A tenant without an email should not receive a PDF.');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().length() > 0);
        }
    }

    @IsTest
    static void remindersSendOnceAndOccupancyBatchHealsDrift() {
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Gray Adams', 'gray@example.com');
        Tenant__c noEmail = REPM_TestDataFactory.insertTenant('No Mail', null);
        Property__c monthProperty = REPM_TestDataFactory.insertProperty('Month House', 'Available');
        Property__c dayProperty = REPM_TestDataFactory.insertProperty('Day House', 'Available');
        Property__c silentProperty = REPM_TestDataFactory.insertProperty('Silent House', 'Available');
        Property__c driftProperty = REPM_TestDataFactory.insertProperty('Drift House', 'Available');

        REPM_TestDataFactory.insertLease(monthProperty.Id, tenant.Id, Date.today(), Date.today().addMonths(1));
        REPM_TestDataFactory.insertLease(dayProperty.Id, tenant.Id, Date.today(), Date.today().addDays(1));
        REPM_TestDataFactory.insertLease(silentProperty.Id, noEmail.Id, Date.today(), Date.today().addDays(1));

        REPM_TriggerBypass.skipOccupancySync = true;
        Lease_Agreement__c drifted = REPM_TestDataFactory.insertLease(
            driftProperty.Id,
            tenant.Id,
            Date.today().addDays(-2),
            Date.today().addDays(10)
        );
        REPM_TriggerBypass.skipOccupancySync = false;
        Assert.areEqual('Available', [SELECT Status__c FROM Property__c WHERE Id = :driftProperty.Id].Status__c);

        Test.startTest();
        Database.executeBatch(new REPM_LeaseReminderBatch(), 20);
        Database.executeBatch(new REPM_OccupancySyncBatch(), 20);
        Test.stopTest();

        Assert.areEqual(2, REPM_LeaseReminderBatch.emailsSent);
        Assert.isTrue(
            [SELECT Reminder_Month_Sent__c FROM Lease_Agreement__c WHERE Property__c = :monthProperty.Id].Reminder_Month_Sent__c
        );
        Assert.isTrue([SELECT Reminder_Day_Sent__c FROM Lease_Agreement__c WHERE Property__c = :dayProperty.Id].Reminder_Day_Sent__c);
        Assert.isFalse(
            [SELECT Reminder_Day_Sent__c FROM Lease_Agreement__c WHERE Property__c = :silentProperty.Id].Reminder_Day_Sent__c
        );
        Property__c healed = [SELECT Status__c, Tenant__c FROM Property__c WHERE Id = :driftProperty.Id];
        Assert.areEqual('Occupied', healed.Status__c);
        Assert.areEqual(tenant.Id, healed.Tenant__c);
    }

    @IsTest
    static void remindersAreNotSentTwice() {
        Tenant__c tenant = REPM_TestDataFactory.insertTenant('Repeat Reminder', 'repeat@example.com');
        Property__c property = REPM_TestDataFactory.insertProperty('Repeat House', 'Available');
        Lease_Agreement__c lease = REPM_TestDataFactory.insertLease(property.Id, tenant.Id, Date.today(), Date.today().addDays(1));
        lease.Reminder_Day_Sent__c = true;
        update lease;

        Test.startTest();
        Database.executeBatch(new REPM_LeaseReminderBatch(), 20);
        Test.stopTest();

        Assert.areEqual(0, REPM_LeaseReminderBatch.emailsSent);
    }

    @IsTest
    static void schedulableQueuesDailyJobs() {
        Test.startTest();
        String jobId = System.schedule('REPM Lease Reminders Test', '0 0 8 * * ?', new REPM_LeaseReminderSchedulable());
        Test.stopTest();
        Assert.isNotNull(jobId);
    }
}
