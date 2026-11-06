import { LightningElement, api } from 'lwc';

export default class RepmPaginator extends LightningElement {
    @api pageNumber = 1;
    @api totalPages = 1;
    @api totalCount = 0;
    @api disabled = false;

    get summary() {
        const records = this.totalCount === 1 ? '1 record' : `${this.totalCount || 0} records`;
        return `Page ${this.pageNumber} of ${this.totalPages} · ${records} · 25 per page`;
    }

    get disablePrevious() {
        return this.disabled || Number(this.pageNumber) <= 1;
    }

    get disableNext() {
        return this.disabled || Number(this.pageNumber) >= Number(this.totalPages);
    }

    handlePrevious() {
        this.dispatchEvent(new CustomEvent('previous'));
    }

    handleNext() {
        this.dispatchEvent(new CustomEvent('next'));
    }
}
