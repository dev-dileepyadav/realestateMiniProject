/**
 * Test and system flags that keep automation from looping or calling out during unit tests.
 */
public with sharing class REPM_TriggerBypass {
    public static Boolean runGeocodeInTests = false;
    public static Boolean skipOccupancySync = false;
    public static Boolean skipLeaseTask = false;

    public static Boolean geocodeEnabled() {
        return !Test.isRunningTest() || runGeocodeInTests;
    }
}
