public with sharing class ForecastTriggerHandler {
    public static void HandleForecastTrigger(Class_Type_Forecast__c[] newRecords, Map<Id, Class_Type_Forecast__c> oldMap, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isBefore) {
        if(isBefore) {
            Map<String, Class_Forecast_Setting__mdt> classSettings = new Map<String, Class_Forecast_Setting__mdt>();
            for(Class_Forecast_Setting__mdt cfs : [SELECT Id, Annual_Hours__c, Average_CPM__c, MasterLabel, Average_Invoice_Numbers__c, Average_Labor_Rate__c, Average_Mileage_Delta__c, Labor_Percent__c, Lower_CPM_Percent__c, Median_CPM__c, Misc_Percent__c, Parts_Percent__c, Total_VIN__c, Upper_CPM_Percent__c from Class_Forecast_Setting__mdt]) {
                classSettings.put(cfs.MasterLabel, cfs);
            }
            for(Class_Type_Forecast__c ctf : newRecords) {
                if(isInsert || ctf.Class_Type__c != oldMap.get(ctf.Id).Class_Type__c) {
                    ctf.Annual_Hours_Data__c = classSettings.get(ctf.Class_Type__c).Annual_Hours__c;
                    ctf.Average_Invoice_Numbers__c = classSettings.get(ctf.Class_Type__c).Average_Invoice_Numbers__c;
                    ctf.Average_Labor_Rate__c = classSettings.get(ctf.Class_Type__c).Average_Labor_Rate__c;
                    ctf.Average_Mileage_Delta__c = classSettings.get(ctf.Class_Type__c).Average_Mileage_Delta__c;
                    ctf.Labor_Percent__c = classSettings.get(ctf.Class_Type__c).Labor_Percent__c;
                    ctf.Lower_CPM_Percent__c = classSettings.get(ctf.Class_Type__c).Lower_CPM_Percent__c;
                    ctf.Median_CPM__c = classSettings.get(ctf.Class_Type__c).Median_CPM__c;
                    ctf.Misc_Percent__c = classSettings.get(ctf.Class_Type__c).Misc_Percent__c;
                    ctf.Parts_Percent__c = classSettings.get(ctf.Class_Type__c).Parts_Percent__c;
                    ctf.Total_VIN__c = classSettings.get(ctf.Class_Type__c).Total_VIN__c;
                    ctf.Upper_CPM_Percent__c = classSettings.get(ctf.Class_Type__c).Upper_CPM_Percent__c;
                }
            }
        }
        else {
            Id[] opIds = new Id[0];
            if(isInsert) {
                for(Class_Type_Forecast__c ctf : newRecords) {
                    opIds.add(ctf.Opportunity__c);
                }
            }
            else if(isUpdate) {
                for(Class_Type_Forecast__c ctf : newRecords) {
                    if(ctf.Class_Type__c != oldMap.get(ctf.Id).Class_Type__c || ctf.Annual_Mileage_per_Unit__c != oldMap.get(ctf.Id).Annual_Mileage_per_Unit__c || ctf.of_Units__c != oldMap.get(ctf.Id).of_Units__c || ctf.Labor_Rate__c != oldMap.get(ctf.Id).Labor_Rate__c) {
                        opIds.add(ctf.Opportunity__c);
                    }
                }
            }
            else {
                for(Class_Type_Forecast__c ctf : oldMap.values()) {
                    opIds.add(ctf.Opportunity__c);
                }
            }
            if(opIds.size() > 0) {
                Map<Id, Class_Type_Forecast__c[]> forecastMap = new Map<Id, Class_Type_Forecast__c[]>();
                for(Class_Type_Forecast__c ctf : [Select Id, of_Units__c, Annual_ROs_per_Unit__c, Opportunity__c , Annual_Cost__c, CPM_Low__c, CPM_Average__c, CPM_High__c from Class_Type_Forecast__c where Opportunity__c in :opIds]) {
                    if(!forecastMap.containsKey(ctf.Opportunity__c)) {
                        forecastMap.put(ctf.Opportunity__c, new Class_Type_Forecast__c[0]);
                    }
                    forecastMap.get(ctf.Opportunity__c).add(ctf);
                }
                Map<Id, Decimal> rosPerYear = new Map<Id, Decimal>();
                Map<Id, Decimal> lowAvgCostPerRo = new Map<Id, Decimal>();
                Map<Id, Decimal> avgCostPerRo = new Map<Id, Decimal>();
                Map<Id, Decimal> highAvgCostPerRo = new Map<Id, Decimal>();
                Map<Id, Decimal> lowTotalCost = new Map<Id, Decimal>();
                Map<Id, Decimal> avgTotalCost = new Map<Id, Decimal>();
                Map<Id, Decimal> highTotalCost = new Map<Id, Decimal>();
                Map<Id, Decimal> noOfUnits = new Map<Id, Decimal>();
                Map<Id, Decimal> aa = new Map<Id, Decimal>();
                Map<Id, Decimal> ab = new Map<Id, Decimal>();
                for(Id i : opIds) {
                    rosPerYear.put(i, 0.00);
                    lowAvgCostPerRo.put(i, 0.00);
                    avgCostPerRo.put(i, 0.00);
                    highAvgCostPerRo.put(i, 0.00);
                    lowTotalCost.put(i, 0.00);
                    avgTotalCost.put(i, 0.00);
                    highTotalCost.put(i, 0.00);
                    noOfUnits.put(i, 0);
                    aa.put(i, 0.00);
                    ab.put(i, 0.00);
                    if(forecastMap.containsKey(i)) {
                        for(Class_Type_Forecast__c ctf : forecastMap.get(i)) {
                            rosPerYear.put(i, rosPerYear.get(i) + (ctf.Annual_ROs_per_Unit__c * ctf.of_Units__c));
                            avgTotalCost.put(i, avgTotalCost.get(i) + ctf.Annual_Cost__c);
                            noOfUnits.put(i, noOfUnits.get(i) + ctf.of_Units__c);
                            aa.put(i, aa.get(i) + (Math.round((ctf.Annual_Cost__c / ctf.Annual_ROs_per_Unit__c * ctf.CPM_Low__c / ctf.CPM_Average__c) * 100.00) / 100.00));
                            ab.put(i, ab.get(i) + (Math.round((ctf.Annual_Cost__c / ctf.Annual_ROs_per_Unit__c * ctf.CPM_High__c / ctf.CPM_Average__c) * 100.00) / 100.00));
                        }
                    }
                    rosPeryear.put(i, Math.round(rosPerYear.get(i)));
                    avgCostPerRo.put(i, (Math.floor(rosPerYear.get(i)) == 0 ? 0 : (Math.Round(avgTotalCost.get(i) / Math.floor(rosPerYear.get(i)) * 10.0) / 10.0)));
                    lowAvgCostPerRo.put(i, (noOfUnits.get(i) == 0 ? 0 : (Math.round(aa.get(i) / noOfUnits.get(i) * 10.0) / 10.0)));
                    highAvgCostPerRo.put(i, (noOfUnits.get(i) == 0 ? 0 : (Math.round(ab.get(i) / noOfUnits.get(i) * 10.0) / 10.0)));
                    lowTotalCost.put(i, Math.floor((lowAvgCostPerRo.get(i) * rosPerYear.get(i)) / 100.000) * 100);
                    highTotalCost.put(i, Math.floor((highAvgCostPerRo.get(i) * rosPerYear.get(i)) / 100.000) * 100);
                }
                for(Opportunity[] ops : [Select Id from Opportunity where Id in :opIds]) {
                    for(Opportunity o : ops) {
                        o.of_RO_s_per_Year__c = rosPerYear.get(o.Id);
                        o.Annual_Total_Cost_Low__c = lowTotalCost.get(o.Id);
                        o.Annual_Total_Cost_Avg__c = avgTotalCost.get(o.Id);
                        o.Annual_Total_Cost_High__c = highTotalCost.get(o.Id);
                        o.Avg_Cost_per_RO_Low__c = lowAvgCostPerRo.get(o.Id);
                        o.Avg_Cost_per_RO_Avg__c = avgCostPerRo.get(o.Id);
                        o.Avg_Cost_per_RO_High__c = highAvgCostPerRo.get(o.Id);
                    }
                    update ops;
                }
            }
        }
    }
}