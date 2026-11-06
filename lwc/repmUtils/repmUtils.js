import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export function reduceError(error) {
    if (!error) {
        return 'Unexpected error';
    }
    if (Array.isArray(error.body)) {
        return error.body.map((item) => item.message).filter(Boolean).join(', ');
    }
    if (error.body && Array.isArray(error.body.pageErrors) && error.body.pageErrors.length) {
        return error.body.pageErrors.map((item) => item.message).join(', ');
    }
    if (error.body && typeof error.body.message === 'string') {
        return error.body.message;
    }
    if (typeof error.message === 'string') {
        return error.message;
    }
    return 'Unexpected error';
}

export function showToast(host, title, variant = 'info') {
    host.dispatchEvent(
        new ShowToastEvent({
            title,
            variant,
            mode: 'dismissible'
        })
    );
}

export const PROPERTY_TYPES = [
    { label: 'Residential', value: 'Residential' },
    { label: 'Commercial', value: 'Commercial' }
];

export const FURNISHING_STATUSES = [
    { label: 'Furnished', value: 'Furnished' },
    { label: 'Semi-Furnished', value: 'Semi-Furnished' },
    { label: 'Unfurnished', value: 'Unfurnished' }
];

export const PROPERTY_STATUSES = [
    { label: 'Available', value: 'Available' },
    { label: 'Occupied', value: 'Occupied' }
];

export const MAINTENANCE_STATUSES = [
    { label: 'Open', value: 'Open' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Cancelled', value: 'Cancelled' }
];
