@isTest
private with sharing class ForecastTriggerTest {
    private static testMethod void TestForecastTrigger() {
        Opportunity o = new Opportunity(Name='test',StageName='test', CloseDate=Date.today());
        insert o;
        Class_Type_Forecast__c ctf = new Class_Type_Forecast__c(Class_Type__c = 'Class 1', Annual_Mileage_per_Unit__c = 100, of_Units__c = 10, Labor_Rate__c = 150, Opportunity__c = o.Id);
        insert ctf;

    }
}