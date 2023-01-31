public without sharing class osfUtilizationReport {


    @InvocableMethod(label='Configure Utilization Metric Data' description='Takes in Utiilization Metric Ids, Updates their records to support complicated math')
    public static List<IDs> createUtilizationRecord(List<ID> utilizationMetricIds){
        List<Utilization_Metric__c> utilizationMetricList = [SELECT ID, Absences__c, Appointments__c, Breaks__c, Overtime__c, Travel_Time__c, Service_Resource__c, Service_Territory__c, Report_End_Date_Time__c, Report_Start_Date_Time__c FROM Utilization_Metric__c WHERE ID IN: utilizationMetricIds]


        Database.SaveResult [] updateResult = Database.update(records, false);
            for (Database.SaveResult r : updateResult){
                if (r.isSuccess()){
                }else{
                    for (Database.Error e : r.getErrors()){ //here you can call those custom object field from A method and assign the value : e.getMessage()
                    
                    }
                }
            }
        }
        private static void getAbsenceData(ID serviceResource, ID Service_Territory__c, DateTime startdate, DateTime endDate){

        }  
        private static void getAppointmentsData(ID serviceResource, ID Service_Territory__c, DateTime startdate, DateTime endDate){

        }  
        private static void getBreakData(ID serviceResource, ID Service_Territory__c, DateTime startdate, DateTime endDate){

        }  

        private static void getOvertimeData(ID serviceResource, ID Service_Territory__c, DateTime startdate, DateTime endDate){

        }  
    }
                
}