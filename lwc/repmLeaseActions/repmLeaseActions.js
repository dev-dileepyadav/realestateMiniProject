import { LightningElement, api, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import JSPDF from '@salesforce/resourceUrl/jspdf';
import getLease from '@salesforce/apex/REPM_LeaseController.getLease';
import sendPdf from '@salesforce/apex/REPM_LeaseController.sendPdf';
import { reduceError, showToast } from 'c/repmUtils';

export default class RepmLeaseActions extends LightningElement {
    @api recordId;
    lease;
    error;
    working = false;
    wiredResult;

    @wire(getLease, { leaseId: '$recordId' })
    wiredLease(result) {
        this.wiredResult = result;
        if (result.data) {
            this.lease = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.lease = undefined;
            this.error = reduceError(result.error);
        }
    }

    get tenantEmail() {
        return this.lease && this.lease.Tenant__r ? this.lease.Tenant__r.Email__c : '';
    }

    get disableActions() {
        return this.working || !this.lease;
    }

    async handleDownload() {
        await this.withPdf((document) => {
            document.save(this.fileName());
            showToast(this, 'Lease agreement downloaded.', 'success');
        });
    }

    async handleSend() {
        await this.withPdf(async (document) => {
            await sendPdf({ leaseId: this.recordId, pdfBase64: document.output('datauristring') });
            showToast(this, 'Lease agreement emailed to the tenant.', 'success');
        });
    }

    async withPdf(action) {
        if (!this.lease) {
            return;
        }
        this.working = true;
        try {
            const document = this.buildPdf(await this.loadLibrary(), this.lease);
            await action(document);
        } catch (error) {
            showToast(this, reduceError(error), 'error');
        } finally {
            this.working = false;
        }
    }

    async loadLibrary() {
        if (window.jspdf && window.jspdf.jsPDF) {
            return window.jspdf.jsPDF;
        }
        await loadScript(this, JSPDF);
        if (!window.jspdf || !window.jspdf.jsPDF) {
            throw new Error('The PDF library did not load.');
        }
        return window.jspdf.jsPDF;
    }

    buildPdf(JsPDF, lease) {
        const doc = new JsPDF();
        let y = 20;
        const write = (text, size = 11, style = 'normal') => {
            doc.setFont('helvetica', style);
            doc.setFontSize(size);
            const lines = doc.splitTextToSize(text == null ? '' : String(text), 180);
            if (y + lines.length * 6 > 280) {
                doc.addPage();
                y = 20;
            }
            doc.text(lines, 14, y);
            y += lines.length * 6 + 2;
        };
        const propertyName = lease.Property__r ? lease.Property__r.Name : '';
        const address = lease.Property__r ? lease.Property__r.Full_Address__c : '';
        const tenantName = lease.Tenant__r ? lease.Tenant__r.Name : '';
        const email = lease.Tenant__r ? lease.Tenant__r.Email__c : '';
        const phone = lease.Tenant__r ? lease.Tenant__r.Phone_Number__c : '';
        write('Lease Agreement', 18, 'bold');
        write(lease.Name, 13, 'bold');
        write(`Status: ${lease.Status__c || ''}`);
        write(`Property: ${propertyName || ''}`);
        write(`Address: ${address || ''}`);
        write(`Tenant: ${tenantName || ''}`);
        write(`Email: ${email || ''}`);
        write(`Phone: ${phone || ''}`);
        write(`Agreed Monthly Rent: ${lease.Agreed_Monthly_Rent__c ?? ''}`);
        write(`Start Date: ${lease.Start_Date__c || ''}`);
        write(`End Date: ${lease.End_Date__c || ''}`);
        write('Terms', 14, 'bold');
        write(lease.Terms__c || 'No additional terms were recorded.');
        write(`Generated ${new Date().toLocaleDateString()}.`);
        return doc;
    }

    fileName() {
        const name = this.lease && this.lease.Name ? this.lease.Name : 'agreement';
        return `Lease-${name}.pdf`;
    }
}
