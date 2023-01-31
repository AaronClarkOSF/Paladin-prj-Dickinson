public without sharing class osfUtilizationReport {


    @InvocableMethod(label='Configure Utilization Metric Data' description='Takes in Utiilization Metric Ids, Updates their records to support complicated math')
    public static List<ID> createUtilizationRecord(List<ID> utilizationMetricIds){
        List<Utilization_Metric__c> utilizationMetricList = [SELECT ID, Absences__c, Appointments__c, Breaks__c, Overtime__c, Travel_Time__c, Service_Resource__c, Service_Territory__c, Report_End_Date_Time__c, Report_Start_Date_Time__c FROM Utilization_Metric__c WHERE ID IN: utilizationMetricIds];
        
        for (Utilization_Metric__c um: utilizationMetricList){
            if (um.Absences__c){
                sumResourceAbsenceData(getAbsenceData(um.Service_Resource__c, um.Report_Start_Date_Time__c, um.Report_End_Date_Time__c));
            }
            if (um.Appointments__c){
                sumAppointmentData(getAppointmentsData(um.Service_Resource__c, um.Service_Territory__c, um.Report_Start_Date_Time__c, um.Report_End_Date_Time__c));
            }
        }

        List<ID> successfulResults = new List<ID>();

        Database.SaveResult [] updateResult = Database.update(utilizationMetricList, false);
            for (Database.SaveResult r : updateResult){
                if (r.isSuccess()){
                    successfulResults.add(r.Id);
                }else{
                    for (Database.Error e : r.getErrors()){ //here you can call those custom object field from A method and assign the value : e.getMessage()
                    
                    }
                }
            }
            return successfulResults;
        }


        private static List<ResourceAbsence> getAbsenceData(ID serviceResource, DateTime startdate, DateTime endDate){
            if(endDate != null){
                return [SELECT ID, Start, End FROM ResourceAbsence WHERE ResourceId =:serviceResource AND Start <=: startdate AND End >=: endDate];
            }else{
                return [SELECT ID, Start, End FROM ResourceAbsence WHERE ResourceId =:serviceResource AND Start <=: startdate AND End >=: System.Now()];
            }

        }

        private static List<AssignedResource> getAppointmentsData(ID serviceResource, ID serviceTerritoryId, DateTime startdate, DateTime endDate){
           //ServiceApointment.ActualDuration, ServiceAppointment.ActualTravelTime,
            return [SELECT ID, ServiceAppointment.AppointmentNumber,  ServiceAppointment.ServiceTerritoryID, ServiceResource.Name FROM AssignedResource WHERE ServiceAppointmentID IN (SELECT Id FROM ServiceAppointment WHERE EarliestStartTime >=: startDate AND EarliestStartTime <=: endDate) AND (ServiceAppointment.ServiceTerritoryID =: serviceTerritoryId)];
        }  

        private static void getBreakData(ID serviceResource, ID serviceTerritoryId, DateTime startdate, DateTime endDate){
        }  

        private static void getOvertimeData(ID serviceResource, ID serviceTerritoryId, DateTime startdate, DateTime endDate){
        }

        private static void sumResourceAbsenceData(List<ResourceAbsence> resourceAbsences){
        }

        private static void sumAppointmentData(List<AssignedResource> AssignedResource){
        }

        private static void sumBreakData(List<ResourceAbsence> resourceAbsences){    
        }

        private static void sumOvertimeData(List<ResourceAbsence> resourceAbsences){    
        }
}