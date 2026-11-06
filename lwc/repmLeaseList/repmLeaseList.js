import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLeases from '@salesforce/apex/REPM_LeaseController.getLeases';
import createLease from '@salesforce/apex/REPM_LeaseController.createLease';
import { reduceError, showToast } from 'c/repmUtils';

export default class RepmLeaseList extends NavigationMixin(LightningElement) {
    records = [];
    pageNumber = 1;
    totalPages = 1;
    totalCount = 0;
    loading = false;
    creating = false;
    saving = false;
    propertyId;
    tenantId;
    rent = null;
    startDate;
    endDate;
    terms = '';

    connectedCallback() {
        this.load();
    }

    get hasRecords() {
        return this.records.length > 0;
    }

    handleCreate() {
        this.creating = true;
    }

    handleCancel() {
        this.creating = false;
    }

    handleProperty(event) {
        this.propertyId = event.detail.recordId;
    }

    handleTenant(event) {
        this.tenantId = event.detail.recordId;
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.detail.value;
    }

    handleRent(event) {
        const value = event.detail.value;
        this.rent = value === '' || value === null ? null : Number(value);
    }

    handleView(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Lease_Agreement__c',
                actionName: 'view'
            }
        });
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

    async handleSave() {
        const fields = [...this.template.querySelectorAll('lightning-input, lightning-textarea')];
        const fieldsValid = fields.every((field) => (typeof field.reportValidity === 'function' ? field.reportValidity() : true));
        if (!this.propertyId || !this.tenantId) {
            showToast(this, 'Choose a property and a tenant.', 'error');
            return;
        }
        if (!fieldsValid) {
            return;
        }
        this.saving = true;
        try {
            await createLease({
                lease: {
                    sobjectType: 'Lease_Agreement__c',
                    Property__c: this.propertyId,
                    Tenant__c: this.tenantId,
                    Agreed_Monthly_Rent__c: this.rent,
                    Start_Date__c: this.startDate,
                    End_Date__c: this.endDate,
                    Terms__c: this.terms
                }
            });
            this.creating = false;
            this.propertyId = null;
            this.tenantId = null;
            this.rent = null;
            this.startDate = null;
            this.endDate = null;
            this.terms = '';
            this.pageNumber = 1;
            showToast(this, 'Lease agreement created. The property is marked occupied while the lease is active.', 'success');
            await this.load();
        } catch (error) {
            showToast(this, reduceError(error), 'error');
        } finally {
            this.saving = false;
        }
    }

    async load() {
        this.loading = true;
        try {
            const page = await getLeases({ pageNumber: this.pageNumber });
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
}
