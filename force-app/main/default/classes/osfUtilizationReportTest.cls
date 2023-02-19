@isTest
public with sharing class osfUtilizationReportTest {
    @testSetup
    public static void assResourceSetup(){
        Account acc = new Account(Name = 'Test AssResource');
        insert acc;
        OperatingHours oH = new OperatingHours(name = '1000 - 24/7test' , TimeZone = 'Pacific/Kiritimati', GMT_Offset__c = -5);
        insert oH;
        ServiceTerritory servTerr = new ServiceTerritory(Name ='Test Serv', operatingHoursId = oH.Id, IsActive = true);
        insert servTerr;
        ServiceResource servRes = new ServiceResource(Name='Test', IsActive = true , ResourceType = 'T', RelatedRecordId = UserInfo.getUserId());
        insert servRes;
        ServiceTerritoryMember servTM = new ServiceTerritoryMember(ServiceResourceId = servRes.Id, ServiceTerritoryId = servTerr.Id, TerritoryType = 'P', EffectiveStartDate = System.today()-5);
        insert servTM;
        WorkType wT = new WorkType(Name='Test WT', EstimatedDuration = 1, DurationType = 'Hours');
        insert wT;
        WorkOrder wO = new WorkOrder(WorkTypeId = wT.Id, AccountId = acc.Id, serviceTerritoryId = servTerr.Id);
        insert wO;
        ServiceAppointment servApp = new ServiceAppointment(Status = 'Scheduled', ParentRecordId = wO.Id, DueDate = System.today()+2, Subject = 'test',WorkTypeId = wT.Id, Duration = 1, DurationType = 'Hours', SchedStartTime = System.today() , SchedEndTime = System.today()+1 );
        insert servApp;
        AssignedResource ar = new AssignedResource (ServiceAppointmentId = servApp.Id, ServiceResourceId = servRes.Id);
        insert ar;
        ResourceAbsence ra1= new ResourceAbsence (Start = System.now(), End =System.now().addHours(1), resourceId = servRes.Id );
        insert ra1;
        ResourceAbsence ra2= new ResourceAbsence (Start = System.now().addHours(2), End =System.now().addHours(3), resourceId = servRes.Id );
        insert ra2;
    }
    
    @IsTest(SeeAllData=false)
    public static void scheduleJobTest(){
        Test.startTest();
        String CRON_EXP = '0 0 0 3 9 ? 2025';
        String jobId = System.schedule('osfUtilizationReportTest', CRON_EXP, new osfUtilizationMetricJob());
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId]; 
        System.assertEquals(0, ct.TimesTriggered); 
        System.assertEquals('2025-09-03 00:00:00', String.valueOf(ct.NextFireTime));   
        Test.stopTest();        
    }


    // public static void batchClassTest(){
    //     Test.startTest();
    //     Id batchJobId = Database.executeBatch(new osfUtilizationReport(), 30);
    //     Test.stopTest();
    // }
}
