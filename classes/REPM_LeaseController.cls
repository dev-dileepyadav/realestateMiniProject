/**
 * Lease list, create, and PDF email actions.
 */
public with sharing class REPM_LeaseController {
    @TestVisible
    private static Integer emailsSent = 0;

    public class LeaseRow {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String propertyName;
        @AuraEnabled
        public String tenantName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Decimal rent;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
    }

    public class LeasePage {
        @AuraEnabled
        public List<LeaseRow> records;
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
    public static LeasePage getLeases(Integer pageNumber) {
        try {
            Integer safePage = REPM_Constants.pageNumber(pageNumber);
            Integer offsetSize = REPM_Constants.offset(safePage);
            if (offsetSize > REPM_Constants.MAX_OFFSET) {
                throw REPM_Constants.auraError('Narrow the list to move past 2,000 lease agreements.');
            }
            Integer pageSize = REPM_Constants.PAGE_SIZE;
            Integer totalCount = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Lease_Agreement__c',
                new Map<String, Object>(),
                AccessLevel.USER_MODE
            );
            List<Lease_Agreement__c> leases = Database.queryWithBinds(
                'SELECT Id, Name, Status__c, Agreed_Monthly_Rent__c, Start_Date__c, End_Date__c, Property__r.Name, Tenant__r.Name ' +
                    'FROM Lease_Agreement__c ORDER BY End_Date__c ASC, Name ASC LIMIT :pageSize OFFSET :offsetSize',
                new Map<String, Object>{ 'pageSize' => pageSize, 'offsetSize' => offsetSize },
                AccessLevel.USER_MODE
            );
            LeasePage page = new LeasePage();
            page.records = new List<LeaseRow>();
            for (Lease_Agreement__c lease : leases) {
                LeaseRow row = new LeaseRow();
                row.id = lease.Id;
                row.name = lease.Name;
                row.propertyName = lease.Property__r == null ? null : lease.Property__r.Name;
                row.tenantName = lease.Tenant__r == null ? null : lease.Tenant__r.Name;
                row.status = lease.Status__c;
                row.rent = lease.Agreed_Monthly_Rent__c;
                row.startDate = lease.Start_Date__c;
                row.endDate = lease.End_Date__c;
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
    public static Id createLease(Lease_Agreement__c lease) {
        try {
            if (lease == null || lease.Property__c == null || lease.Tenant__c == null) {
                throw REPM_Constants.auraError('Property and tenant are required.');
            }
            if (lease.Start_Date__c == null || lease.End_Date__c == null) {
                throw REPM_Constants.auraError('Start and end dates are required.');
            }
            if (lease.End_Date__c < lease.Start_Date__c) {
                throw REPM_Constants.auraError('End date must be on or after the start date.');
            }
            if (lease.Agreed_Monthly_Rent__c == null || lease.Agreed_Monthly_Rent__c <= 0) {
                throw REPM_Constants.auraError('Agreed monthly rent must be greater than zero.');
            }
            lease.Id = null;
            lease.Reminder_Month_Sent__c = false;
            lease.Reminder_Day_Sent__c = false;
            Database.insert(new List<Lease_Agreement__c>{ lease }, AccessLevel.USER_MODE);
            return lease.Id;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Lease_Agreement__c getLease(Id leaseId) {
        if (leaseId == null) {
            return null;
        }
        List<Lease_Agreement__c> leases = [
            SELECT
                Id,
                Name,
                Terms__c,
                Agreed_Monthly_Rent__c,
                Start_Date__c,
                End_Date__c,
                Status__c,
                Property__c,
                Property__r.Name,
                Property__r.Full_Address__c,
                Tenant__c,
                Tenant__r.Name,
                Tenant__r.Email__c,
                Tenant__r.Phone_Number__c
            FROM Lease_Agreement__c
            WHERE Id = :leaseId
            WITH USER_MODE
            LIMIT 1
        ];
        if (leases.isEmpty()) {
            throw REPM_Constants.auraError('Lease agreement not found or you do not have access.');
        }
        return leases[0];
    }

    @AuraEnabled
    public static void sendPdf(Id leaseId, String pdfBase64) {
        try {
            Lease_Agreement__c lease = queryLease(leaseId);
            if (lease.Tenant__r == null || String.isBlank(lease.Tenant__r.Email__c)) {
                throw REPM_Constants.auraError('Add an email address on the tenant before sending the agreement.');
            }
            Blob pdfBody = decodePdf(pdfBase64);
            insert new ContentVersion(
                Title = 'Lease Agreement ' + lease.Name,
                PathOnClient = 'Lease-' + lease.Name + '.pdf',
                VersionData = pdfBody,
                FirstPublishLocationId = lease.Id
            );

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('Lease-' + lease.Name + '.pdf');
            attachment.setBody(pdfBody);
            attachment.setContentType('application/pdf');

            String tenantName = lease.Tenant__r.Name;
            String propertyName = lease.Property__r == null ? 'the property' : lease.Property__r.Name;
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setToAddresses(new List<String>{ lease.Tenant__r.Email__c });
            message.setSubject('Lease agreement ' + lease.Name);
            message.setPlainTextBody(
                'Hello ' +
                    tenantName +
                    ',\n\nAttached is lease agreement ' +
                    lease.Name +
                    ' for ' +
                    propertyName +
                    '.\n\nThe term runs from ' +
                    String.valueOf(lease.Start_Date__c) +
                    ' to ' +
                    String.valueOf(lease.End_Date__c) +
                    '.'
            );
            message.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
            message.setSaveAsActivity(false);

            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message }, true);
            if (results.isEmpty() || !results[0].isSuccess()) {
                String failure = results.isEmpty() ? 'Email could not be sent.' : results[0].getErrors()[0].getMessage();
                throw REPM_Constants.auraError(failure);
            }
            emailsSent++;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(ex.getMessage());
        }
    }

    private static Lease_Agreement__c queryLease(Id leaseId) {
        if (leaseId == null) {
            throw REPM_Constants.auraError('Lease agreement is required.');
        }
        List<Lease_Agreement__c> leases = [
            SELECT Id, Name, Start_Date__c, End_Date__c, Tenant__r.Name, Tenant__r.Email__c, Property__r.Name
            FROM Lease_Agreement__c
            WHERE Id = :leaseId
            WITH USER_MODE
            LIMIT 1
        ];
        if (leases.isEmpty()) {
            throw REPM_Constants.auraError('Lease agreement not found or you do not have access.');
        }
        return leases[0];
    }

    private static Blob decodePdf(String pdfBase64) {
        if (String.isBlank(pdfBase64)) {
            throw REPM_Constants.auraError('A PDF is required.');
        }
        String payload = pdfBase64;
        Integer comma = payload.indexOf(',');
        if (payload.startsWith('data:') && comma > -1) {
            payload = payload.substring(comma + 1);
        }
        Blob body;
        try {
            body = EncodingUtil.base64Decode(payload);
        } catch (Exception ex) {
            throw REPM_Constants.auraError('The PDF could not be read.');
        }
        if (body == null || body.size() == 0 || body.size() > 4500000) {
            throw REPM_Constants.auraError('The PDF is empty or too large to email.');
        }
        // %PDF is 25504446 in hex. Avoid Blob.toString(), which rejects binary PDF streams.
        if (!EncodingUtil.convertToHex(body).startsWith('25504446')) {
            throw REPM_Constants.auraError('The file is not a valid PDF.');
        }
        return body;
    }
}
