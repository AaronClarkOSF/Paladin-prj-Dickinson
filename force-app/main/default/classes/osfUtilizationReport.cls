public without sharing class osfUtilizationReport implements Database.Batchable<sObject> {
    DateTime startDateTime;
    Date startDate;

    //query Assigned Resource
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = System.today();
        String queryString = 'SELECT ID, ServiceAppointmentId, ServiceAppointment.AppointmentNumber,ServiceAppointment.Schedule_Start_Day__c, ServiceAppointment.DurationType, ServiceAppointment.Duration, ServiceAppointment.ServiceTerritoryID, ServiceResource.Name FROM AssignedResource  WHERE CREATEDDATE >: Yesterday ';
        return Database.getQueryLocator(queryString);
    }

    //Perform actions to create or update the existing U.M. records based on Service Resource and Service Territory
    public void execute(Database.BatchableContext BC, List<AssignedResource> scope){
        System.debug('***Batch Started***');
        //call your batch method here, or just write your logic instead.
        List<Utilization_Metric__c> records = new List<Utilization_Metric__c>();
       for(AssignedResource ar: scope){
            Utilization_Metric__c record = performBatchActions(ar);
       }
       upsert records;
    }
    
    //send an email with completion information
    public void finish(Database.BatchableContext BC){}


    //"Parent" method that executes the order of data compilation
    public Utilization_Metric__c performBatchActions( AssignedResource ar){
        this.startDateTime = ar.ServiceAppointment.SchedStartTime;
        this.startDate = Date.newInstance(this.startDateTime.year(), this.startDateTime.month(), this.startDateTime.day());

        Utilization_Metric__c record = findUtilizationMetricRecord(ar);
        putServiceAppointmentDurations(record, ar);
        putResourceAbsences(record, ar);
        return record;
    }

    //an if/else that locates an existing U.M. record based on Date, Serv. Territory Id, and Service Resource Id
    private  Utilization_Metric__c findUtilizationMetricRecord (AssignedResource ar){
        Id serviceTerritoryId =  ar.ServiceAppointment.ServiceTerritoryID;
        Utilization_Metric__c record = [SELECT ID, Total_Scheduled__c, Service_Resource__c, Report_Start_Date__c, Service_Territory__c  FROM Utilization_Metric__c WHERE Service_Resource__c =: ar.ServiceResourceId AND  Report_Start_Date__c =: this.startDate AND Service_Territory__c =: serviceTerritoryId   LIMIT 1];
        if (record == null){
            return createUtilizationMetricRecord(ar, serviceTerritoryId);
        }else{
            return record;
        }
    }

    //a sum method to add the Service Appointment Duration by first checking duration type
     private  Utilization_Metric__c putServiceAppointmentDurations(Utilization_Metric__c record, AssignedResource ar){
        if (ar.ServiceAppointment.DurationType == 'Hours'){
            Integer minutes = (Integer) ar.ServiceAppointment.Duration * 60;
            record.Total_Scheduled__c += minutes;
        }else{
            record.Total_Scheduled__c += ar.ServiceAppointment.Duration;
        }
        return record;
    }

    private Utilization_Metric__c putResourceAbsences (Utilization_Metric__c record, AssignedResource ar){
        List<ResourceAbsence> resourceAbsences = [SELECT Id, Start, End FROM ResourceAbsence WHERE resourceId =: ar.ServiceResourceId];
        Long totalMinutesofAbsence;
        if (resourceAbsences != null && resourceAbsences.size() > 1){
            totalMinutesofAbsence = minutesOfAbsence(resourceAbsences);
        }else if(resourceAbsences.size() == 1){
            totalMinutesofAbsence = (resourceAbsences[0].Start.getTime() - resourceAbsences[0].End.getTime()) /60000;
        }
        else{
            totalMinutesofAbsence = 0;
        }
        record.Total_NAs__c = (Integer) totalMinutesofAbsence;
        return record;
    }

    private Integer minutesOfAbsence(List<ResourceAbsence> resourceAbsences){
        Long totalMinutesofAbsence;
        for (ResourceAbsence ra: resourceAbsences){
            totalMinutesofAbsence += (resourceAbsences[0].Start.getTime() - resourceAbsences[0].End.getTime())/ 60000;
        }
        return (Integer) totalMinutesofAbsence;
    }

    //if no U.M. record was found then create new record with Start Date, Service Resource Id, and Service Territory Id
    private  Utilization_Metric__c createUtilizationMetricRecord(AssignedResource ar, Id serviceTerritoryId){
        Utilization_Metric__c newUtilizationMetric = new Utilization_Metric__c();
        newUtilizationMetric.Report_Start_Date__c = this.startDate;
        newUtilizationMetric.Service_Resource__c = ar.ServiceResourceId;
        newUtilizationMetric.Service_Territory__c = serviceTerritoryId;

        return newUtilizationMetric;
    }

}