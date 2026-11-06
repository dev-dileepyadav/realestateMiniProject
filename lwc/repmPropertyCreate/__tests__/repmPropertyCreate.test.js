import { createElement } from 'lwc';
import RepmPropertyCreate from 'c/repmPropertyCreate';
import createProperty from '@salesforce/apex/REPM_PropertyController.createProperty';

jest.mock(
    '@salesforce/apex/REPM_PropertyController.createProperty',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

describe('c-repm-property-create', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('blocks save when no image is attached', async () => {
        const element = createElement('c-repm-property-create', { is: RepmPropertyCreate });
        document.body.appendChild(element);

        element.shadowRoot.querySelector('lightning-button[data-id="save"]').click();
        await Promise.resolve();

        expect(createProperty).not.toHaveBeenCalled();
        expect(element.shadowRoot.textContent).toContain('At least one property image is required.');
    });

    it('reads images from the file input and sends them to Apex', async () => {
        const file = new File(['img'], 'house.png', { type: 'image/png' });
        class FakeReader {
            readAsDataURL() {
                this.result = 'data:image/png;base64,aaaa';
                this.onload();
            }
        }
        const originalReader = global.FileReader;
        global.FileReader = FakeReader;
        createProperty.mockResolvedValue('a00100000000001AAA');

        const element = createElement('c-repm-property-create', { is: RepmPropertyCreate });
        document.body.appendChild(element);
        const values = {
            name: 'Harbor House',
            address: '100 Congress Ave',
            city: 'Austin',
            state: 'TX',
            postalCode: '78701',
            country: 'USA',
            description: 'Corner loft with a river view.'
        };
        Object.entries(values).forEach(([field, value]) => {
            element.shadowRoot.querySelector(`[data-field="${field}"]`).dispatchEvent(
                new CustomEvent('change', { detail: { value } })
            );
        });
        const inputs = [...element.shadowRoot.querySelectorAll('lightning-input')];
        const rentInput = inputs[inputs.length - 2];
        rentInput.dispatchEvent(new CustomEvent('change', { detail: { value: '1800' } }));
        const fileInput = inputs[inputs.length - 1];
        Object.defineProperty(fileInput, 'files', { configurable: true, value: [file] });
        fileInput.dispatchEvent(new CustomEvent('change'));
        element.shadowRoot.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea').forEach((field) => {
            field.reportValidity = () => true;
        });
        element.shadowRoot.querySelector('lightning-button[data-id="save"]').click();
        await Promise.resolve();
        await Promise.resolve();

        expect(createProperty).toHaveBeenCalledWith(
            expect.objectContaining({
                files: [{ fileName: 'house.png', base64Data: 'aaaa', contentType: 'image/png' }]
            })
        );
        global.FileReader = originalReader;
    });
});
