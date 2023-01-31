({
    handleClick : function (component) {
        component.set("v.update", true);
        component.set("v.tempAccountName", component.get("v.accountName"));
        component.set("v.tempAccountPhone", component.get("v.accountPhone"));
        component.set("v.tempStreetAddress", component.get("v.streetAddress"));
        component.set("v.tempCity", component.get("v.city"));
        component.set("v.tempState", component.get("v.state"));
        component.set("v.tempZipCode", component.get("v.zipCode"));
        //component.set("v.tempUpdate", false);
    },
    
    onSave : function(component) {
        component.set("v.accountName", component.find("accountName").get("v.value"));
        component.set("v.accountPhone", component.find("accountPhone").get("v.value"));
        component.set("v.streetAddress", component.find("streetAddress").get("v.value"));
        component.set("v.city", component.find("city").get("v.value"));
        component.set("v.state", component.find("state").get("v.value"));
        component.set("v.zipCode", component.find("zipCode").get("v.value"));
        component.set("v.update", false);
    },
    
    onCancel : function(component) {
        component.set("v.accountName", component.get("v.tempAccountName"));
        component.set("v.accountPhone", component.get("v.tempAccountPhone"));
        component.set("v.streetAddress", component.get("v.tempStreetAddress"));
        component.set("v.city", component.get("v.tempCity"));
        component.set("v.state", component.get("v.tempState"));
        component.set("v.zipCode", component.get("v.tempZipCode"));
        component.set("v.update", false);
    }
})