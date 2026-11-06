import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPropertyLocation from '@salesforce/apex/REPM_PropertyController.getPropertyLocation';
import geocodeProperty from '@salesforce/apex/REPM_PropertyController.geocodeProperty';
import { reduceError, showToast } from 'c/repmUtils';

export default class RepmPropertyMap extends LightningElement {
    @api recordId;
    property;
    error;
    geocoding = false;
    wiredResult;

    @wire(getPropertyLocation, { propertyId: '$recordId' })
    wiredProperty(result) {
        this.wiredResult = result;
        if (result.data) {
            this.property = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.property = undefined;
            this.error = reduceError(result.error);
        }
    }

    get hasLocation() {
        return this.property && this.property.Location__Latitude__s != null && this.property.Location__Longitude__s != null;
    }

    get mapMarkers() {
        if (!this.hasLocation) {
            return [];
        }
        return [
            {
                location: {
                    Latitude: this.property.Location__Latitude__s,
                    Longitude: this.property.Location__Longitude__s
                },
                title: this.property.Name,
                description: this.property.Full_Address__c
            }
        ];
    }

    get address() {
        return this.property ? this.property.Full_Address__c : '';
    }

    async handleGeocode() {
        this.geocoding = true;
        try {
            this.property = await geocodeProperty({ propertyId: this.recordId });
            this.error = undefined;
            await refreshApex(this.wiredResult);
            showToast(this, 'Property location updated.', 'success');
        } catch (error) {
            showToast(this, reduceError(error), 'error');
        } finally {
            this.geocoding = false;
        }
    }
}
