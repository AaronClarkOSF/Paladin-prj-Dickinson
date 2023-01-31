({
    handleClick : function (component) {
        component.set("v.update", true);
        component.set("v.tempBillingStreetAddress", component.get("v.billingStreetAddress"));
        component.set("v.tempBillingCity", component.get("v.billingCity"));
        component.set("v.tempBillingState", component.get("v.billingState"));
        component.set("v.tempBillingZipCode", component.get("v.billingZipCode"));
        //component.set("v.tempUpdate", false);
    },
    
    onSave : function(component) {
        component.set("v.billingStreetAddress", component.find("billingStreetAddress").get("v.value"));
        component.set("v.billingCity", component.find("billingCity").get("v.value"));
        component.set("v.billingState", component.find("billingState").get("v.value"));
        component.set("v.billingZipCode", component.find("billingZipCode").get("v.value"));
        component.set("v.update", false);
    },
    
    onCancel : function(component) {
        component.set("v.billingStreetAddress", component.get("v.tempBillingStreetAddress"));
        component.set("v.billingCity", component.get("v.tempBillingCity"));
        component.set("v.billingState", component.get("v.tempBillingState"));
        component.set("v.billingZipCode", component.get("v.tempBillingZipCode"));
        component.set("v.update", false);
    }
})