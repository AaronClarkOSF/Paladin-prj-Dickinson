@isTest
public class osfAccountStateCodeFixBatchTest {

    @TestSetup
    static void makeData() {
        List < Account > accList = new List < Account > ();
        for (Integer i= 0; i < 5; i++) {
            Account acc = new Account();
            if (i < 3) {
                acc.Name = 'Test Account ' + (i + 1);
                acc.ShippingStreet = '123 Street';
                acc.ShippingCity = 'Columbus';
                acc.ShippingState = 'Ohio';
                acc.ShippingPostalCode = '43215';
                acc.ShippingCountryCode = 'US';
                accList.add(acc);
            } else {
                acc.Name = 'Test Account ' + (i + 1);
                acc.ShippingStreet = '456 Street';
                acc.ShippingCity = 'Dallas';
                acc.ShippingState = 'Texas';
                acc.ShippingPostalCode = '75001';
                acc.ShippingCountryCode = 'US';
                accList.add(acc);
            }
        }
        insert accList;
    }

    @isTest
    public static void testStateCodeFix_1() {

        for (Account acc: [SELECT ShippingState From Account ORDER BY CreatedDate DESC LIMIT 10]) {
            system.assert(acc.ShippingState.length() > 2);
        }

        Test.startTest();
        database.executeBatch(new osfAccountStateCodeFixBatch(), 200);
        Test.stopTest();

        for (Account acc: [SELECT ShippingState From Account ORDER BY CreatedDate DESC LIMIT 10]) {
            system.assertEquals(2, acc.ShippingState.length());
        }
    }
}