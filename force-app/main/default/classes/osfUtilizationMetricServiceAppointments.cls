public without sharing class osfUtilizationMetricServiceAppointments {

    /*
    What is being offered in this class is a way to get a Utilization Metric Record which contains a SERVICE TERRITORY MEMBER (thus Service Territory and Service Resource)
    Service Appointments of the Date of Assignment, Absence of the Date of Service Appointments, Break on the Date of Assignment, Overtime of the Date 
    */

    @InvocableMethod(label='Service Appointment Utilization Metric' description='Returns the amount of hours for Service Appointments')
    public static List<ID> servicAppointmentUtilizationMetric(List<ID> utilizationMetricRecords){
        Utilization_Metric__c singleUM = [SELECT ID, Date__c, Service_Resource__c, Service_Territory__c, Total_Scheduled__c FROM Utilization_Metric__c WHERE Id in: utilizationMetricRecords LIMIT 1][0];        
        List<AssignedResource> assignedResourceList = [SELECT Id, ServiceResourceId, ServiceAppointmentId FROM AssignedResource WHERE CreatedDate >=: System.Today()-1 AND ServiceResource.Id =: singleUM.Service_Resource__c];
        update getServiceAppointmentDurationAmount(singleUM,assignedResourceList);

        return utilizationMetricRecords;
    }


    //AC Notes + Comments
    /* Takes in a single UM record which should have been created in the Schedule FLow. Assigns it the Service Appointment Amount scheduled
    */
    private static Utilization_Metric__c getServiceAppointmentDurationAmount(Utilization_Metric__c singleUM , List<AssignedResource> assignedResourceList){
        Decimal totalDurationMinutes;
        List<Id> serviceAppointmentIds = new List<Id>();
        for(AssignedResource ar: assignedResourceList){
            serviceAppointmentIds.add(ar.ServiceAppointmentId);
        }
        List<ServiceAppointment> saList = [SELECT Id, Duration, DurationType, SchedStartTime FROM ServiceAppointment WHERE Id in: serviceAppointmentIds AND serviceTerritoryId =: singleUM.Service_Territory__c];
        for (ServiceAppointment sa: saList){
            if (sa.DurationType == 'Minutes'){
                totalDurationMinutes += sa.Duration;
            }else{
                totalDurationMinutes += sa.Duration * 60;
            }
        }
        singleUM.Total_Scheduled__c = totalDurationMinutes;
        return singleUm;
    }

    private static Utilization_Metric__c getAbsenceDurationAmount(Utilization_Metric__c singleUM){

        return singleUM;
    }
    
}