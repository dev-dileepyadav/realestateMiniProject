/**
 * Image payload posted by the property form. The file is stored as a Salesforce File.
 */
public with sharing class REPM_FilePayload {
    @AuraEnabled
    public String fileName { get; set; }
    @AuraEnabled
    public String base64Data { get; set; }
    @AuraEnabled
    public String contentType { get; set; }
}
