@isTest
private with sharing class AddTerritoryToWorkOrderTriggerTest {
    private static testMethod void TestAddTerritoryToWorkOrderTrigger() {
        WorkOrder w = new WorkOrder();
        insert w;
        OperatingHours o = new OperatingHours(Name='test');
        insert o;
        ServiceTerritory t = new ServiceTerritory(Name='test', OperatingHoursId = o.Id, IsActive = true);
        insert t;
        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = w.Id, ServiceTerritoryId = t.Id);
        insert sa;

    }
}