public with sharing class QuoteRateCardController {
    
 @AuraEnabled
    public static void saveToMetadata(String recordDeveloperName, String recordLabel, String jsonString, Decimal baseAmount, String departmentName) {
        try {
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'Price_Calculator__mdt.' + recordDeveloperName; 
            customMetadata.label = recordLabel; 
            
            // 1. Assign JSON String
            if (String.isNotBlank(jsonString)) {
                Metadata.CustomMetadataValue payloadField = new Metadata.CustomMetadataValue();
                payloadField.field = 'JSON_Payload__c'; 
                payloadField.value = jsonString; 
                customMetadata.values.add(payloadField);
            }
            
            // 2. Assign Flat Rate to Base_Amount__c
            if (baseAmount != null) {
                Metadata.CustomMetadataValue baseAmountField = new Metadata.CustomMetadataValue();
                baseAmountField.field = 'Base_Amount__c'; 
                baseAmountField.value = baseAmount; 
                customMetadata.values.add(baseAmountField);
            }
            
            // 👉 3. Assign the TRUE Department Name (Decoupled from the label)
            if (String.isNotBlank(departmentName)) {
                Metadata.CustomMetadataValue deptField = new Metadata.CustomMetadataValue();
                deptField.field = 'Department__c'; // Use your exact API name here
                deptField.value = departmentName; 
                customMetadata.values.add(deptField);
            }
            
            mdContainer.addMetadata(customMetadata);
            
            QuoteRateCardCallback callback = new QuoteRateCardCallback();
            Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, callback);
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to deploy Metadata: ' + e.getMessage());
        }
    }

   @AuraEnabled
    public static Price_Calculator__mdt getExistingRates(String recordDeveloperName) {
        try {
            // 👉 Now fetches the entire record, including Base_Amount__c!
            return [SELECT DeveloperName, JSON_Payload__c, Base_Amount__c, rateCard__c 
                    FROM Price_Calculator__mdt 
                    WHERE DeveloperName = :recordDeveloperName 
                    LIMIT 1];
        } catch (Exception e) {
            return null; 
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPriceCalculatorDepartments() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for(Price_Calculator__mdt calc : [SELECT DeveloperName, MasterLabel, Department__c FROM Price_Calculator__mdt ORDER BY MasterLabel ASC]) {
            Map<String, String> item = new Map<String, String>();
            item.put('label', calc.MasterLabel + ' (' + calc.Department__c + ')');
            item.put('value', calc.DeveloperName);
            item.put('department', calc.Department__c);
            result.add(item);
        }
        return result;
    }

    @AuraEnabled
    public static void savePriceCalculatorMetadata(String developerName, String jsonString) {
        try {
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'Price_Calculator__mdt.' + developerName;
            customMetadata.label = developerName.replaceAll('_', ' ');
            
            Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
            customField.field = 'rateCard__c'; 
            customField.value = jsonString; 
            
            customMetadata.values.add(customField);
            mdContainer.addMetadata(customMetadata);
            
            QuoteRateCardCallback callback = new QuoteRateCardCallback();
            Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, callback);
            
            System.debug('Price_Calculator__mdt metadata deployment queued with Job ID: ' + jobId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to deploy Metadata: ' + e.getMessage());
        }
    }

    public class QuoteRateCardCallback implements Metadata.DeployCallback {
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            if (result.status == Metadata.DeployStatus.Succeeded) {
                System.debug('✅ Custom Metadata updated successfully.');
            } else {
                System.debug('❌ Custom Metadata update failed: ' + result.errorMessage);
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static Price_Calculator__mdt getHighMastAmounts(String recordDeveloperName) {
        List<Price_Calculator__mdt> recs = [
            SELECT DeveloperName, MasterLabel, Department__c, Base_Amount__c, Add_On_Amount__c
            FROM Price_Calculator__mdt
            WHERE DeveloperName = :recordDeveloperName
            LIMIT 1
        ];
        return recs.isEmpty() ? null : recs[0];
    }

    @AuraEnabled
    public static void saveHighMastAmounts(String developerName, Decimal baseAmount, Decimal addOn) {
        if (String.isBlank(developerName)) {
            throw new AuraHandledException('Developer Name is required.');
        }

        try {
            // Preserve the existing MasterLabel instead of deriving it from the API name
            String existingLabel;
            for (Price_Calculator__mdt pc : [
                    SELECT MasterLabel FROM Price_Calculator__mdt
                    WHERE DeveloperName = :developerName LIMIT 1]) {
                existingLabel = pc.MasterLabel;
            }

            Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
            cmd.fullName = 'Price_Calculator__mdt.' + developerName;
            cmd.label = String.isNotBlank(existingLabel)
                        ? existingLabel
                        : developerName.replaceAll('_', ' ');

            // Only push fields that were actually supplied, so a null never blanks a live value
            if (baseAmount != null) {
                Metadata.CustomMetadataValue baseVal = new Metadata.CustomMetadataValue();
                baseVal.field = 'Base_Amount__c';
                baseVal.value = baseAmount;
                cmd.values.add(baseVal);
            }

            if (addOn != null) {
            Metadata.CustomMetadataValue addOnVal = new Metadata.CustomMetadataValue();
            addOnVal.field = 'Add_On_Amount__c';
            addOnVal.value = addOn;
            cmd.values.add(addOnVal);
            }

            if (cmd.values.isEmpty()) {
                throw new AuraHandledException('Nothing to update — both Base Amount and Add-On are blank.');
            }

            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(cmd);

            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, new QuoteRateCardCallback());
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to deploy High Mast amounts: ' + e.getMessage());
        }
    }
}