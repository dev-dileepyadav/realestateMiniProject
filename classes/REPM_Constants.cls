/**
 * Shared limits and picklist values for the property management app.
 */
public with sharing class REPM_Constants {
    public static final Integer PAGE_SIZE = 25;
    public static final Integer MAX_OFFSET = 2000;
    public static final Integer MAX_PROPERTY_FILES = 10;
    public static final Integer MAX_FILE_BASE64_LENGTH = 1500000;

    public static final String AVAILABLE = 'Available';
    public static final String OCCUPIED = 'Occupied';
    public static final String RESIDENTIAL = 'Residential';
    public static final String COMMERCIAL = 'Commercial';
    public static final String FURNISHED = 'Furnished';
    public static final String SEMI_FURNISHED = 'Semi-Furnished';
    public static final String UNFURNISHED = 'Unfurnished';

    public static final String MAINT_OPEN = 'Open';
    public static final String MAINT_IN_PROGRESS = 'In Progress';
    public static final String MAINT_COMPLETED = 'Completed';
    public static final String MAINT_CANCELLED = 'Cancelled';
    public static final String TASK_SUBJECT = 'Generate Lease Agreement';

    public static final Set<String> PROPERTY_TYPES = new Set<String>{ RESIDENTIAL, COMMERCIAL };
    public static final Set<String> FURNISHING_STATUSES = new Set<String>{ FURNISHED, SEMI_FURNISHED, UNFURNISHED };
    public static final Set<String> PROPERTY_STATUSES = new Set<String>{ AVAILABLE, OCCUPIED };
    public static final Set<String> MAINTENANCE_STATUSES = new Set<String>{
        MAINT_OPEN,
        MAINT_IN_PROGRESS,
        MAINT_COMPLETED,
        MAINT_CANCELLED
    };
    public static final Set<String> ACTIVE_MAINTENANCE_STATUSES = new Set<String>{ MAINT_OPEN, MAINT_IN_PROGRESS };
    public static final List<String> MAINTENANCE_STATUS_ORDER = new List<String>{
        MAINT_OPEN,
        MAINT_IN_PROGRESS,
        MAINT_COMPLETED,
        MAINT_CANCELLED
    };

    public static Integer pageNumber(Integer requested) {
        return (requested == null || requested < 1) ? 1 : requested;
    }

    public static Integer offset(Integer requestedPage) {
        return (pageNumber(requestedPage) - 1) * PAGE_SIZE;
    }

    public static Integer pageCount(Integer totalCount) {
        if (totalCount == null || totalCount < 1) {
            return 1;
        }
        return (Integer) Math.ceil(totalCount / (Decimal) PAGE_SIZE);
    }

    public static AuraHandledException auraError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }
}
