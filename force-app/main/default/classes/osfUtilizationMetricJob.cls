global class osfUtilizationMetricJob implements Schedulable {
    global void execute(SchedulableContext SC) {
       osfUtilizationReport osfReport = new osfUtilizationReport(); 
       Database.executeBatch(osfReport);
    }
 }