@isTest
public class MultiSelectFlowValuesTestClass {
    @isTest
    static void MultiSelectFlowValuesTest(){
        List<string> tempLst = new list<string>();
        tempLst.add('Test');
        tempLst.add('Salesforce');
        MultiselectFlowvalues.CheckValues(tempLst);        
    }
    @isTest
    static void MultiSelectFlowValuesTestNull(){
        List<string> tempLst = new list<string>();
        MultiselectFlowvalues.CheckValues(tempLst);        
    }
}