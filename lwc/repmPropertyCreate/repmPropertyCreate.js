import { LightningElement } from 'lwc';
import createProperty from '@salesforce/apex/REPM_PropertyController.createProperty';
import { FURNISHING_STATUSES, PROPERTY_STATUSES, PROPERTY_TYPES, reduceError, showToast } from 'c/repmUtils';

export default class RepmPropertyCreate extends LightningElement {
    name = '';
    address = '';
    city = '';
    state = '';
    postalCode = '';
    country = '';
    type = 'Residential';
    furnishingStatus = '';
    status = 'Available';
    rent = null;
    description = '';
    selectedFiles = [];
    previews = [];
    imageError;
    saving = false;

    typeOptions = PROPERTY_TYPES;
    statusOptions = PROPERTY_STATUSES;
    furnishingOptions = [{ label: 'None', value: '' }, ...FURNISHING_STATUSES];

    get disableSave() {
        return this.saving;
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.detail.value;
    }

    handleRent(event) {
        const value = event.detail.value;
        this.rent = value === '' || value === null ? null : Number(value);
    }

    handleFiles(event) {
        const detailFiles = event.detail && event.detail.files;
        const targetFiles = event.target && event.target.files;
        const files = Array.from(detailFiles && detailFiles.length ? detailFiles : targetFiles || []);
        const images = files.filter((file) => file.type && file.type.startsWith('image/'));
        if (images.length !== files.length) {
            this.imageError = 'Only image files can be uploaded.';
        } else if (images.length > 10) {
            this.imageError = 'Upload 10 images or fewer.';
        } else {
            this.imageError = undefined;
        }
        this.selectedFiles = images.slice(0, 10);
        this.previews = [];
        this.selectedFiles.forEach((file) => {
            const reader = new FileReader();
            reader.onload = () => {
                this.previews = [...this.previews, { name: file.name, url: reader.result }];
            };
            reader.readAsDataURL(file);
        });
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    async handleSave() {
        const fields = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')];
        const fieldsValid = fields.every((field) => (typeof field.reportValidity === 'function' ? field.reportValidity() : true));
        if (!this.selectedFiles.length) {
            this.imageError = 'At least one property image is required.';
        }
        if (!fieldsValid || !this.selectedFiles.length) {
            return;
        }

        this.saving = true;
        try {
            const files = await Promise.all(this.selectedFiles.map((file) => this.readFile(file)));
            const recordId = await createProperty({
                property: {
                    sobjectType: 'Property__c',
                    Name: this.name,
                    Address__c: this.address,
                    City__c: this.city,
                    State__c: this.state,
                    Postal_Code__c: this.postalCode,
                    Country__c: this.country,
                    Type__c: this.type,
                    Furnishing_Status__c: this.furnishingStatus || null,
                    Status__c: this.status,
                    Rent__c: this.rent,
                    Description__c: this.description
                },
                files
            });
            this.dispatchEvent(new CustomEvent('created', { detail: { recordId } }));
        } catch (error) {
            showToast(this, reduceError(error), 'error');
        } finally {
            this.saving = false;
        }
    }

    readFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = String(reader.result || '');
                resolve({
                    fileName: file.name,
                    base64Data: result.includes(',') ? result.split(',')[1] : result,
                    contentType: file.type
                });
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }
}
