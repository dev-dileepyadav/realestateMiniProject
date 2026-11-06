import { createElement } from 'lwc';
import RepmDashboard from 'c/repmDashboard';
import getDashboard from '@salesforce/apex/REPM_DashboardController.getDashboard';

jest.mock(
    '@salesforce/apex/REPM_DashboardController.getDashboard',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

describe('c-repm-dashboard', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders occupancy, maintenance counts, and expiring leases', async () => {
        getDashboard.mockResolvedValue({
            expiringCount: 1,
            expiringLeases: [
                {
                    id: 'a011',
                    name: 'LA-0001',
                    propertyName: 'Harbor House',
                    tenantName: 'Avery Stone',
                    endDate: '2026-12-01',
                    rent: 2200
                }
            ],
            maintenanceByStatus: [
                { status: 'Open', count: 2, percent: 50 },
                { status: 'In Progress', count: 1, percent: 25 },
                { status: 'Completed', count: 1, percent: 25 },
                { status: 'Cancelled', count: 0, percent: 0 }
            ],
            occupancyRate: 50,
            occupiedCount: 1,
            availableCount: 1,
            totalProperties: 2
        });

        const element = createElement('c-repm-dashboard', { is: RepmDashboard });
        document.body.appendChild(element);
        await Promise.resolve();
        await Promise.resolve();

        const text = element.shadowRoot.textContent;
        expect(text).toContain('50%');
        expect(text).toContain('LA-0001');
        expect(text).toContain('Open');
        expect(text).toContain('1 occupied of 2 properties');
    });
});
