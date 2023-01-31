global class osfAccountStateCodeFixBatch implements Database.Batchable < sobject > {

    private Map < String,String > mapStateCode;

    global osfAccountStateCodeFixBatch() {
        this.mapStateCode = new Map < String, String > ();
        for (String row: [SELECT Id, Body FROM StaticResource WHERE Name = 'DickinsonShippingStates' LIMIT 1].Body.toString().split('\n')) {
            List<String> splitStr = new List<String>(row.split(','));
            if (splitStr[0].trim() == 'ShippingState') {
                continue;
            }

            this.mapStateCode.put(splitStr[0].trim(), splitStr[1].trim());
        }
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        List < String > shippingStatesFull = new List < String > (this.mapStateCode.keySet());
        String query = 'SELECT Id, Name, ShippingState FROM Account WHERE ShippingState IN :shippingStatesFull AND ShippingCountry=\'United States\'';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List < Account > accList) {
        List<Account> accToUpdate = new List<Account>();
        for(Account acc : accList){
            if(this.mapStateCode.containsKey(acc.ShippingState)){
            acc.ShippingState = this.mapStateCode.get(acc.ShippingState);
            accToUpdate.add(acc);
            }
        }

        if(accToUpdate.size() > 0)update accToUpdate;
    }

    global void finish(Database.BatchableContext bc) {

    }
}