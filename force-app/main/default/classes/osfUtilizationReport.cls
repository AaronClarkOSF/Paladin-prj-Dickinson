public without sharing class osfUtilizationReport implements Database.Batchable<sObject> {
    DateTime startDateTime;
    Date startDate;

    //query Assigned Resource
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = System.today();
        String queryString = 'SELECT ID, ServiceAppointmentId, EstimatedTravelTime, ActualTravelTime ServiceAppointment.AppointmentNumber,ServiceAppointment.Schedule_Start_Day__c, ServiceAppointment.DurationType, ServiceAppointment.Duration, ServiceAppointment.ServiceTerritoryID, ServiceResource.Name FROM AssignedResource  WHERE CREATEDDATE >: Yesterday ';
        return Database.getQueryLocator(queryString);
    }

    //Perform actions to create or update the existing U.M. records based on Service Resource and Service Territory
    public void execute(Database.BatchableContext BC, List<AssignedResource> scope){
        System.debug('***Batch Started***');
        //call your batch method here, or just write your logic instead.
        List<Utilization_Metric__c> records = new List<Utilization_Metric__c>();
        for(AssignedResource ar: scope){
                Utilization_Metric__c record = performBatchActions(ar);
                records.add(record);
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
        record = putServiceAppointmentDurations(record, ar);
        record = putResourceAbsences(record, ar);
        record = putTravelTime(record, ar); //using EstimatedTravelTime. In Dev environment no ActualTravelTime is used. Also, to use ActualTravelTime means that we are back updating which isn't true.
        record = putOperatingHours(record, ar);
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

    //if no U.M. record was found then create new record with Start Date, Service Resource Id, and Service Territory Id
    private  Utilization_Metric__c createUtilizationMetricRecord(AssignedResource ar, Id serviceTerritoryId){
        Utilization_Metric__c newUtilizationMetric = new Utilization_Metric__c();
        newUtilizationMetric.Report_Start_Date__c = this.startDate;
        newUtilizationMetric.Service_Resource__c = ar.ServiceResourceId;
        newUtilizationMetric.Service_Territory__c = serviceTerritoryId;

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
        Integer totalMinutesofAbsence;
        for (ResourceAbsence ra: resourceAbsences){
            totalMinutesofAbsence += (Integer) resourceAbsences[0].FSL__Duration_In_Minutes__c;
        }
        return totalMinutesofAbsence;
    }

    //a method for putting the Travel Time onto U.M.
    private Utilization_Metric__c putTravelTime (Utilization_Metric__c record, AssignedResource ar){
        record.Total_Travel__c = ar.EstimatedTravelTime;
        return record;
    }

    //a method to run calculations to find the Operating Hours associated with U.M. Service Territory, Day Of Week, and then to get the total time (in minutes) associated with 
    //those factors. Placing them onto the U.M. record.
    private Utilization_Metric__c putOperatingHours (Utilization_Metric__c record, AssignedResource ar){
        String dayOfWeek = getDayOfWeek(getDayOfWeekInt());
        Id operatingHoursId = getOperatingHoursId(record.Service_Territory__c);
        if (operatingHoursId != null){
            record.Total_Available_Hours__c = getTotalOperatingHours(getTimeSlots(dayOfWeek, operatingHoursId));
        }

        return record;
    }

    //needed to understand what timeslots are associated, indirectly, to the Service Territory given the assigned OperatingHoursId.
    private Id getOperatingHoursId(Id serviceTerritoryId){
        ServiceTerritory st = [SELECT Id, OperatingHoursId FROM ServiceTerritory WHERE Id =: serviceTerritoryId];
        return st.OperatingHoursId;
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
        Integer totalOperatingHours;
        for (TimeSlot ts: timeSlots){
            totalOperatingHours += (Integer)ts.Total_Hours__c * 60; 
        }
        return totalOperatingHours;
    }


}