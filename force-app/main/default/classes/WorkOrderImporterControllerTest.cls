@isTest
private with sharing class WorkOrderImporterControllerTest {
    public static testMethod void TestWorkOrderImporterController() {
        Id jobId = WorkOrderImporterController.handleUpload('test.csv', EncodingUtil.base64Encode(Blob.valueOf('KarmakID,Territory,WorkType,Asset  (o),Subject,Description,Street (o),City (o),State (o),ZIP (o)\n138220,2800 Greater Indianapolis,HD Power 2.0,PF12345678,row1,long,4709 W 96th Street,Indianapolis,IN,46268\n138220,2800 Greater Indianapolis,HD Power 2.0,PF1234,row2,long,4709 W 96th Street,Indianapolis,IN,46268')));
        WorkOrderImporterController.isDone(jobId);
    }
}