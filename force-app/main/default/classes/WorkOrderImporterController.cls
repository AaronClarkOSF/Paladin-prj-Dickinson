public with sharing class WorkOrderImporterController {

    private static final string BOOLEAN_TRUE = 'TRUE'; //case does not matter as long as the value for the boolean field from CSV document says true. Anything other than that is considered false.

    @AuraEnabled
    public static Id handleUpload(String file, String body) {
        Workorder_Column_Mapping__mdt[] mappings = [Select MasterLabel, Required__c, Salesforce_Field__c, Only_Set_If_Exists__c from Workorder_Column_Mapping__mdt];
        return processFile(file, body, mappings);
    }

    @AuraEnabled
    public static String isDone(Id workOrderUploadId) {
        Work_Order_Upload__c wou = [Select Id, Processed_Rows__c, Status__c from Work_Order_Upload__c where Id =: workOrderUploadId];

        Map < String, Object > mapRes = new Map < String, Object > ();

        mapRes = (Map < String, Object > ) JSON.deserializeUntyped(JSON.serialize(wou.getPopulatedFieldsAsMap()));

        if (wou.Status__c == 'Failed with Errors') {
            String error = [SELECT Error__c FROM Work_Order_Upload_Error_Line__c WHERE Work_Order_Upload__c =: workOrderUploadId ORDER BY CreatedDate DESC LIMIT 1].Error__c;
            mapRes.put('Error_Description__c', String.isNotEmpty(error) && String.isNotBlank(error) ? error + '. Contact your administrator' : 'Exception error. Contact your administrator');
        }
        return JSON.serialize(mapRes);
    }

    public static Id processFile(String file, String body, Workorder_Column_Mapping__mdt[] mappings) {
        Work_Order_Upload__c wou = new Work_Order_Upload__c(Status__c = 'Pending', Processed_Rows__c = 0);
        insert wou;

        system.debug(wou.Id);
        ContentVersion cv = new ContentVersion(Work_Order_File_Type__c = 'Import', FirstPublishLocationId = wou.Id, PathOnClient = file, VersionData = EncodingUtil.base64Decode(body));
        insert cv;
        AsyncProcessFile apf = new AsyncProcessFile(wou.Id);
        Id jobId = System.enqueueJob(apf);
        wou.Current_Job_Id__c = jobId;
        update wou;
        return wou.Id;
    }


    public class AsyncProcessFile implements Queueable {
        Id fileId {
            get;
            set;
        }

        public AsyncProcessFile(Id fileId) {
            this.fileId = fileId;
        }

        public void execute(QueueableContext context) {
            Work_Order_Upload__c wou = [Select Id, Status__c, Processed_Rows__c, Last_Index__c from Work_Order_Upload__c where Id =: fileID];

            Workorder_Column_Mapping__mdt[] mappings = [Select MasterLabel, Required__c, Salesforce_Field__c, Only_Set_If_Exists__c from Workorder_Column_Mapping__mdt];
            String body = [Select VersionData from ContentVersion where FirstPublishLocationId =: wou.Id and Work_Order_File_Type__c = 'Import'
                limit 1
            ].VersionData.toString();
            processFile(body, mappings, wou);

        }

        public String[] getParts(String line) {
            String[] parts = line.split(',');
            for (Integer i = 0; i < parts.size(); i++) {
                parts[i] = parts[i].trim();
            }
            return parts;
        }

        public String hasRequired(SObject o, Workorder_Column_Mapping__mdt[] required) {
            String[] errors = new String[0];
            for (Workorder_Column_Mapping__mdt m: required) {
                if (m.Only_Set_If_Exists__c) {
                    String[] fieldParts = m.Salesforce_Field__c.split('\\.');
                    String cname;
                    if (fieldParts[0].contains('__r')) {
                        cName = fieldParts[0].replace('__r', '__c');
                    } else {
                        cname = fieldParts[0] + 'Id';
                    }
                    if (((Id) o.get(cname)) == null) {
                        errors.add(m.MasterLabel);
                    }
                } else {
                    if (o.get(m.Salesforce_Field__c) == null || (((String) o.get(m.Salesforce_field__c)) == '')) {
                        errors.add(m.MasterLabel);
                    }
                }
            }
            if (errors.size() > 0) {
                return 'The following columns are required and blank or do not match a lookup: ' + String.join(errors, ' ');
            }
            return null;
        }

        public void processFile(String body, Workorder_Column_Mapping__mdt[] mappings, Work_Order_Upload__c wou) {

            try {
                Map < String, Workorder_Column_Mapping__mdt[] > columnToColumns = new Map < String, Workorder_Column_Mapping__mdt[] > ();
                Workorder_Column_Mapping__mdt[] requiredColumns = new Workorder_Column_Mapping__mdt[0];
                for (Workorder_Column_Mapping__mdt mapping: mappings) {
                    if (!columnToColumns.containsKey(mapping.MasterLabel.trim())) {
                        System.Debug(mapping.MasterLabel.trim());
                        columnToColumns.put(mapping.MasterLabel.trim(), new Workorder_Column_Mapping__mdt[0]);
                    }
                    columnToColumns.get(mapping.MasterLabel.trim()).add(mapping);
                    if (mapping.Required__c) {
                        requiredColumns.add(mapping);
                    }
                }
                if (body != null && body.length() > 0 && body.codePointAt(0) == 65279) {
                    body = body.right(body.length() - 1);
                }
                Integer index = body.indexOf('\n');
                System.Debug(body.left(index));
                System.Debug(body.left(index).trim());
                String[] header = getParts(body.left(index).trim());
                index = index + 1;
                System.Debug(header);
                Map < String, Integer > headerMap = new Map < String, Integer > ();
                for (Integer i = 0; i < header.size(); i++) {
                    headerMap.put(header[i], i);
                }
                Integer lineNum = (wou.Processed_Rows__c != null ? wou.Processed_Rows__c.intValue() : 0);
                index = (wou.Last_Index__c == null ? index : wou.Last_Index__c.intValue());
                System.Debug(body);
                System.Debug(index);
                SplitLinesReturn slr = splitLines(body, index);
                system.debug(slr);

                SObject[] toUpsert = new SObject[0];
                Map < String, Map < String, Map < String, Id >>> foundKeys = new Map < String, Map < String, Map < String, Id >>> ();
                Map < String, Map < String, Set < String >>> searchKeys = new Map < String, Map < String, Set < String >>> ();
                Map < String, Id > updateMap = new Map < String, Id > ();
                Set < String > updateSearch = new Set < String > ();
                Map < Integer, String > missingErrors = new Map < Integer, String > ();

                System.Debug(columnToColumns);
                for (Integer i = 0; i < slr.lines.size(); i++) {
                    System.Debug(slr.lines[i]);
                    String[] parts = getParts(slr.lines[i]);
                    for (Integer j = 0; j < header.size(); j++) {
                        System.Debug(header[j]);
                        System.Debug(columnToColumns.containsKey(header[j].trim()));
                        if (columnToColumns.containsKey(header[j])) {
                            for (Workorder_Column_Mapping__mdt wcm: columnToColumns.get(header[j])) {
                                if (wcm.Only_Set_If_Exists__c) {
                                    String[] fieldParts = wcm.Salesforce_Field__c.split('\\.');
                                    String cname;
                                    System.Debug(fieldParts);
                                    if (fieldParts[0].contains('__r')) {
                                        cName = fieldParts[0].replace('__r', '__c');
                                    } else if (!fieldParts[0].contains('__c')) {
                                        cname = fieldParts[0] + 'Id';
                                    }
                                    System.Debug(cName);
                                    String objectName = Schema.getGlobalDescribe().get('WorkOrder').getDescribe().fields.getMap().get(cName).getDescribe().getReferenceTo()[0].getDescribe().getName();
                                    System.Debug(objectName);
                                    if (!foundKeys.containsKey(objectName)) {
                                        foundKeys.put(objectName, new Map < String, Map < String, Id >> ());
                                        searchKeys.put(objectName, new Map < String, Set < String >> ());
                                    }
                                    if (!foundKeys.get(objectName).containsKey(fieldParts[1])) {
                                        foundKeys.get(objectName).put(fieldParts[1], new Map < String, Id > ());
                                        searchKeys.get(objectName).put(fieldParts[1], new Set < String > ());
                                    }
                                    if (parts[j] != '') {
                                        searchKeys.get(objectName).get(fieldParts[1]).add(parts[j]);
                                    }
                                }
                            }
                        }
                    }
                }
                system.debug(searchKeys);
                for (String s: searchKeys.keySet()) {
                    for (String t: searchKeys.get(s).keySet()) {
                        String[] vals = new String[0];
                        vals.addAll(searchKeys.get(s).get(t));
                        system.debug(vals);
                        system.debug('SELECT ' + t + ' FROM ' + s + ' WHERE ' + t + ' IN :vals');
                        for (SObject so: Database.query('SELECT ' + t + ' FROM ' + s + ' WHERE ' + t + ' IN :vals')) {
                            foundKeys.get(s).get(t).put((String) so.get(t), so.Id);
                        }
                    }
                }
                system.debug(foundKeys);
                Map < Integer, Integer > rowToOriginal = new Map < Integer, Integer > ();
                Work_Order_Upload_Error_Line__c[] errors = new Work_Order_Upload_Error_Line__c[0];
                for (Integer i = 0; i < slr.lines.size(); i++) {
                    SObject tempUpsert = Schema.getGlobalDescribe().get('WorkOrder').newSObject();
                    Map < String, Schema.SObjectField > fieldMap = Schema.getGlobalDescribe().get('WorkOrder').getDescribe().fields.getMap();
                    String[] parts = getParts(slr.lines[i]);
                    system.debug(header);
                    for (Integer j = 0; j < header.size(); j++) {
                        if (columnToColumns.containsKey(header[j])) {
                            System.Debug(header[j]);
                            for (Workorder_Column_Mapping__mdt wcm: columnToColumns.get(header[j])) {
                                if (!wcm.Salesforce_Field__c.contains('.')) {
                                    system.debug(wcm.Salesforce_Field__c);
                                    if (fieldMap.containsKey(wcm.Salesforce_Field__c) && parts.size() > j) {
                                        DescribeFieldResult fr = fieldMap.get(wcm.Salesforce_Field__c).getDescribe();
                                        if (fr.getSOAPType() == Schema.SOAPType.Double) {
                                            tempUpsert.put(wcm.Salesforce_Field__c, parts[j] == '' ? null : Decimal.valueOf(parts[j]));
                                        } else if (fr.getSOAPType() == Schema.SOAPType.Date) {
                                            tempUpsert.put(wcm.Salesforce_Field__c, parts[j] == '' ? null : Date.parse(parts[j]));
                                        } else if (fr.getSOAPType() == Schema.SOAPType.Boolean) {
                                            tempUpsert.put(wcm.Salesforce_Field__c, parts[j].equalsIgnoreCase(BOOLEAN_TRUE) ? true : false);
                                        } else {
                                            tempUpsert.put(wcm.Salesforce_Field__c, parts[j]);
                                        }
                                    }

                                } else {
                                    System.Debug(wcm.Salesforce_Field__c);
                                    String[] fieldParts = wcm.Salesforce_Field__c.split('\\.');
                                    String cName;
                                    if (fieldParts[0].contains('__r')) {
                                        cName = fieldParts[0].replace('__r', '__c');
                                    } else {
                                        cname = fieldParts[0] + 'Id';
                                    }
                                    system.debug(cname);
                                    if (cname == 'AccountId') {
                                        System.debug(cname);
                                        System.Debug(parts[j]);
                                    }
                                    SObject relObject = Schema.getGlobalDescribe().get('WorkOrder').getDescribe().fields.getMap().get(cName).getDescribe().getReferenceTo()[0].newSObject();
                                    String objName = Schema.getGlobalDescribe().get('WorkOrder').getDescribe().fields.getMap().get(cName).getDescribe().getReferenceTo()[0].getDescribe().getName();
                                    if (parts[j] != '' && (!wcm.Only_Set_If_Exists__c || (foundKeys.containsKey(objName) && foundKeys.get(objName).containsKey(fieldParts[1]) && foundKeys.get(objName).get(fieldParts[1]).containsKey(parts[j])))) {
                                        tempUpsert.put(cname, foundKeys.get(objName).get(fieldParts[1]).get(parts[j]));
                                    }
                                }
                            }
                        }
                    }
                    system.debug(tempUpsert);
                    Database.DMLOptions dml = new Database.DMLOptions();
                    dml.DuplicateRuleHeader.AllowSave = true;
                    tempUpsert.setOptions(dml);
                    String requiredError = hasRequired(tempUpsert, requiredColumns);
                    if (requiredError == null) {
                        toUpsert.add(tempUpsert);
                        rowToOriginal.put(toUpsert.size() - 1, i);
                    } else {
                        missingErrors.put(i, requiredError);
                        errors.add(new Work_Order_Upload_Error_Line__c(Row_Number__c = (lineNum + i + 1), Error__c = requiredError.left(255), Work_Order_Upload__c = wou.Id));
                    }

                }
                Integer[] errorLines = new Integer[0];
                Integer[] originalErrorLines = new Integer[0];
                Database.SaveResult[] insertResults = new Database.SaveResult[0];
                String errorFileData = '';
                ContentVersion cv;
                try {
                    cv = [Select Id, VersionData from ContentVersion where FirstPublishLocationId =: wou.Id and Work_Order_File_Type__c = 'Error'
                        limit 1
                    ];
                    errorFileData = cv.VersionData.toString();
                } catch (Exception ex) {
                    cv = new ContentVersion(isMajorVersion = false, Title = 'Errors', FirstPublishLocationId = wou.Id, Work_Order_File_Type__c = 'Error', PathOnClient = 'Errors.csv');
                }
                System.Debug(toUpsert);
                insertResults = Database.insert(toUpsert, false);


                Integer rowNumber = 0;
                for (Database.SaveResult result: insertResults) {
                    if (!result.isSuccess()) {
                        errorLines.add(rowNumber);
                        originalErrorLines.add(rowToOriginal.get(rowNumber));
                        Work_Order_Upload_Error_Line__c wouel = new Work_Order_Upload_Error_Line__c(Row_Number__c = (lineNum + rowToOriginal.get(rowNumber)) + 1, Error__c = result.getErrors()[0].getMessage().left(255), Work_Order_Upload__c = wou.Id);
                        errors.add(wouel);
                    }
                    rowNumber++;
                }
                lineNum = lineNum + slr.lines.size();
                insert errors;
                if (errors.size() > 0) {
                    if (errorFileData == '') {
                        String[] tempHeader = new string[0];
                        tempHeader.addAll(header);
                        tempHeader.add('Error');
                        errorFileData += (String.join(tempHeader, ',') + '\n');
                    }
                    for (Integer i = 0; i < errorLines.size(); i++) {
                        errorFileData += (slr.lines[originalErrorLines[i]] + ',' + insertResults[errorLines[i]].getErrors()[0].getMessage().replaceAll(',', '') + '\n');
                    }
                    for (Integer i: missingErrors.keySet()) {
                        errorFileData += (slr.lines[i] + ',' + missingErrors.get(i) + '\n');
                    }
                    cv.VersionData = Blob.valueOf(errorFileData);
                    upsert cv;
                }
                wou.Status__c = (((wou.Status__c == 'Processing With Errors' || errors.size() > 0) && slr.complete) ? 'Complete With Errors' : ((wou.Status__c == 'Processing With Errors' || errors.size() > 0) ? 'Processing With Errors' : (slr.complete ? 'Complete' : 'Processing')));
                wou.Last_Index__c = slr.index;

                wou.Processed_Rows__c = linenum;
                update wou;
                if (!wou.Status__c.startsWithIgnoreCase('Complete')) {
                    AsyncProcessFile apf = new AsyncProcessFile(fileId);
                    Id jobId = System.enqueueJob(apf);
                    wou.Current_Job_Id__c = jobId;
                } else {
                    wou.Current_Job_Id__c = null;
                }
                update wou;
            } catch (Exception ex) {
                // List<Work_Order_Upload_Error_Line__c> workOrderUploadError = new List<Work_Order_Upload_Error_Line__c>([SELECT Id, Name, Work_Order_Upload__c, Error__c, Row_Number__c, Format(CreatedDate) FROM Work_Order_Upload_Error_Line__c WHERE Work_Order_Upload__c = :wou.Id ORDER BY CreatedDate DESC LIMIT 1]);
                Work_Order_Upload_Error_Line__c uploadError = new Work_Order_Upload_Error_Line__c(Work_Order_Upload__c = wou.Id, Stack_Trace_Line_Number__c = 'WorkOrderImporterController error on line : ' + ex.getLineNumber(), Error__c = ex.getMessage());
                insert uploadError;

                wou.Status__c = 'Failed with Errors';
                update wou;
            }
        }


        public SplitLinesReturn splitLines(String body, Integer index) {
            SplitLinesReturn slr = new SplitLinesReturn();
            slr.complete = false;
            slr.lines = new String[0];
            Boolean done = false;
            Integer oldIndex = index;
            Integer newIndex;
            while (!done) {
                if (slr.lines.size() < 200) {
                    newIndex = body.indexOf('\n', oldIndex);
                    System.Debug(newIndex);
                    if (newIndex != -1 && slr.lines.size() < 200) { //(Decimal.valueOf(Limits.getCpuTime()) / Decimal.valueOf(Limits.getLimitCpuTime())) < .05
                        slr.lines.add(body.substring(oldIndex, newIndex).trim());
                        oldIndex = newIndex + 1;
                    } else {
                        done = true;
                        if (newIndex == -1) {
                            slr.complete = true;
                        }
                    }
                } else {
                    done = true;
                }
            }
            if (slr.complete && oldIndex < body.length()) {
                slr.lines.add(body.substring(oldIndex).trim());
            }
            slr.index = newIndex + 1;
            return slr;
        }
    }
    public class SplitLinesReturn {
        public String[] lines {
            get;
            set;
        }
        public Integer index {
            get;
            set;
        }
        public Boolean complete {
            get;
            set;
        }
    }
}