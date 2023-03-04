global class osfUtilizationMetricJob implements Schedulable {
    global void execute(SchedulableContext SC) {
       osfUtilizationReport osfReport = new osfUtilizationReport(); 
       Database.executeBatch(osfReport, 4);
       osfUtilizatonReportAssignedResource osfARReport = new osfUtilizatonReportAssignedResource(); 
       Database.executeBatch(osfARReport, 20);
       osfUtilizationReportResourceAbsence osfRAReport = new osfUtilizationReportResourceAbsence(); 
       Database.executeBatch(osfRAReport, 20);
    }
 }