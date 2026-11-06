import { createElement } from 'lwc';
import RepmPropertyList from 'c/repmPropertyList';
import getProperties from '@salesforce/apex/REPM_PropertyController.getProperties';

jest.mock(
    '@salesforce/apex/REPM_PropertyController.getProperties',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

const flush = () => Promise.resolve();

describe('c-repm-property-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('loads the first server page and renders the property', async () => {
        getProperties.mockResolvedValue({
            records: [
                {
                    id: 'a001',
                    name: 'Harbor House',
                    city: 'Austin',
                    state: 'TX',
                    country: 'USA',
                    propertyType: 'Residential',
                    furnishingStatus: 'Furnished',
                    status: 'Available',
                    rent: 1800,
                    distanceKm: 1.2
                }
            ],
            totalCount: 1,
            pageNumber: 1,
            pageSize: 25,
            totalPages: 1
        });

        const element = createElement('c-repm-property-list', { is: RepmPropertyList });
        document.body.appendChild(element);
        await flush();
        await flush();

        expect(getProperties).toHaveBeenCalledWith({
            pageNumber: 1,
            minRent: null,
            maxRent: null,
            status: '',
            furnishingStatus: '',
            latitude: null,
            longitude: null,
            distanceKm: null
        });
        expect(element.shadowRoot.textContent).toContain('Harbor House');
        const paginator = element.shadowRoot.querySelector('c-repm-paginator');
        expect(paginator.shadowRoot.textContent).toContain('25 per page');
    });
});
