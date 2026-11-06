@IsTest
public class REPM_TestDataFactory {
    public static Tenant__c insertTenant(String name, String email) {
        Tenant__c tenant = new Tenant__c(Name = name, Phone_Number__c = '5550100', Email__c = email);
        insert tenant;
        return tenant;
    }

    public static Vendor__c insertVendor(String name) {
        Vendor__c vendor = new Vendor__c(Name = name, Phone_Number__c = '5550199', Email__c = 'vendor@example.com');
        insert vendor;
        return vendor;
    }

    public static Property__c buildProperty(String name, String status) {
        return new Property__c(
            Name = name,
            Address__c = '100 Market Street',
            City__c = 'Austin',
            State__c = 'TX',
            Postal_Code__c = '78701',
            Country__c = 'USA',
            Type__c = 'Residential',
            Furnishing_Status__c = 'Furnished',
            Status__c = status,
            Rent__c = 2500,
            Description__c = 'Bright property near transit with a private entrance.',
            Images_Uploaded__c = true
        );
    }

    public static Property__c insertProperty(String name, String status) {
        Property__c property = buildProperty(name, status);
        insert property;
        return property;
    }

    public static Lease_Agreement__c insertLease(Id propertyId, Id tenantId, Date startDate, Date endDate) {
        Lease_Agreement__c lease = new Lease_Agreement__c(
            Property__c = propertyId,
            Tenant__c = tenantId,
            Terms__c = 'Rent is due on the first day of each month.',
            Agreed_Monthly_Rent__c = 2200,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        insert lease;
        return lease;
    }
}
