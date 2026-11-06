import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRequests from '@salesforce/apex/REPM_MaintenanceController.getRequests';
import createRequest from '@salesforce/apex/REPM_MaintenanceController.createRequest';
import { MAINTENANCE_STATUSES, reduceError, showToast } from 'c/repmUtils';

export default class RepmMaintenanceList extends NavigationMixin(LightningElement) {
    records = [];
    pageNumber = 1;
    totalPages = 1;
    totalCount = 0;
    loading = false;
    creating = false;
    saving = false;
    propertyId;
    status = 'Open';
    description = '';
    statusOptions = MAINTENANCE_STATUSES;

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

    handleStatus(event) {
        this.status = event.detail.value;
    }

    handleDescription(event) {
        this.description = event.detail.value;
    }

    handleView(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Maintenance_Request__c',
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
        if (!this.propertyId) {
            showToast(this, 'Choose the property for this request.', 'error');
            return;
        }
        this.saving = true;
        try {
            const created = await createRequest({
                propertyId: this.propertyId,
                status: this.status,
                description: this.description
            });
            this.creating = false;
            this.propertyId = null;
            this.status = 'Open';
            this.description = '';
            this.pageNumber = 1;
            showToast(this, `Request ${created.name} assigned to ${created.vendorName || 'no vendor yet'}.`, 'success');
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
            const page = await getRequests({ pageNumber: this.pageNumber });
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
