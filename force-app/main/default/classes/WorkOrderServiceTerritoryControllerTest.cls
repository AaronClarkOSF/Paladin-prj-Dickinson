@isTest
public class WorkOrderServiceTerritoryControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account();
        acc.Name = 'Test Account';
        acc.ShippingStreet = '7111 West Washington Street';
        acc.ShippingCity = 'Indianapolis';
        acc.ShippingState = 'IN';
        acc.ShippingPostalCode = '46241';
        acc.ShippingCountry = 'United States';
        acc.ShippingStateCode = 'IN';
        acc.ShippingCountryCode = 'US';
        insert acc;

        Asset asset = new Asset();
        asset.Name ='Test Asset';
        asset.AccountId = acc.Id;
        insert asset;

        OperatingHours op = new OperatingHours();
        op.TimeZone = 'America/Indiana/Indianapolis';
        op.Name = '1000 - 24/7';
        insert op;

        ServiceTerritory str = new ServiceTerritory();
        str.Name = 'Indianapolis Big';
        str.Country = 'United States';
        str.CountryCode = 'US';
        str.OperatingHoursId = op.Id;
        insert str;

        FSL__Polygon__c poly = new FSL__Polygon__c(
                Name = 'Indianapolis Big'
                ,FSL__Color__c = '#5679C0'
                ,FSL__KML__c =  '<?xml version="1.0" encoding="UTF-8"?> '+
                '<kml xmlns="http://www.opengis.net/kml/2.2">'+
                '<Style id="IndianapolisBIGStyle">'+
                '<LineStyle>'+
                '<width>1</width>'+
                '</LineStyle>'+
                '<PolyStyle>'+
                '<color>80C07956</color>'+
                '</PolyStyle>'+
                '</Style>'+
                '<Placemark>'+
                '<name>IndianapolisBIG</name>'+
                '<styleUrl>#IndianapolisBIGStyle</styleUrl>'+
                '<Polygon>'+
                '<outerBoundaryIs>'+
                '<LinearRing>\n'+
                '<coordinates> -86.32562329197897,39.92265695017522,0\n'+
                '-86.32425000096335,39.63981990877852,0\n'+
                '-85.95483471776022,39.64087743098026,0\n'+
                '-85.96582104588522,39.916337503052816,0\n'+
                '-86.32562329197897,39.92265695017522,0\n'+
                '</coordinates>\n'+
                '</LinearRing>'+
                '</outerBoundaryIs>'+
                '</Polygon>'+
                '</Placemark>'+
                '</kml>'
                ,FSL__Ma_La__c = 39.92265695017522
                ,FSL__Ma_Lo__c = -85.95483471776022
                ,FSL__Mi_La__c = 39.63981990877852
                ,FSL__Mi_Lo__c = -86.32562329197897
        );
        insert poly;

     /*   FSL__Polygon__c poly = new FSL__Polygon__c();
        poly.Name = 'Indianapolis Big';
        poly.FSL__KML__c = '<?xmlversion="1.0"encoding="UTF-8"?><kmlxmlns="http://www.opengis.net/kml/2.2"><Styleid="IndianapolisBIGStyle"><LineStyle><width>1</width></LineStyle><PolyStyle><color>80C07956</color></PolyStyle></Style><Placemark><name>IndianapolisBIG</name><styleUrl>#IndianapolisBIGStyle</styleUrl><Polygon><outerBoundaryIs><LinearRing><coordinates>-86.32562329197897,39.92265695017522,0-86.32425000096335,39.63981990877852,0-85.95483471776022,39.64087743098026,0-85.96582104588522,39.916337503052816,0-86.32562329197897,39.92265695017522,0</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark></kml>';
        poly.FSL__Ma_La__c = Double.valueOf(39.92265695017522);
        poly.FSL__Ma_Lo__c = Double.valueOf(-85.95483471776022);
        poly.FSL__Mi_La__c = Double.valueOf(39.63981990877852);
        poly.FSL__Mi_Lo__c = Double.valueOf(-86.32562329197897);
        poly.FSL__Color__c = '#5679C0';
        poly.FSL__Service_Territory__c = str.Id;
        insert poly; */

        WorkOrder wo = new WorkOrder();
        wo.AssetId = asset.Id;
        wo.Latitude = Double.valueOf(39.739941);
        wo.Longitude = Double.valueOf(-86.286498);
        wo.AccountId = acc.Id;
        wo.Street = acc.ShippingStreet;
        wo.State = acc.ShippingStateCode;
        wo.PostalCode = acc.ShippingPostalCode;
        wo.Country = acc.ShippingCountry;
        wo.City = acc.ShippingCity;
        insert wo;
 
    }

    @isTest
    public static void fetchServiceTerritoryId_test() {
        Id woId = [SELECT Id, Latitude, Longitude FROM WorkOrder ORDER BY CreatedDate DESC LIMIT 1].Id;

        Test.startTest();
        WorkOrderServiceTerritoryController.fetchServiceTerritoryId(woId);
        Test.stopTest();
    }
}