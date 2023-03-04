// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

//Id batchJobId = Database.executeBatch(new osfUtilizationReport(), 200);

List<ServiceTerritoryMember> stms = [SELECT ID, Date_Value_EffectiveStartDate__c, EffectiveEndDate, ServiceTerritoryId, ServiceResourceId, ServiceTerritory.OperatingHoursId FROM ServiceTerritoryMember WHERE (Is_the_StartDate_a_Year_Or_Older__c = True AND Effectiveenddate = null) OR LastModifiedDate = TODAY];
System.debug('stms are ' + stms);
List<Utilization_Metric__c>  umRecords = new List<Utilization_Metric__c>();
for (ServiceTerritoryMember stm: stms){
    umRecords = [SELECT ID, Total_Scheduled__c,Total_NAs__c,Total_Available_Hours__c, Total_Available_Minutes__c, Total_Travel__c, Service_Resource__c, Service_Resource_Name__c, Report_Start_Date__c, Service_Territory__c , Service_Territory_Name__c FROM
        Utilization_Metric__c WHERE Service_Resource__c =: stm.ServiceResourceId AND Service_Territory__c =: stm.ServiceTerritoryID  AND  Report_Start_Date__c >=: stm.Date_Value_EffectiveStartDate__c AND 
        Report_Start_Date__c <=: (stm.EffectiveEndDate == null ? stm.Date_Value_EffectiveStartDate__c + 365: stm.Date_Value_EffectiveEndDate__c)];
    }
System.debug('um records ' + umRecords);
 


