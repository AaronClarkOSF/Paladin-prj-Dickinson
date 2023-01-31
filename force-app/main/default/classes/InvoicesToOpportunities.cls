public class InvoicesToOpportunities {
    
    public void relate (String invoiceId){
        System.debug('Invoice Id --> ' + invoiceId);
        
        Invoice__c invoice = [Select Id, BillingCustomerID_Lookup__c, InvoiceDate__c  FROM Invoice__c WHERE Id = :invoiceId];
        
        if (invoice != null && invoice.BillingCustomerID_Lookup__c != null){
            List<Opportunity> opportunities = [SELECT Id, CloseDate FROM Opportunity WHERE AccountId = :invoice.BillingCustomerID_Lookup__c ORDER BY CloseDate DESC];
            if (opportunities != null && !opportunities.isEmpty()){
                invoice.Opportunity__c = opportunities[0].id;
                for (Opportunity opp : opportunities){
                    invoice.Opportunity__c = opp.Id;
                    if (opp.CloseDate < invoice.InvoiceDate__c){
                        break;
                    }
                }
                System.debug('Invoice ' + invoice.Id + ' will be related to the opportunity ' + invoice.Opportunity__c);
                update invoice;
            }else System.debug('No Opportunities found  related to the account ' + invoice.BillingCustomerID_Lookup__c);
        }else System.debug('Invoice with the record Id ' + invoiceId + ' is not related to an Account');
    }

}