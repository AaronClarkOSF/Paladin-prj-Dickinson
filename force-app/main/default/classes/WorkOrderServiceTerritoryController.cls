public class WorkOrderServiceTerritoryController {

    @AuraEnabled(cacheable = true)
    public static Id fetchServiceTerritoryId(Id workOrderId) {
        if (workOrderId != null) {
            List < WorkOrder > woList = [SELECT Id, Subject, Tax, Priority, Latitude, Longitude FROM WorkOrder WHERE Id =: workOrderId];

            if (!woList.isEmpty()) {
                //retrieve the service territory record id from the getTerritoryIdByPolygons method using geolocation fields from the work order record found

                Double longitude = double.valueOf(woList[0].longitude);
                Double latitude = double.valueOf(woList[0].latitude);

                if (longitude != null && latitude != null) {
                    Id ServiceTerritoryId = FSL.PolygonUtils.getTerritoryIdByPolygons(longitude, latitude);
                    if (ServiceTerritoryId != null) {
                        return ServiceTerritoryId;
                    } else {
                        return null;
                    }
                } else {
                    return null;
                }
            } else {
                return null;
            }
        } else {
            return null;
        }
    }

    @AuraEnabled(cacheable = true)
    public static List < ServiceTerritoryPicklist > getServiceTerritories() {
        List < ServiceTerritoryPicklist > ServiceTerritoryList = new List < ServiceTerritoryPicklist > ();

        for (ServiceTerritory st: [SELECT Id, Name, Street, City, State, PostalCode, Country FROM ServiceTerritory WHERE IsActive = true LIMIT 10000]) {
            ServiceTerritoryList.add(new ServiceTerritoryPicklist(st.Name, st.Id));
        }

        return ServiceTerritoryList;
    }

    @AuraEnabled
    public static Boolean saveServiceTerritory(Id workOrderId, Id serviceTerritoryId, Boolean updateWorkOrder, Boolean updateRelatedServiceAppointment) {
        Boolean isSuccess = true;
        Database.SaveResult[] woSrList;
        Database.SaveResult[] saSrList;

        if(workOrderId != null && serviceTerritoryId != null && updateWorkOrder){
            WorkOrder wo = new WorkOrder(Id = workOrderId, ServiceTerritoryId = serviceTerritoryId);
            woSrList = Database.update(new List < WorkOrder > {
                wo
            });
            isSuccess = isSuccess && woSrList.get(0).isSuccess();
        }

        if(workOrderId != null && serviceTerritoryId != null && updateRelatedServiceAppointment){
            List < ServiceAppointment > saList = new List < ServiceAppointment > ([SELECT Id, ServiceTerritoryId FROM ServiceAppointment WHERE ParentRecordId =: workOrderId LIMIT 8000]);

            for(ServiceAppointment sa : saList){
                sa.ServiceTerritoryId = serviceTerritoryId;
            }

            saSrList = Database.update(saList);

            for( Database.SaveResult sr : saSrList){
                isSuccess = isSuccess && sr.isSuccess();
            }
        }
        
        
        if(!woSrList.isEmpty() || !saSrList.isEmpty()){
            return isSuccess;
        } else {
            return null;
        }
        
        
        
     /*   if (workOrderId != null && serviceTerritoryId != null) {
            WorkOrder wo = new WorkOrder(Id = workOrderId, ServiceTerritoryId = serviceTerritoryId);

            List < ServiceAppointment > saList = new List < ServiceAppointment > ([SELECT Id, ServiceTerritoryId FROM ServiceAppointment WHERE ParentRecordId =: workOrderId LIMIT 8000]);

            for(ServiceAppointment sa : saList){
                sa.ServiceTerritoryId = serviceTerritoryId;
            }

            Database.SaveResult[] saSrList = Database.update(saList);

            Database.SaveResult[] woSrList = Database.update(new List < WorkOrder > {
                wo
            });

            Boolean isSuccess = true;

            for( Database.SaveResult sr : saSrList){
                isSuccess = isSuccess && sr.isSuccess();
            }

            isSuccess = isSuccess && woSrList.get(0).isSuccess();

            return isSuccess;
        } else {
            return null;
        } */
    }


    public class ServiceTerritoryPicklist {

        @AuraEnabled
        public string label;

        @AuraEnabled
        public string value;

        public ServiceTerritoryPicklist(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

}