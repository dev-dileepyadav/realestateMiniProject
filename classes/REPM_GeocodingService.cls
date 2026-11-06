/**
 * Geocodes a property address through OpenStreetMap Nominatim.
 * Callout only: callers perform DML after the response returns.
 */
public with sharing class REPM_GeocodingService {
    @TestVisible
    private static final String ENDPOINT = 'https://nominatim.openstreetmap.org/search';

    public class GeoPoint {
        public Decimal latitude;
        public Decimal longitude;
    }

    public static String buildAddress(Property__c property) {
        List<String> parts = new List<String>();
        if (property == null) {
            return '';
        }
        addPart(parts, property.Address__c);
        addPart(parts, property.City__c);
        addPart(parts, property.State__c);
        addPart(parts, property.Postal_Code__c);
        addPart(parts, property.Country__c);
        return String.join(parts, ', ');
    }

    public static GeoPoint geocodeAddress(String address) {
        if (String.isBlank(address)) {
            return null;
        }
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setTimeout(10000);
        request.setEndpoint(ENDPOINT + '?format=jsonv2&limit=1&q=' + EncodingUtil.urlEncode(address, 'UTF-8'));
        request.setHeader('Accept', 'application/json');
        request.setHeader('User-Agent', 'REPMSalesforcePropertyManagement/1.0');

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw new CalloutException('Geocoding failed with status ' + response.getStatusCode());
        }
        List<Object> results = (List<Object>) JSON.deserializeUntyped(response.getBody());
        if (results == null || results.isEmpty()) {
            return null;
        }
        Map<String, Object> first = (Map<String, Object>) results[0];
        if (first.get('lat') == null || first.get('lon') == null) {
            return null;
        }
        GeoPoint point = new GeoPoint();
        point.latitude = Decimal.valueOf(String.valueOf(first.get('lat')));
        point.longitude = Decimal.valueOf(String.valueOf(first.get('lon')));
        return point;
    }

    private static void addPart(List<String> parts, String value) {
        if (String.isNotBlank(value)) {
            parts.add(value.trim());
        }
    }
}
