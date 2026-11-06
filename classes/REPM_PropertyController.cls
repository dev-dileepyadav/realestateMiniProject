/**
 * Server-side property search, creation, and map geocoding for the property list and record page.
 */
public with sharing class REPM_PropertyController {
    public class PropertyRow {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String address;
        @AuraEnabled
        public String city;
        @AuraEnabled
        public String state;
        @AuraEnabled
        public String country;
        @AuraEnabled
        public String propertyType;
        @AuraEnabled
        public String furnishingStatus;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Decimal rent;
        @AuraEnabled
        public Decimal distanceKm;
    }

    public class PropertyPage {
        @AuraEnabled
        public List<PropertyRow> records;
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
    public static PropertyPage getProperties(
        Integer pageNumber,
        Decimal minRent,
        Decimal maxRent,
        String status,
        String furnishingStatus,
        Decimal latitude,
        Decimal longitude,
        Decimal distanceKm
    ) {
        try {
            if (minRent != null && maxRent != null && minRent > maxRent) {
                throw REPM_Constants.auraError('Minimum rent cannot be greater than maximum rent.');
            }
            Integer safePage = REPM_Constants.pageNumber(pageNumber);
            Integer offsetSize = REPM_Constants.offset(safePage);
            if (offsetSize > REPM_Constants.MAX_OFFSET) {
                throw REPM_Constants.auraError('Narrow the filters to move past 2,000 properties.');
            }

            List<String> filters = new List<String>();
            Map<String, Object> binds = new Map<String, Object>();
            if (minRent != null) {
                filters.add('Rent__c >= :minRent');
                binds.put('minRent', minRent);
            }
            if (maxRent != null) {
                filters.add('Rent__c <= :maxRent');
                binds.put('maxRent', maxRent);
            }
            if (String.isNotBlank(status)) {
                if (!REPM_Constants.PROPERTY_STATUSES.contains(status)) {
                    throw REPM_Constants.auraError('Availability status is not valid.');
                }
                filters.add('Status__c = :status');
                binds.put('status', status);
            }
            if (String.isNotBlank(furnishingStatus)) {
                if (!REPM_Constants.FURNISHING_STATUSES.contains(furnishingStatus)) {
                    throw REPM_Constants.auraError('Furnishing status is not valid.');
                }
                filters.add('Furnishing_Status__c = :furnishingStatus');
                binds.put('furnishingStatus', furnishingStatus);
            }
            if (distanceKm != null) {
                if (distanceKm < 0) {
                    throw REPM_Constants.auraError('Distance must be zero or greater.');
                }
                if (latitude == null || longitude == null) {
                    throw REPM_Constants.auraError('Turn on location access before filtering by distance.');
                }
                // SOQL DISTANCE supports only > and <, so the entered range is exclusive of the boundary.
                filters.add('DISTANCE(Location__c, GEOLOCATION(:latitude, :longitude), \'km\') < :distanceKm');
                binds.put('latitude', latitude);
                binds.put('longitude', longitude);
                binds.put('distanceKm', distanceKm);
            }

            String whereClause = filters.isEmpty() ? '' : ' WHERE ' + String.join(filters, ' AND ');
            Integer totalCount = Database.countQueryWithBinds(
                'SELECT COUNT() FROM Property__c' + whereClause,
                binds,
                AccessLevel.USER_MODE
            );
            Integer pageSize = REPM_Constants.PAGE_SIZE;
            binds.put('pageSize', pageSize);
            binds.put('offsetSize', offsetSize);
            List<Property__c> properties = Database.queryWithBinds(
                'SELECT Id, Name, Address__c, City__c, State__c, Country__c, Type__c, Furnishing_Status__c, Status__c, Rent__c, Location__Latitude__s, Location__Longitude__s ' +
                    'FROM Property__c' +
                    whereClause +
                    ' ORDER BY Name ASC, Id ASC LIMIT :pageSize OFFSET :offsetSize',
                binds,
                AccessLevel.USER_MODE
            );

            PropertyPage page = new PropertyPage();
            page.records = toRows(properties, latitude, longitude);
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
    public static Id createProperty(Property__c property, List<REPM_FilePayload> files) {
        try {
            validateProperty(property);
            validateFiles(files);
            property.Id = null;
            property.Images_Uploaded__c = true;
            applyGeocode(property);
            Database.insert(new List<Property__c>{ property }, AccessLevel.USER_MODE);
            Database.insert(buildFiles(property.Id, files), AccessLevel.USER_MODE);
            return property.Id;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(messageFrom(ex));
        }
    }

    @AuraEnabled(cacheable=true)
    public static Property__c getPropertyLocation(Id propertyId) {
        if (propertyId == null) {
            return null;
        }
        List<Property__c> properties = [
            SELECT
                Id,
                Name,
                Full_Address__c,
                Address__c,
                City__c,
                State__c,
                Postal_Code__c,
                Country__c,
                Location__Latitude__s,
                Location__Longitude__s
            FROM Property__c
            WHERE Id = :propertyId
            WITH USER_MODE
            LIMIT 1
        ];
        if (properties.isEmpty()) {
            throw REPM_Constants.auraError('Property not found or you do not have access.');
        }
        return properties[0];
    }

    @AuraEnabled
    public static Property__c geocodeProperty(Id propertyId) {
        try {
            if (propertyId == null) {
                throw REPM_Constants.auraError('Property is required.');
            }
            List<Property__c> properties = [
                SELECT Id, Address__c, City__c, State__c, Postal_Code__c, Country__c
                FROM Property__c
                WHERE Id = :propertyId
                WITH USER_MODE
                LIMIT 1
            ];
            if (properties.isEmpty()) {
                throw REPM_Constants.auraError('Property not found or you do not have access.');
            }
            REPM_GeocodingService.GeoPoint point = REPM_GeocodingService.geocodeAddress(
                REPM_GeocodingService.buildAddress(properties[0])
            );
            if (point == null) {
                throw REPM_Constants.auraError('No map location was found for this address.');
            }
            Property__c updateRow = new Property__c(Id = propertyId);
            updateRow.Location__Latitude__s = point.latitude;
            updateRow.Location__Longitude__s = point.longitude;
            Database.update(new List<Property__c>{ updateRow }, AccessLevel.USER_MODE);
            List<Property__c> refreshed = [
                SELECT Id, Name, Full_Address__c, Location__Latitude__s, Location__Longitude__s
                FROM Property__c
                WHERE Id = :propertyId
                LIMIT 1
            ];
            return refreshed[0];
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw REPM_Constants.auraError(messageFrom(ex));
        }
    }

    private static void applyGeocode(Property__c property) {
        if (!REPM_TriggerBypass.geocodeEnabled()) {
            return;
        }
        try {
            REPM_GeocodingService.GeoPoint point = REPM_GeocodingService.geocodeAddress(
                REPM_GeocodingService.buildAddress(property)
            );
            if (point != null) {
                property.Location__Latitude__s = point.latitude;
                property.Location__Longitude__s = point.longitude;
            }
        } catch (Exception ex) {
            // The property is still saved when the geocoder is unavailable. The queueable retries later.
        }
    }

    private static void validateProperty(Property__c property) {
        if (
            property == null ||
            String.isBlank(property.Name) ||
            String.isBlank(property.Address__c) ||
            String.isBlank(property.City__c) ||
            String.isBlank(property.State__c) ||
            String.isBlank(property.Postal_Code__c) ||
            String.isBlank(property.Country__c) ||
            String.isBlank(property.Description__c) ||
            property.Rent__c == null ||
            String.isBlank(property.Type__c) ||
            String.isBlank(property.Status__c)
        ) {
            throw REPM_Constants.auraError('Complete all required property fields.');
        }
        if (!REPM_Constants.PROPERTY_TYPES.contains(property.Type__c)) {
            throw REPM_Constants.auraError('Type must be Residential or Commercial.');
        }
        if (!REPM_Constants.PROPERTY_STATUSES.contains(property.Status__c)) {
            throw REPM_Constants.auraError('Status must be Occupied or Available.');
        }
        if (
            String.isNotBlank(property.Furnishing_Status__c) &&
            !REPM_Constants.FURNISHING_STATUSES.contains(property.Furnishing_Status__c)
        ) {
            throw REPM_Constants.auraError('Furnishing status is not valid.');
        }
        if (property.Rent__c <= 0) {
            throw REPM_Constants.auraError('Rent must be greater than zero.');
        }
    }

    private static void validateFiles(List<REPM_FilePayload> files) {
        if (files == null || files.isEmpty()) {
            throw REPM_Constants.auraError('At least one property image is required.');
        }
        if (files.size() > REPM_Constants.MAX_PROPERTY_FILES) {
            throw REPM_Constants.auraError('Upload 10 images or fewer.');
        }
        for (REPM_FilePayload file : files) {
            if (file == null || String.isBlank(file.base64Data)) {
                throw REPM_Constants.auraError('Each property image must include file contents.');
            }
            String payload = normalizedBase64(file.base64Data);
            if (payload.length() > REPM_Constants.MAX_FILE_BASE64_LENGTH) {
                throw REPM_Constants.auraError('Each image must be smaller than about 1 MB.');
            }
            String contentType = file.contentType == null ? '' : file.contentType.toLowerCase();
            if (!contentType.startsWith('image/')) {
                throw REPM_Constants.auraError('Only image files can be uploaded for a property.');
            }
        }
    }

    private static List<ContentVersion> buildFiles(Id propertyId, List<REPM_FilePayload> files) {
        List<ContentVersion> versions = new List<ContentVersion>();
        for (REPM_FilePayload file : files) {
            String path = safeFileName(file.fileName);
            versions.add(
                new ContentVersion(
                    Title = path.contains('.') ? path.substring(0, path.lastIndexOf('.')) : path,
                    PathOnClient = path,
                    VersionData = EncodingUtil.base64Decode(normalizedBase64(file.base64Data)),
                    FirstPublishLocationId = propertyId
                )
            );
        }
        return versions;
    }

    private static String normalizedBase64(String value) {
        Integer comma = value == null ? -1 : value.indexOf(',');
        if (value != null && value.startsWith('data:') && comma > -1) {
            return value.substring(comma + 1);
        }
        return value;
    }

    private static String safeFileName(String fileName) {
        String name = String.isBlank(fileName) ? 'property-image.png' : fileName.trim().replace('\\', '/');
        Integer slash = name.lastIndexOf('/');
        if (slash >= 0) {
            name = name.substring(slash + 1);
        }
        if (!name.contains('.')) {
            name += '.png';
        }
        return name;
    }

    private static List<PropertyRow> toRows(List<Property__c> properties, Decimal latitude, Decimal longitude) {
        List<PropertyRow> rows = new List<PropertyRow>();
        for (Property__c property : properties) {
            PropertyRow row = new PropertyRow();
            row.id = property.Id;
            row.name = property.Name;
            row.address = property.Address__c;
            row.city = property.City__c;
            row.state = property.State__c;
            row.country = property.Country__c;
            row.propertyType = property.Type__c;
            row.furnishingStatus = property.Furnishing_Status__c;
            row.status = property.Status__c;
            row.rent = property.Rent__c;
            row.distanceKm = distanceKmBetween(
                latitude,
                longitude,
                property.Location__Latitude__s,
                property.Location__Longitude__s
            );
            rows.add(row);
        }
        return rows;
    }

    private static Decimal distanceKmBetween(Decimal latitude, Decimal longitude, Decimal otherLatitude, Decimal otherLongitude) {
        if (latitude == null || longitude == null || otherLatitude == null || otherLongitude == null) {
            return null;
        }
        Double earthRadiusKm = 6371.0;
        Double latitudeDelta = toRadians(otherLatitude - latitude);
        Double longitudeDelta = toRadians(otherLongitude - longitude);
        Double startLat = toRadians(latitude);
        Double endLat = toRadians(otherLatitude);
        Double a =
            Math.sin(latitudeDelta / 2) * Math.sin(latitudeDelta / 2) +
            Math.cos(startLat) * Math.cos(endLat) * Math.sin(longitudeDelta / 2) * Math.sin(longitudeDelta / 2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Decimal.valueOf(earthRadiusKm * c).setScale(2);
    }

    private static Double toRadians(Decimal degrees) {
        return degrees.doubleValue() * Math.PI / 180;
    }

    private static String messageFrom(Exception ex) {
        if (ex instanceof DmlException) {
            DmlException dml = (DmlException) ex;
            return dml.getNumDml() > 0 ? dml.getDmlMessage(0) : dml.getMessage();
        }
        return String.isBlank(ex.getMessage()) ? 'Request failed.' : ex.getMessage();
    }
}
