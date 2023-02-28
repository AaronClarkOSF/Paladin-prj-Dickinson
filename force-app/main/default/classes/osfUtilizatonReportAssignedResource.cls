public without sharing class osfUtilizatonReportAssignedResource implements Database.Batchable<sObject> {
    DateTime startDateTime;
    Date startDate;
    List<Utilization_Metric__c> records = new List<Utilization_Metric__c>();


    //query Assigned Resource
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('***Batch Started***');
        String queryString = 'SELECT ID, ServiceAppointmentId, lastmodifiedby.name, createddate, Schedule_Start_Date__c, lastmodifieddate, ServiceAppointment.SchedStartTime, EstimatedTravelTime, ServiceResourceId, ActualTravelTime, ServiceAppointment.AppointmentNumber,ServiceAppointment.Schedule_Start_Day__c, ServiceAppointment.DurationType, ServiceAppointment.Duration, ServiceAppointment.ServiceTerritoryID, ServiceAppointment.ServiceTerritory.Name, ServiceResource.Name FROM AssignedResource  WHERE Created_Utilization_Metric__c = false AND ServiceResource.IsActive = TRUE AND ServiceResource.RelatedRecord.IsActive = TRUE AND ServiceResource.ResourceType = \'T\' ' + (Test.isRunningTest()?' LIMIT 5':'');
        return Database.getQueryLocator(queryString);
    }

    //Perform actions to create or update the existing U.M. records based on Service Resource and Service Territory
    public void execute(Database.BatchableContext BC, List<AssignedResource> scope){
        System.debug('***Batch Excecuted***');
        System.debug('the scope is ' + scope.size());
        //call your batch method here, or just write your logic instead.
        try {
            for(AssignedResource ar: scope){
                    Utilization_Metric__c record = new Utilization_Metric__c();
                    record = performBatchActions(ar);
                    this.records.add(record);
                    ar.Created_Utilization_Metric__c = true; // after you finish creating/updating the U.M. record, mark the "parent" AssignedResource checkbox so it doesn't get reupdated incorrectly
                    // System.debug('the ar scope id of this is ' + ar.id);
                    // System.debug('the record records id of this is ' + record.id);
                }
            update scope;
            upsert this.records;
            
        }catch (Exception e) {
            System.debug('BATCH ERROR ===> ' + e);
        }
    }

    
    //send an email with completion information
    public void finish(Database.BatchableContext BC){
        System.debug('** BATCH FINISHED** ');
    }


    //"Parent" method that executes the order of data compilation
    public Utilization_Metric__c performBatchActions( AssignedResource ar){
        this.startDateTime = ar.ServiceAppointment.SchedStartTime;
        this.startDate = ar.Schedule_Start_Date__c;

        Utilization_Metric__c record = findUtilizationMetricRecord(ar);
        record = putServiceAppointmentDurations(record, ar);
        //record = putResourceAbsences(record, ar);
        record = putTravelTime(record, ar); //using EstimatedTravelTime. In Dev environment no ActualTravelTime is used. Also, to use ActualTravelTime means that we are back updating which isn't true.
        record = putOperatingHours(record, ar);
        return record;
        //to see the result see Utilization Metric Record's Utilization__c value
    }

    //an if/else that locates an existing U.M. record based on Date, Serv. Territory Id, and Service Resource Id
    private  Utilization_Metric__c findUtilizationMetricRecord (AssignedResource ar){
        Id serviceTerritoryId =  ar.ServiceAppointment.ServiceTerritoryID;
        List<Utilization_Metric__c> umRecords = new List<Utilization_Metric__c>();
        umRecords = [SELECT ID, Total_Scheduled__c,Total_NAs__c,Total_Available_Hours__c, Total_Available_Minutes__c, Total_Travel__c, Service_Resource__c, Service_Resource_Name__c, Report_Start_Date__c, Service_Territory__c , Service_Territory_Name__c FROM Utilization_Metric__c WHERE Service_Resource__c =: ar.ServiceResourceId AND  Report_Start_Date__c =: this.startDate AND Service_Territory__c =: serviceTerritoryId];
        if (umRecords.size() == 0){ //no U.M. record was ever made in the past so make one
            return createUtilizationMetricRecord(ar);
        }else{
            /* for (Integer i = 0; i <this.records.size(); i++){ // one U.M. was already made during this batch (either made or found with umRecords[0] see below) and we should be re-reupdating it
                if (this.records[i].Id == umRecords[0].Id){
                    Utilization_Metric__c recordAlreadyMade = this.records[i];
                    this.records.remove(i);
                    return recordAlreadyMade;
                }
            }
        }*/
            System.debug('the record st that we found was  ' + records[0].Service_Territory__c);
            return umRecords[0]; // no U.M. record was made in this batch  but one had been made previously
        }   
    }

    //if no U.M. record was found then create new record with Start Date, Service Resource Id/  Name, and Service Territory Id/Name, and the minutes of the times
    private  Utilization_Metric__c createUtilizationMetricRecord(AssignedResource ar){
        Utilization_Metric__c newUtilizationMetric = new Utilization_Metric__c();
        newUtilizationMetric.Report_Start_Date__c = this.startDate;
        newUtilizationMetric.Service_Resource__c = ar.ServiceResourceId;
        newUtilizationMetric.Service_Territory__c =  ar.ServiceAppointment.ServiceTerritoryID;
        newUtilizationMetric.Total_Scheduled__c = 0;
        newUtilizationMetric.Total_NAs__c = 0;
        newUtilizationMetric.Total_Travel__c = 0;
        newUtilizationMetric.Total_Available_Hours__c = 0;
        newUtilizationMetric.Total_Available_Minutes__c = 0;
        newUtilizationMetric.Service_Territory_Name__c = ar.ServiceAppointment.ServiceTerritory.Name;
        newUtilizationMetric.Service_Resource_Name__c = ar.ServiceResource.Name;
        newUtilizationMetric.Test_Assigned_Resource__c = ar.Id;
        return newUtilizationMetric;
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

    //a method for putting all the Resource Absences of a Service Resource onto the U.M. record
    private Utilization_Metric__c putResourceAbsences (Utilization_Metric__c record, AssignedResource ar){
        List<ResourceAbsence> resourceAbsences = [SELECT Id, Start, End, FSL__Duration_In_Minutes__c FROM ResourceAbsence WHERE resourceId =: ar.ServiceResourceId AND Start_Day__c =: this.startDate];
        Integer totalMinutesofAbsence;
        if (resourceAbsences != null && resourceAbsences.size() > 1){
            totalMinutesofAbsence = minutesOfAbsence(resourceAbsences);
        }else if(resourceAbsences.size() == 1){
            totalMinutesofAbsence = (Integer) resourceAbsences[0].FSL__Duration_In_Minutes__c;
        }
        else{
            totalMinutesofAbsence = 0;
        }
        record.Total_NAs__c = totalMinutesofAbsence;
        return record;
    }

    //helper method of putResourceAbsences. It is if there are many Resource Absences on the same day.
    private Integer minutesOfAbsence(List<ResourceAbsence> resourceAbsences){
        Integer totalMinutesofAbsence = 0;
        for (ResourceAbsence ra: resourceAbsences){
            totalMinutesofAbsence += (Integer) ra.FSL__Duration_In_Minutes__c;
        }
        return totalMinutesofAbsence;
    }

    //a method for putting the Travel Time onto U.M.
    private Utilization_Metric__c putTravelTime (Utilization_Metric__c record, AssignedResource ar){
        record.Total_Travel__c += ar.EstimatedTravelTime;
        return record;
    }

    //a method to run calculations to find the Operating Hours associated with U.M. Service Territory, Day Of Week, and then to get the total time (in minutes) associated with 
    //those factors. Placing them onto the U.M. record.
    private Utilization_Metric__c putOperatingHours (Utilization_Metric__c record, AssignedResource ar){
        String dayOfWeek = getDayOfWeek(getDayOfWeekInt());
        Id operatingHoursId = getOperatingHoursId(record.Service_Territory__c);
        if (operatingHoursId != null){
            System.debug('the operating hours id is ' + operatingHoursId);
            List<TimeSlot> timeSlots = getTimeSlots(dayOfWeek, operatingHoursId);
            Integer totalHours = getTotalOperatingHours(timeSlots);
            Integer totalMins = totalHours * 60;
            record.Total_Available_Hours__c =  totalHours;
            if(totalMins != 0){ // there is still a chance, after testing, that Operating Hours could retun 0. So we are doing another check and giving the U.M. Record a base of 8 hours (480 mins).
                record.Total_Available_Minutes__c = totalMins;
            }else{
                record.Total_Available_Minutes__c = 480;
            }

        }else{
            record.Total_Available_Hours__c = 8; // if no operating id is associated with the Service Territory, just make it a standard 8 hours of work so that the calculation doesn't break
            record.Total_Available_Minutes__c = 480;
        }
        return record;
    }

    //needed to understand what timeslots are associated, indirectly, to the Service Territory given the assigned OperatingHoursId.
    private Id getOperatingHoursId(Id serviceTerritoryId){
        if (serviceTerritoryId != null){
            ServiceTerritory st = [SELECT Id, OperatingHoursId FROM ServiceTerritory WHERE Id =: serviceTerritoryId];
            return st.OperatingHoursId;
        }else{
            return null;
        }
    }

    //a way to find the day of week given a datetime
    private Integer getDayOfWeekInt(){
        return Integer.valueOf((this.startDateTime.format('u')));
    }

    //a switch statement to return day of week.
    private String getDayOfWeek(Integer dayInt){
        switch on dayInt {
            when 1 {
                return 'Monday';
            }
            when 2 {
                return 'Tuesday';
            }
            when 3 {
                return 'Wednesday';
            }
            when 4 {
                return 'Thursday';
            }
            when 5 {
                return 'Friday';
            }
            when 6 {
                return 'Saturday';
            }
            when 7 {
                return 'Sunday';
            }
            when else {
                return 'Monday';
            }
            }
    }

    //returns the list of time slots given the operatinghoursId and the day of week.
    private List<TimeSlot> getTimeSlots(String day, Id operationHoursId){
        List<TimeSlot> timeSlots = [SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day];
        return timeSlots;
    }

    //utilizes a custom field found on TimeSlots and multiplying the found hours by 60 to return minutes of operation given the timeslots
    private Integer getTotalOperatingHours(List<TimeSlot> timeSlots){
        Decimal totalOperatingHours = 0;
        for (TimeSlot ts: timeSlots){
            totalOperatingHours += ts.Total_Hours__c; 
        }
        return (Integer) totalOperatingHours;
    }

}