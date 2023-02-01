public with sharing class osfUtilizationMetricServiceAppointments {


    @InvocableMethod(label='Service Appointment Utilization Metric' description='Returns the amount of hours for Service Appointments')
    public static List<ID> servicAppointmentUtilizationMetric(List<ID> serviceAppointments){
        
        Integer totalDurationMinutes;
        //parameter should be Assigned Reousrce. Get the assignedresource.apptid. Pass that into line 9's where clause
        List<ServiceAppointment> saList = [SELECT Id, Duration, DurationType, SchedStartTime FROM ServiceAppointment WHERE Id in: serviceAppointments];
        for (ServiceAppointment sa: saList){
            if (sa.DurationType == 'Minutes'){
                totalDurationMinutes += sa.Duration;
            }else{
                totalDurationMinutes += sa.Duration * 60;
            }
        }


    }

    public static Utilization_Metric__c checkOrCreateUM()
    
}