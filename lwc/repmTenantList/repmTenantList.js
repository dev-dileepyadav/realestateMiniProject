import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getTenants from '@salesforce/apex/REPM_TenantController.getTenants';
import createTenant from '@salesforce/apex/REPM_TenantController.createTenant';
import { reduceError, showToast } from 'c/repmUtils';

export default class RepmTenantList extends NavigationMixin(LightningElement) {
    records = [];
    pageNumber = 1;
    totalPages = 1;
    totalCount = 0;
    loading = false;
    creating = false;
    saving = false;
    name = '';
    phone = '';
    email = '';

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

    handleChange(event) {
        this[event.target.dataset.field] = event.detail.value;
    }

    handleView(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Tenant__c',
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
        const fields = [...this.template.querySelectorAll('lightning-input')];
        const fieldsValid = fields.every((field) => (typeof field.reportValidity === 'function' ? field.reportValidity() : true));
        if (!fieldsValid) {
            return;
        }
        this.saving = true;
        try {
            await createTenant({ name: this.name, phone: this.phone, email: this.email });
            this.creating = false;
            this.name = '';
            this.phone = '';
            this.email = '';
            this.pageNumber = 1;
            showToast(this, 'Tenant created.', 'success');
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
            const page = await getTenants({ pageNumber: this.pageNumber });
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
