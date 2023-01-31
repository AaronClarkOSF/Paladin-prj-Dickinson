global class WorkOrderServiceTerritoryFetch {

    global class input {
        @InvocableVariable(label = 'Work Order Id'
            description = 'Id of the work order created')
        global Id workOrderId;

    }


    global class output {
        @InvocableVariable(label = 'Service Territory Id'
            description = 'Service Territory Id based on Polygon search')
        global String serviceTerritoryId;

        global output(Id serviceTerritoryId) {
            this.serviceTerritoryId = serviceTerritoryId;
        }
    }

    @InvocableMethod(label = 'Fetch Service Territory Id')
    global static List < output > fetchServiceTerritoryId(List < input > inpList) {
        List < output > outList = new List < output > ();

        if (inpList.size() > 0 && inpList.get(0).workOrderId != null) {
            List < WorkOrder > woList = [SELECT Id, Subject, Tax, Priority, Latitude, Longitude FROM WorkOrder WHERE Id =: inpList.get(0).workOrderId];
            if (!woList.isEmpty()) {
                //retrieve the service territory record id from the getTerritoryIdByPolygons method using geolocation fields from the work order record found

                Double longitude = double.valueOf(woList[0].longitude);
                Double latitude = double.valueOf(woList[0].latitude);
                system.debug(woList.get(0));
                system.debug(longitude);
                system.debug(latitude);

                Long startTime = DateTime.now().getTime();
                Long finishTime = DateTime.now().getTime();
                while((longitude == null || latitude == null) && Limits.getCpuTime() < Limits.getLimitCpuTime() && (finishTime - startTime) < 5000){} //waiting till Longitude and Latitude values are calculated
                if (longitude != null && latitude != null) {
                    Id ServiceTerritoryId = FSL.PolygonUtils.getTerritoryIdByPolygons(longitude, latitude);
                    system.debug(ServiceTerritoryId);
                    if (ServiceTerritoryId != null) {
                        WorkOrder wo = new WorkOrder(Id = woList.get(0).Id, ServiceTerritoryId = ServiceTerritoryId);
                        update wo;


                        outList.add(new output(ServiceTerritoryId));
                        system.debug(outList);
                        return outlist;
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
}