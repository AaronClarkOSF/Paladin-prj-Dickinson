@isTest
public with sharing class RelateInvoices2OppsBatchJobTest {
    // Dummy CRON expression: midnight on May 15.
    // Because this is a test, job executes
    // immediately after Test.stopTest().
    public static String CRON_EXP = '0 0 0 15 5 ? 2025';
    public static List<String> invoiceList = new List<String>();
    @isTest
    static void setup() {
        RecordType recordType = [select Id,Name from RecordType where Name='DFS 3.0'];
        Account a1 = new Account(Name='TestAccount1', RecordTypeId=recordType.Id, Hub__c='4300 - East');
        insert a1;
        
        Account a2 = new Account(Name='TestAccount2', RecordTypeId=recordType.Id, Hub__c='4300 - East');
        insert a2;

        Opportunity testOpportunity1 = new Opportunity(
            StageName = 'Close Won',
            CloseDate = System.today(),
            AccountId = a1.Id,
            Name = 'Test Batch Job Opp1'
        );
        insert testOpportunity1;
        
        Opportunity testOpportunity2 = new Opportunity(
            StageName = 'Close Won',
            CloseDate = System.today().addYears(-1),
            AccountId = a2.Id,
            Name = 'Test Batch Job Opp2'
        );
        insert testOpportunity2;
        
        Invoice__c invoice1 = new Invoice__c(
        	Name = 'Invoice test',
            InvoiceDate__c = System.today(),
            BillingCustomerID_Lookup__c = a1.Id
        );
        insert invoice1;
        
        invoiceList.add(invoice1.Id);

        Test.startTest(); 
        String jobId = System.schedule('ScheduledApexTest', CRON_EXP, new RelateInvoicesToOpportunitiesBatchJob());
        Test.stopTest();
    }
    
     @isTest  static void batchTest1(){           
        Test.startTest();
        RelateInvoicesToOpportunitiesBatch myBatchObject1 = new RelateInvoicesToOpportunitiesBatch(1);
        Id batchId1 = Database.executeBatch(myBatchObject1,1);
        Test.stopTest();   
    }

    @isTest static void batchTest2(){           
        Test.startTest();
        RelateInvoicesToOpportunitiesBatch myBatchObject2 = new RelateInvoicesToOpportunitiesBatch(invoiceList);
        Id batchId2 = Database.executeBatch(myBatchObject2,1);
        Test.stopTest();   
    }
}