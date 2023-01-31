global class RelateInvoicesToOpportunitiesBatch implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {
    // instance member to retain state across transactions
    global Integer recordsProcessed = 0;
    // create batchlist 
    global list<String> batchlist = new list<String>();

    global Integer maxSize;

    global List<String> selectedInvoicesIds;

    public RelateInvoicesToOpportunitiesBatch(List<String> selectedInvoicesIds){
        this.selectedInvoicesIds = selectedInvoicesIds;
    }

    public RelateInvoicesToOpportunitiesBatch(Integer maxSize) {
        this.maxSize = maxSize;
    }

    public RelateInvoicesToOpportunitiesBatch(){
    }

    global Iterable<String> start(Database.BatchableContext bc) {
        List<String> ret = new List<String>();
        
        List<Invoice__c> invoices = [SELECT id FROM Invoice__c WHERE Opportunity__c = NULL LIMIT 50000];
        
        if (invoices != null && !invoices.isEmpty()) {
            System.debug('Invoices found = ' + invoices.size() );
        
            List<String> invoicesIds = new List<String>();
                
            // Add all invoices Ids to the invoicesIds List
            for(integer i = 0; i < invoices.size(); i++){
                invoicesIds.add(invoices[i].id);
            }
                
            if(maxSize != null) {
                // return only the number of items received as maxSize from the invoiceIds List 
             	Integer invoiceLimit = invoices.size();
                if (maxSize <= invoices.size()) invoiceLimit = maxSize;
                for(Integer i = 0 ; i < invoiceLimit; i++){
                    ret.add(invoicesIds[i]);
                }
            } else if(selectedInvoicesIds != null){
                // return only the items from the invoiceIds List matching the selectedInvoicesIds received
                for(String invoiceId : invoicesIds){
                    if(selectedInvoicesIds.contains(invoiceId)){
                        ret.add(invoiceId);
                    }
                }
            } else {
                // return the entire invoiceIds List
                ret.addAll(invoicesIds);
            }
        }
        
        System.debug('Number of Invoices not related to Opportunities = ' + ret.size()); 
        return ret;
    }

    global void execute(Database.BatchableContext bc, List<String> invoicesList){
        // process each batch of records
        for(String listItem : invoicesList){
            InvoicesToOpportunities i2o = new InvoicesToOpportunities();
            i2o.relate(listItem);
            // increment the instance member counter
            recordsProcessed = recordsProcessed + 1;
        }
    }    

    global void finish(Database.BatchableContext bc){
        System.debug(recordsProcessed + ' records processed!');
        AsyncApexJob job = [SELECT Id, 
            Status, 
            NumberOfErrors, 
            JobItemsProcessed,
            TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()];
        //EmailUtils.sendMessage(job, recordsProcessed);
    } 
}