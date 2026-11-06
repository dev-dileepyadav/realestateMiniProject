/**
 * Geocodes property addresses in chunks so a bulk insert stays inside callout limits.
 */
public without sharing class REPM_PropertyGeocodeQueueable implements Queueable, Database.AllowsCallouts {
    @TestVisible
    private static final Integer CHUNK_SIZE = 10;
    private final List<Id> propertyIds;

    public REPM_PropertyGeocodeQueueable(List<Id> propertyIds) {
        this.propertyIds = propertyIds == null ? new List<Id>() : new List<Id>(propertyIds);
    }

    public void execute(QueueableContext context) {
        if (propertyIds.isEmpty()) {
            return;
        }
        Integer chunkSize = Math.min(CHUNK_SIZE, propertyIds.size());
        List<Id> currentIds = new List<Id>();
        List<Id> remainingIds = new List<Id>();
        for (Integer index = 0; index < propertyIds.size(); index++) {
            if (index < chunkSize) {
                currentIds.add(propertyIds[index]);
            } else {
                remainingIds.add(propertyIds[index]);
            }
        }

        List<Property__c> updates = new List<Property__c>();
        for (Property__c property : [
            SELECT Id, Address__c, City__c, State__c, Postal_Code__c, Country__c
            FROM Property__c
            WHERE Id IN :currentIds
        ]) {
            try {
                REPM_GeocodingService.GeoPoint point = REPM_GeocodingService.geocodeAddress(
                    REPM_GeocodingService.buildAddress(property)
                );
                if (point == null) {
                    continue;
                }
                Property__c updateRow = new Property__c(Id = property.Id);
                updateRow.Location__Latitude__s = point.latitude;
                updateRow.Location__Longitude__s = point.longitude;
                updates.add(updateRow);
            } catch (Exception ex) {
                // One failed address should not stop the rest of the chunk.
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }
        if (!remainingIds.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new REPM_PropertyGeocodeQueueable(remainingIds));
        }
    }
}
