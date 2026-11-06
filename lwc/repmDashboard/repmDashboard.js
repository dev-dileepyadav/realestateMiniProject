import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboard from '@salesforce/apex/REPM_DashboardController.getDashboard';
import { reduceError, showToast } from 'c/repmUtils';

export default class RepmDashboard extends NavigationMixin(LightningElement) {
    data;
    loading = false;

    connectedCallback() {
        this.load();
    }

    get occupancyLabel() {
        return this.data ? `${this.data.occupancyRate}%` : '0%';
    }

    get occupancyDetail() {
        if (!this.data) {
            return '';
        }
        return `${this.data.occupiedCount} occupied of ${this.data.totalProperties} properties`;
    }

    get expiringCount() {
        return this.data ? this.data.expiringCount : 0;
    }

    get expiringLeases() {
        return this.data && this.data.expiringLeases ? this.data.expiringLeases : [];
    }

    get hasExpiring() {
        return this.expiringLeases.length > 0;
    }

    get statusRows() {
        const rows = this.data && this.data.maintenanceByStatus ? this.data.maintenanceByStatus : [];
        return rows.map((row) => ({
            ...row,
            barStyle: `width: ${row.percent || 0}%`,
            percentLabel: `${Math.round(row.percent || 0)}%`
        }));
    }

    get occupancyStyle() {
        const rate = this.data ? this.data.occupancyRate : 0;
        return `width: ${rate || 0}%`;
    }

    handleRefresh() {
        this.load();
    }

    handleOpen(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Lease_Agreement__c',
                actionName: 'view'
            }
        });
    }

    async load() {
        this.loading = true;
        try {
            this.data = await getDashboard();
        } catch (error) {
            showToast(this, reduceError(error), 'error');
        } finally {
            this.loading = false;
        }
    }
}
