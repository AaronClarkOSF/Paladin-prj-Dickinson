 public without sharing class osfUtilizationReportResourceAbsence implements Database.Batchable<sObject> {
        DateTime startDateTime;
        Date startDate;
        List<Utilization_Metric__c> records = new List<Utilization_Metric__c>();
    
    
        //query Resource Absence
        public Database.QueryLocator start(Database.BatchableContext bc) {
            System.debug('***Batch Started***');
            STRING queryString = 'SELECT Id, Start,Start_Day__c, End, FSL__Duration_In_Minutes__c,ResourceId FROM ResourceAbsence WHERE Start_Day__c >= LAST_90_DAYS AND Start_Day__c <= NEXT_90_DAYS AND Created_Utilization_Metric__c = false AND Resource.IsActive = TRUE AND Resource.RelatedRecord.IsActive = TRUE AND Resource.ResourceType = \'T\' ' + (Test.isRunningTest()?' LIMIT 5':'');
            return Database.getQueryLocator(queryString);
        }
    
        //Perform actions to create or update the existing U.M. records based on Service Resource and Service Territory
        public void execute(Database.BatchableContext BC, List<ResourceAbsence> scope){
            System.debug('***Batch Excecuted***');
            System.debug('the scope is ' + scope.size());
            //call your batch method here, or just write your logic instead.
            try {
                for(ResourceAbsence ra: scope){
                        List<Utilization_Metric__c> recordsFromRA = new List<Utilization_Metric__c>();
                        recordsFromRA = performBatchActions(ra);
                        this.records.addall(recordsFromRA);
                        ra.Created_Utilization_Metric__c = true; // after you finish creating/updating the U.M. record, mark the "parent" ResourceAbsence checkbox so it doesn't get reupdated incorrectly
                    }
                Set<Utilization_Metric__c> myObjectSet = new Set<Utilization_Metric__c>(this.records);
                List<Utilization_Metric__c> myObjectList = new List<Utilization_Metric__c>(myObjectSet);
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
        public List<Utilization_Metric__c> performBatchActions( ResourceAbsence ra){
            this.startDateTime = ra.start;
            this.startDate = ra.Start_Day__c;
    
            List<Utilization_Metric__c> records = findUtilizationMetricRecord(ra);
            System.debug('the first round of records found was ' + records);

            records = putResourceAbsences(records, ra);
            records = putOperatingHours(records, ra);

            return records;
            //to see the result see Utilization Metric Record's Utilization__c value
        }
    
        //an if/else that locates an existing U.M. record based on Date, Serv. Territory Id, and Service Resource Id
        private  List<Utilization_Metric__c> findUtilizationMetricRecord (ResourceAbsence ra){
            List<Utilization_Metric__c> umRecordsFound = new List<Utilization_Metric__c>();
            List<Utilization_Metric__c> umRecords = new List<Utilization_Metric__c>();
            umRecords = [SELECT ID, Total_Scheduled__c,Total_NAs__c,Total_Available_Hours__c, Total_Available_Minutes__c, Total_Travel__c, Service_Resource__c, Service_Resource_Name__c, Report_Start_Date__c, Service_Territory__c , Service_Territory_Name__c FROM Utilization_Metric__c WHERE Service_Resource__c =: ra.ResourceId AND  Report_Start_Date__c =: this.startDate];
            if (umRecords.size() == 0 || umRecords == null){ //no U.M. record was ever made in the past so make one
                return createUtilizationMetricRecords(ra);
            }else{
                System.debug('the umRecords were ' + umRecords);
                for(Utilization_Metric__c umRecord : umRecords){
                    for(Utilization_Metric__c umExist : this.records ){
                        if (umRecord.Id == umExist.Id){
                            umRecordsFound.add(umExist);
                        }
                    }
                    umrecordsFound.add(umRecord);
                }
                System.debug('the first round of umRecordsFound found was ' + umRecordsFound);

                return umRecordsFound;
            }   
        }
        private List<ServiceTerritory> getResourceServiceTerritories(ResourceAbsence ra){
            List<ServiceTerritoryMember> stmList = [Select Id, ServiceTerritoryID FROM ServiceTerritoryMember WHERE ServiceResourceId =: ra.ResourceId];
            List<ServiceTerritory> stList = new List<ServiceTerritory>();
            List<Id> returnList = new List<Id>();
            for (ServiceTerritoryMember stm: stmList){
                returnList.add(stm.ServiceTerritoryID);
            }
            for (Id stID : returnList){
                ServiceTerritory st = [SELECT Id, Name FROM ServiceTerritory WHERE Id =: stId];
                stList.add(st);
            }
            System.debug('the first round of stList found was ' + stList);

            return stList;
        }
        //if no U.M. record was found then create new record with Start Date, Service Resource Id/  Name, and Service Territory Id/Name, and the minutes of the times
        private  List<Utilization_Metric__c> createUtilizationMetricRecords(ResourceAbsence ra){
            List<Utilization_Metric__c> newUMList = new List<Utilization_Metric__c>();
            List<ServiceTerritory> stList = getResourceServiceTerritories(ra);
            for (ServiceTerritory st : stList){
                Utilization_Metric__c newUtilizationMetric = new Utilization_Metric__c();
                newUtilizationMetric.Report_Start_Date__c = this.startDate;
                newUtilizationMetric.Service_Resource__c = ra.ResourceId;
                newUtilizationMetric.Service_Territory__c =  st.Id;
                newUtilizationMetric.Total_Scheduled__c = 0;
                newUtilizationMetric.Total_NAs__c = 0;
                newUtilizationMetric.Total_Travel__c = 0;
                newUtilizationMetric.Total_Available_Hours__c = 0;
                newUtilizationMetric.Total_Available_Minutes__c = 0;
                newUtilizationMetric.Service_Territory_Name__c = st.Name;
                newUtilizationMetric.Service_Resource_Name__c = ra.Resource.Name;
                newUtilizationMetric.Test_Assigned_Resource__c = ra.Id;
            }
            System.debug('the first round of createUt found was ' + newUMList);

            return newUMList;
        }
        
    

    
        //a method for putting all the Resource Absences of a Service Resource onto the U.M. record
        private List<Utilization_Metric__c> putResourceAbsences (List<Utilization_Metric__c> records, ResourceAbsence ra){
            List<ResourceAbsence> resourceAbsences = [SELECT Id, Start, End, FSL__Duration_In_Minutes__c FROM ResourceAbsence WHERE resourceId =: ra.ResourceId AND Start_Day__c =: this.startDate];
            Integer totalMinutesofAbsence = 0;
            if (resourceAbsences != null && resourceAbsences.size() > 1){
                totalMinutesofAbsence += minutesOfAbsence(resourceAbsences);
            }else if(resourceAbsences.size() == 1){
                totalMinutesofAbsence += (Integer) resourceAbsences[0].FSL__Duration_In_Minutes__c;
            }
            else{
                totalMinutesofAbsence += 0;
            }
            for (Utilization_Metric__c record: records){
                record.Total_NAs__c += totalMinutesofAbsence;
            }
            System.debug('the first round of records found was ' + records);
            return records;
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
 
    
        //a method to run calculations to find the Operating Hours associated with U.M. Service Territory, Day Of Week, and then to get the total time (in minutes) associated with 
        //those factors. Placing them onto the U.M. record.
        private List<Utilization_Metric__c> putOperatingHours (List<Utilization_Metric__c> records, ResourceAbsence ra){
            String dayOfWeek = getDayOfWeek(getDayOfWeekInt());
            for(Utilization_Metric__c record: records){
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
            }
            
            return records;
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
