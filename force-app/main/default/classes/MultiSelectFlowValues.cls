public class MultiSelectFlowValues {
    @InvocableMethod
    public static List<list<string>> CheckValues(List<string> values) {
        
        if(!(values.isEmpty())){
            string tempStr = values[0];
            List<String> listnew = tempStr.split(';');
            list<list<string>> finalList = new list<list<string>>();
            finalList.add(listnew);
            return finalList;
        }
        else return null;
    }
}