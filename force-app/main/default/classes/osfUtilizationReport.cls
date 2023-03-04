public without sharing class osfUtilizationReport implements Database.Batchable<sObject> {
    DateTime startDateTime;
    Date startDate;
    Integer MondayHours, TuesdayHours, WednesdayHours, ThursdayHours, FridayHours, SaturdayHours, SundayHours;
    List<Utilization_Metric__c> records = new List<Utilization_Metric__c>();
    List<Utilization_Metric__c> oldRecords = new List<Utilization_Metric__c>();
    List<AssignedResource> assResourceList = new List<AssignedResource>();
    Date ninetyDaysAgo = Date.today().addDays(-90);
    Date ninetyDaysFuture =  Date.today().addDays(90);



    //query Assigned Resource
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('***Batch Started***');
        String exampleDate = this.ninetyDaysAgo.format();
        System.debug('today - 90 is ' +  exampleDate);
        String queryString = 'SELECT ID, Date_Value_EffectiveStartDate__c,Add_365_Days_More_to_U_M_Records__c, ServiceResource.Name, ServiceTerritory.Name, Created_Utilization_Metric__c, Date_Value_EffectiveEndDate__c, EffectiveEndDate, ServiceTerritoryId, ServiceResourceId, ServiceTerritory.OperatingHoursId FROM ServiceTerritoryMember WHERE (ServiceResource.IsActive = TRUE AND ServiceResource.RelatedRecord.IsActive = TRUE AND ServiceResource.ResourceType = \'T\')';
        return Database.getQueryLocator(queryString);
    }

    //Perform actions to create or update the existing U.M. records based on Service Resource and Service Territory
    public void execute(Database.BatchableContext BC, List<ServiceTerritoryMember> scope){
        System.debug('***Batch Excecuted***');
        System.debug('the scope is ' + scope.size());
        //call your batch method here, or just write your logic instead.
        try {
            for(ServiceTerritoryMember stm: scope){
                findUtilizationMetricRecord(stm);
            }
            insert this.records;
            delete this.oldRecords;
            
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
            findUtilizationMetricRecord(stm);
    }

    //an if/else that locates an existing U.M. record based on Date, Serv. Territory Id, and Service Resource Id
    private  void findUtilizationMetricRecord (ServiceTerritoryMember stm){
        List<Utilization_Metric__c>  umRecords = new List<Utilization_Metric__c>();

            umRecords = [SELECT ID, Total_Scheduled__c,Total_NAs__c,Total_Available_Hours__c, Total_Available_Minutes__c, Total_Travel__c, Service_Resource__c, Service_Resource_Name__c, Report_Start_Date__c, Service_Territory__c , Service_Territory_Name__c FROM
            Utilization_Metric__c WHERE Service_Resource__c =: stm.ServiceResourceId AND Service_Territory__c =: stm.ServiceTerritoryID];
            

            for (Utilization_Metric__c oldUM: umRecords){
                System.debug('the date is ' + oldUm.Report_Start_Date__c);
                if (oldUM.Report_Start_Date__c < this.ninetyDaysAgo){
                    System.debug('found it');
                    this.oldRecords.add(oldUm);
                }
            }

        if (umRecords.size() == 0){ //no U.M. record was ever made in the past so make one
            createUtilizationMetricRecordSet(stm, ninetyDaysAgo,ninetyDaysFuture);// aka create a set of Utilization Metric records as that means its probably a net new STM record.
        }else{
            createUtilizationMetricRecord(stm, ninetyDaysFuture);
            
        }   
    }
    //if no U.M. record was found then create new record with Start Date, Service Resource Id/  Name, and Service Territory Id/Name, and the minutes of the times
    private  void createUtilizationMetricRecordSet(ServiceTerritoryMember stm, Date startDay, Date endDay){
        List<Utilization_Metric__c> umRecords = new List<Utilization_Metric__c>();
        Integer numberOfDays = (startDay.daysBetween(endDay));
        for (Integer i = 0; i < numberOfDays; i++){
            Utilization_Metric__c newUtilizationMetric = new Utilization_Metric__c();
            newUtilizationMetric.Report_Start_Date__c = startDay + i;
            newUtilizationMetric.Service_Resource__c = stm.ServiceResourceId;
            newUtilizationMetric.Service_Territory__c =  stm.ServiceTerritoryID;
            newUtilizationMetric.Total_Scheduled__c = 0;
            newUtilizationMetric.Total_NAs__c = 0;
            newUtilizationMetric.Total_Travel__c = 0;
            newUtilizationMetric.Service_Territory_Name__c = stm.ServiceTerritory.Name;
            newUtilizationMetric.Service_Resource_Name__c = stm.ServiceResource.Name;
            Integer hours  =  putOperatingHours(startDay + i, stm);
            newUtilizationMetric.Total_Available_Hours__c = hours;
            newUtilizationMetric.Total_Available_Minutes__c = hours * 60;

            this.records.add(newUtilizationMetric);
            }
    }

    private  void createUtilizationMetricRecord(ServiceTerritoryMember stm, Date startDay){
        List<Utilization_Metric__c> umRecords = new List<Utilization_Metric__c>();
            Utilization_Metric__c newUtilizationMetric = new Utilization_Metric__c();
            newUtilizationMetric.Report_Start_Date__c = startDay;
            newUtilizationMetric.Service_Resource__c = stm.ServiceResourceId;
            newUtilizationMetric.Service_Territory__c =  stm.ServiceTerritoryID;
            newUtilizationMetric.Total_Scheduled__c = 0;
            newUtilizationMetric.Total_NAs__c = 0;
            newUtilizationMetric.Total_Travel__c = 0;
            newUtilizationMetric.Service_Territory_Name__c = stm.ServiceTerritory.Name;
            newUtilizationMetric.Service_Resource_Name__c = stm.ServiceResource.Name;
            Integer hours  =  putOperatingHours(startDay, stm);
            newUtilizationMetric.Total_Available_Hours__c = hours;
            newUtilizationMetric.Total_Available_Minutes__c = hours * 60;

            this.records.add(newUtilizationMetric);
    }
    

   
    //a method to run calculations to find the Operating Hours associated with U.M. Service Territory, Day Of Week, and then to get the total time (in minutes) associated with 
    //those factors. Placing them onto the U.M. record.
    private Integer putOperatingHours (Date startDate, ServiceTerritoryMember stm){
        String dayOfWeek = getDayOfWeek(getDayOfWeekInt(startDate));
        Id operatingHoursId = stm.ServiceTerritory.OperatingHoursId;
        if (operatingHoursId != null){
            Integer totalHours = getTimeSlots(dayOfWeek, operatingHoursId);
            Integer totalMins = totalHours * 60;
            return totalHours;
        }else{
            return 8; // if no operating id is associated with the Service Territory, just make it a standard 8 hours of work so that the calculation doesn't break
        }
    }


    //a way to find the day of week given a datetime
    private Integer getDayOfWeekInt(Date startDate){
        DateTime dt = (DateTime) startDate;
        return Integer.valueOf((dt.format('u')));
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
    private Integer getTimeSlots(String day, Id operationHoursId){
        switch on day{
            when 'Monday'{
                if(this.MondayHours != null){
                    return this.MondayHours;
                }
                else{
                    this.MondayHours = getTotalOperatingHours([SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day]);
                    return this.MondayHours;
                }
            }
            when 'Tuesday'{
                if(this.TuesdayHours != null){
                    return this.TuesdayHours;
                }
                else{
                    this.TuesdayHours = getTotalOperatingHours([SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day]);
                    return this.TuesdayHours;
                }            
            }
            when 'Wednesday' {
                if(this.WednesdayHours != null){
                    return this.WednesdayHours;
                }
                else{
                    this.WednesdayHours = getTotalOperatingHours([SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day]);
                    return this.WednesdayHours;
                }
            }
            when 'Thursday'{
                if(this.ThursdayHours != null){
                    return this.ThursdayHours;
                }
                else{
                    this.ThursdayHours = getTotalOperatingHours([SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day]);
                    return this.ThursdayHours;
                }
            }
            when 'Friday' {
                if(this.FridayHours != null){
                    return this.FridayHours;
                }
                else{
                    this.FridayHours = getTotalOperatingHours([SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day]);
                    return this.FridayHours;
                    
                }            
            }
            when 'Saturday'{
                if(this.SaturdayHours != null){
                    return this.SaturdayHours;
                }
                else{
                    this.SaturdayHours = getTotalOperatingHours([SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day]);
                    return this.SaturdayHours;
                }            
            }
            when 'Sunday'  {
                if(this.SundayHours != null){
                    return this.SundayHours;
                }
                else{
                    this.SundayHours = getTotalOperatingHours([SELECT ID, StartTime, EndTime, Total_Hours__c FROM TimeSlot WHERE OperatingHoursId =: operationHoursId AND DayOfWeek =: day]);
                    return this.SundayHours;
                }            
            }
            when else {
                return 1;
                }
    }
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