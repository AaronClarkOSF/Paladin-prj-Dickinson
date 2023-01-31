public with sharing class ForecastController {

    @AuraEnabled
    public static Class_Type_Forecast__c[] getForecasts(Id opId){
        Class_Type_Forecast__c[] returnlist = new Class_Type_Forecast__c[0];
        returnList = [Select Id, Name, of_Units__c, Annual_Cost__c, Annual_Parts__c, Weekly_Hours__c, Labor_Rate__c, Annual_Labor__c, Annual_Misc__c, Annual_Hours__c, Annual_ROs_per_Unit__c, Annual_Mileage_per_Unit__c, Class_Type__c, Opportunity__c from Class_Type_Forecast__c where Opportunity__c = :opId order by Class_Type__c];
        return returnList;
    }

    @AuraEnabled
    public static Class_Type_Forecast__c[] saveForecasts(Class_Type_Forecast__c[] forecasts, Class_Type_Forecast__c[] delForecasts){
        Class_Type_Forecast__c[] toDel = new Class_Type_Forecast__c[0];
        for(Class_Type_Forecast__c f : delForecasts) {
            if(f.Id != null) {
                toDel.add(f);
            }
        }
        delete toDel;
        upsert forecasts;
        Id[] toreturn = new Id[0];
        for(Class_Type_Forecast__c f : forecasts) {
            toReturn.add(f.Id);
        }
        return [Select Id, Name, of_Units__c, Annual_Cost__c, Annual_Parts__c, Weekly_Hours__c, Labor_Rate__c, Annual_Labor__c, Annual_Misc__c, Annual_Hours__c, Annual_ROs_per_Unit__c, Annual_Mileage_per_Unit__c, Class_Type__c, Opportunity__c from Class_Type_Forecast__c where Id in :toReturn order by Class_Type__c];
    }
}