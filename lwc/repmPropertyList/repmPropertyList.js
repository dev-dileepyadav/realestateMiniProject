import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getProperties from '@salesforce/apex/REPM_PropertyController.getProperties';
import { FURNISHING_STATUSES, PROPERTY_STATUSES, reduceError, showToast } from 'c/repmUtils';

const ALL = [{ label: 'All', value: '' }];

export default class RepmPropertyList extends NavigationMixin(LightningElement) {
    records = [];
    pageNumber = 1;
    totalPages = 1;
    totalCount = 0;
    loading = false;
    creating = false;
    minRent = null;
    maxRent = null;
    status = '';
    furnishingStatus = '';
    distanceKm = null;
    latitude = null;
    longitude = null;
    locationReady = false;

    statusOptions = ALL.concat(PROPERTY_STATUSES);
    furnishingOptions = ALL.concat(FURNISHING_STATUSES);

    connectedCallback() {
        this.load();
    }

    get rows() {
        return this.records.map((row) => ({
            ...row,
            statusClass: row.status === 'Occupied' ? 'slds-badge slds-theme_warning' : 'slds-badge slds-theme_success',
            location: [row.city, row.state, row.country].filter(Boolean).join(', ')
        }));
    }

    get hasRecords() {
        return this.records.length > 0;
    }

    get locationLabel() {
        return this.locationReady ? 'Location captured' : 'Location not captured';
    }

    handleCreate() {
        this.creating = true;
    }

    handleCancel() {
        this.creating = false;
    }

    handleCreated(event) {
        this.creating = false;
        showToast(this, 'Property created.', 'success');
        this.pageNumber = 1;
        this.load();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.detail.recordId,
                objectApiName: 'Property__c',
                actionName: 'view'
            }
        });
    }

    handleMinRent(event) {
        this.minRent = this.toNumber(event.detail.value);
    }

    handleMaxRent(event) {
        this.maxRent = this.toNumber(event.detail.value);
    }

    handleStatus(event) {
        this.status = event.detail.value;
    }

    handleFurnishing(event) {
        this.furnishingStatus = event.detail.value;
    }

    handleDistance(event) {
        this.distanceKm = this.toNumber(event.detail.value);
    }

    handleLocation() {
        if (!navigator.geolocation) {
            showToast(this, 'Location is unavailable in this browser.', 'error');
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (position) => {
                this.latitude = position.coords.latitude;
                this.longitude = position.coords.longitude;
                this.locationReady = true;
                showToast(this, 'Location captured. Apply filters to see nearby properties.', 'success');
            },
            () => {
                this.locationReady = false;
                showToast(this, 'Allow location access to filter properties by distance.', 'error');
            }
        );
    }

    handleApply() {
        if (this.distanceKm != null && !this.locationReady) {
            showToast(this, 'Use your location before filtering by distance.', 'error');
            return;
        }
        this.pageNumber = 1;
        this.load();
    }

    handleClear() {
        this.minRent = null;
        this.maxRent = null;
        this.status = '';
        this.furnishingStatus = '';
        this.distanceKm = null;
        this.latitude = null;
        this.longitude = null;
        this.locationReady = false;
        this.pageNumber = 1;
        this.template.querySelectorAll('lightning-input, lightning-combobox').forEach((field) => {
            field.value = null;
        });
        this.load();
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
            this.load();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
            this.load();
        }
    }

    handleView(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Property__c',
                actionName: 'view'
            }
        });
    }

    async load() {
        this.loading = true;
        try {
            const page = await getProperties({
                pageNumber: this.pageNumber,
                minRent: this.minRent,
                maxRent: this.maxRent,
                status: this.status,
                furnishingStatus: this.furnishingStatus,
                latitude: this.locationReady ? this.latitude : null,
                longitude: this.locationReady ? this.longitude : null,
                distanceKm: this.distanceKm
            });
            this.records = page.records || [];
            this.totalCount = page.totalCount || 0;
            this.pageNumber = page.pageNumber || 1;
            this.totalPages = page.totalPages || 1;
        } catch (error) {
            this.records = [];
            showToast(this, reduceError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    toNumber(value) {
        if (value === '' || value === null || value === undefined) {
            return null;
        }
        const numeric = Number(value);
        return Number.isNaN(numeric) ? null : numeric;
    }
}
