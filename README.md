# Real Estate Property Management

Salesforce app for properties, tenants, lease agreements, vendors, and maintenance. The Lightning app is **Real Estate Management**.

In Setup, set **Deliverability** to All Email so lease PDFs and expiry reminders can be sent. The org also needs callout access to `https://nominatim.openstreetmap.org`, which is included as a remote site setting.

## What the app does

- **Properties** lists 25 records per page. Pagination and filters for rent, availability, furnishing, and nearby distance run in Apex. Distance uses the browser location and Salesforce geolocation (`DISTANCE`).
- Creating a property requires at least one image. Images are stored as Salesforce Files. The address is geocoded and shown on the property record page.
- Assigning a tenant on the property creates a task, **Generate Lease Agreement**.
- A tenant can hold leases for multiple properties. Each lease agreement belongs to one property. An active lease marks that property Occupied.
- The lease record page downloads a PDF with [jsPDF](https://github.com/parallax/jsPDF) and can email that PDF to the tenant.
- A daily job emails the tenant one month before the end date and again one day before it.
- A new maintenance request is assigned to the vendor with the fewest Open or In Progress requests.
- **Portfolio Dashboard** shows leases ending in the next 30 days, maintenance counts by status, and occupancy rate.
