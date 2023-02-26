public without sharing class osfUtilizationReport implements Database.Batchable<sObject> {
    DateTime startDateTime;
    Date startDate;
    List<Utilization_Metric__c> records = new List<Utilization_Metric__c>();


    //query Assigned Resource
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('***Batch Started***');
        String queryString = 'SELECT ID, Date_Value_EffectiveStartDate__c, Date_Value_EffectiveEndDate__c, EffectiveEndDate, ServiceTerritoryId, ServiceResourceId, ServiceTerritory.OperatingHoursId FROM ServiceTerritoryMember WHERE (Is_the_StartDate_a_Year_Or_Older__c = True AND Effectiveenddate = null) OR LastModifiedDate = TODAY';
        return Database.getQueryLocator(queryString);
    }

    //Perform actions to create or update the existing U.M. records based on Service Resource and Service Territory
    public void execute(Database.BatchableContext BC, List<AssignedResource> scope){
        System.debug('***Batch Excecuted***');
        System.debug('the scope is ' + scope.size());
        //call your batch method here, or just write your logic instead.
        try {
            for(ServiceTerritoryMember stm: scope){
                    this.records = performBatchActions(stm);
                }
            insert this.records;
            
        }catch (Exception e) {
            System.debug('BATCH ERROR ===> ' + e);
        }
    }

    
    //send an email with completion information
    public void finish(Database.BatchableContext BC){
        System.debug('** BATCH FINISHED** ');
    }


    //"Parent" method that executes the order of data compilation
    public void performBatchActions( ServiceTerritoryMember stm){
         this.records.add(findUtilizationMetricRecord(stm));
    }

    //an if/else that locates an existing U.M. record based on Date, Serv. Territory Id, and Service Resource Id
    private  List<Utilization_Metric__c> findUtilizationMetricRecord (ServiceTerritoryMember stm){
        List<Utilization_Metric__c>  umRecords = new List<Utilization_Metric__c>();
            umRecords = [SELECT ID, Total_Scheduled__c,Total_NAs__c,Total_Available_Hours__c, Total_Available_Minutes__c, Total_Travel__c, Service_Resource__c, Service_Resource_Name__c, Report_Start_Date__c, Service_Territory__c , Service_Territory_Name__c FROM
            Utilization_Metric__c WHERE Service_Resource__c =: stm.ServiceResourceId AND Service_Territory__c =: stm.ServiceTerritoryID AND  Report_Start_Date__c >=: TODAY AND 
                Report_Start_Date__c <=: Date_Value_EffectiveEndDate__c];
            //if you find UM that are greater than today, but less than the Effective end date, delete them and then recreate them.
        if (umRecords.size() == 0){ //no U.M. record was ever made in the past so make one
            return createUtilizationMetricRecords(stm, stm.Date_Value_EffectiveStartDate__c, stm.Date_Value_EffectiveEndDate__c);// aka create a set of Utilization Metric records as that means its probably a net new STM record.
        }else{
            delete umRecords;
            return createUtilizationMetricRecord(stm, Sytem.Today(), stm.Date_Value_EffectiveEndDate__c);
            
        }   
    }

    //if no U.M. record was found then create new record with Start Date, Service Resource Id/  Name, and Service Territory Id/Name, and the minutes of the times
    private  List<Utilization_Metric__c> createUtilizationMetricRecords(ServiceTerritoryMember stm, Date startDay, Date endDay){
        List<Utilization_Metric__c> umRecords = new List<Utilization_Metric__c>();
        Integer numberOfDays = (startDay.daysBetween(endDay));
        for (int i = 0; i < numberOfDays; i++){
            Utilization_Metric__c newUtilizationMetric = new Utilization_Metric__c();
            newUtilizationMetric.Report_Start_Date__c = startDay + i;
            newUtilizationMetric.Service_Resource__c = stm.ServiceResourceId;
            newUtilizationMetric.Service_Territory__c =  stm.ServiceTerritoryID;
            newUtilizationMetric.Total_Scheduled__c = 0;
            newUtilizationMetric.Total_NAs__c = 0;
            newUtilizationMetric.Total_Travel__c = 0;
            newUtilizationMetric.Service_Territory_Name__c = stm.ServiceTerritory.Name;
            newUtilizationMetric.Service_Resource_Name__c = stm.ServiceResource.Name;
            newUtilizationMetric.Test_Assigned_Resource__c = stm.ServiceResourceId;
            newUtilizationMetric = putOperatingHours(newUtilizationMetric, stm);
            umRecords.add(newUtilizationMetric);
            }
        return umRecords;
    }
    

   
    //a method to run calculations to find the Operating Hours associated with U.M. Service Territory, Day Of Week, and then to get the total time (in minutes) associated with 
    //those factors. Placing them onto the U.M. record.
    private Utilization_Metric__c putOperatingHours (Utilication_Metric__c record, ServiceTerritoryMember stm){
        String dayOfWeek = getDayOfWeek(getDayOfWeekInt());
        Id operatingHoursId = getOperatingHoursId(stm.Service_Territory__c);
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