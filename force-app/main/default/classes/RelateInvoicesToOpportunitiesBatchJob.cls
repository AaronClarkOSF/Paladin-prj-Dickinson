public class RelateInvoicesToOpportunitiesBatchJob implements Schedulable{
    private String id;

    public RelateInvoicesToOpportunitiesBatchJob() {
    }

    /*public RelateInvoicesToOpportunitiesBatchJob(String id) {
        this.id = id;
    }*/
    public void execute(SchedulableContext ctx) {
        RelateInvoicesToOpportunitiesBatch myBatchObject = new RelateInvoicesToOpportunitiesBatch(); 
        //if(this.id != null) myBatchObject =  new RelateInvoicesToOpportunitiesBatch(new String[]{this.id});
        Id batchId = Database.executeBatch(myBatchObject,1);
    }
}