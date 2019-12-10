/*********************************************************************************************************
    @Apex Class Name : ConverterSupportClassLightning
    @Created By  : Carlos Naranjo (carlos.naranjo@ccloudonline.nl) on 12/8/19
    @Description : Controller for LWC Convertersupportlightning. Contains HTTP Request to Get Code values
*********************************************************************************************************/

public with sharing class ConverterSupportClassLightning {

    private static String defaultCurrency { get; set; }
    private static String secondaryCurrency { get; set; }
    private static Decimal entryValueOne { get; set; }
    private static Decimal entryValueTwo { get; set; }
    private static Rate_Code__c rate { get; set; }
    private static Rate_Code__c soqlEntryCurrencyOne { get; set; }
    private static Rate_Code__c soqlEntryCurrencyTwo { get; set; }
    private static Decimal bitcoinValue = 1;
    private static Decimal noBitcoinValue;
    private static Decimal CalculationEntryValueTwo;
    private static String bitcoinBTC = 'Bitcoin (BTC)';

    public class ValidationException extends Exception {
    }

    @AuraEnabled
    public static Map<String, Object> makeHTTPCall() {
        Map<String, Object> result = new Map<String, Object>();
        String endpoint = 'https://bitpay.com/api/rates/';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        HttpResponse res = http.send(req);
        String responseBody = res.getBody();
        String message = '';
        Boolean error = false;

        try {

            if (res.getStatusCode() != 200) {
                throw new ValidationException('Call out failed: ' + res.getStatusCode() + ' ' + res.getStatus());

            } else {
                List<Codes> restCode = (List<Codes>) JSON.deserialize(responseBody, List<Codes>.class);
                List<Rate_Code__c> inSystemCodesList = [SELECT Code__c, Rate__c FROM Rate_Code__c];
                Map<String, Decimal> inSystemCodesMap = new Map<String, Decimal>();
                Map<String, Decimal> incomingCodesMap = new Map<String, Decimal>();

                // Use these collections to insert new Rate_Code__c records based on new
                // restCode Codes that are not in the system.
                Set<String> theIncomingKeysToInsert = new Set<String>();
                List<Rate_Code__c> codesList = new List<Rate_Code__c>();

                // Adding Code__c and Rate__c values from SFDC to a map
                for (Integer c = 0; c < inSystemCodesList.size(); c++) {
                    inSystemCodesMap.put(inSystemCodesList[c].Code__c, inSystemCodesList[c].Rate__c);
                }

                //Adding code and rate values from JSON to a map
                for (Integer i = 0; i < restCode.size(); i++) {
                    incomingCodesMap.put(restCode[i].code, restCode[i].rate);
                }

                //Iterate through codes that are already in the system
                for (String k : inSystemCodesMap.keySet()) {

                    // If incoming Codes from GET response does not match with those in system,
                    // send to collection for later processing
                    if (!incomingCodesMap.keySet().contains(k)) {
                        theIncomingKeysToInsert.add(k);
                    }
                }

                // Inserting new Code/Rate/Currency if there is a new Code (Name, Rate, and Code)
                // coming from the http response
                for (Integer i = 0; i < restCode.size(); i++) {

                    Rate_Code__c codeItem = new Rate_Code__c();

                    codeItem = new Rate_Code__c(Name = restCode[i].name,
                            Name__c = restCode[i].name,
                            Rate__c = restCode[i].rate,
                            Code__c = restCode[i].code,
                            Currency__c = restCode[i].name + ' ' + '(' + restCode[i].code + ')'
                    );

                    codesList.add(codeItem);
                }

                // This list will contain only new Codes
                List<Rate_Code__c> newRateCodesToInsert = new List<Rate_Code__c>();

                for (Rate_Code__c rcs : codesList) {
                    for (String str : theIncomingKeysToInsert) {
                        if (rcs.Code__c == str) {
                            newRateCodesToInsert.add(rcs);
                        }
                    }
                }

                // Inserting new Codes if any
                if (!newRateCodesToInsert.isEmpty() && newRateCodesToInsert.size() > 0) {
                    insert newRateCodesToInsert;
                }

                // Getting Rate_Code__c records from system and update them with the new rate
                // from incomingCodesMap.
                List<Rate_Code__c> rc = [
                        SELECT Id, Rate__c, Code__c, Name__c
                        FROM Rate_Code__c
                        WHERE Code__c IN :incomingCodesMap.keySet()
                ];

                if (!rc.isEmpty() && rc.size() > 0) {
                    for (Rate_Code__c r : rc) {
                        if (r.Code__c != null && incomingCodesMap.containsKey(r.Code__c)) {
                            r.Rate__c = incomingCodesMap.get(r.Code__c);
                        }
                    }
                }

                if (!rc.isEmpty()) {
                    update rc;
                }

                defaultCurrency = bitcoinBTC;
                secondaryCurrency = 'US Dollar (USD)';

                rate = [
                        SELECT Rate__c, Currency__c
                        FROM Rate_Code__c
                        WHERE Currency__c = :secondaryCurrency
                        LIMIT 1
                ];

                entryValueOne = 1;
                entryValueTwo = rate.Rate__c;
            }

        } catch (ValidationException e) {
            message = e.getMessage();
            error = true;

        } catch (DmlException e) {
            message = 'DML failed: ' + e.getMessage();
            error = true;
        }

        result.put('message', message);
        result.put('entryValueOne', entryValueOne);
        result.put('entryValueTwo', entryValueTwo);
        result.put('error', error);
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> defaultCurrencyEntryChanges(SubmitCurrencyChanges submitCurrencyChanges) {
        Map<String, Object> result = new Map<String, Object>();
        String message = '';
        Boolean error = false;

        try {

            if (submitCurrencyChanges == null) {
                throw new ValidationException('Currency data error. Contact your administrator');

            } else if (submitCurrencyChanges.defaultCurrency == bitcoinBTC &&
                    submitCurrencyChanges.secondaryCurrency != bitcoinBTC &&
                    (submitCurrencyChanges.entryValueOne != 0 || submitCurrencyChanges.entryValueOne != null)) {
                bitcoinValue = submitCurrencyChanges.entryValueOne;

                soqlEntryCurrencyOne = [
                        SELECT Rate__c, Currency__c
                        FROM Rate_Code__c
                        WHERE Currency__c = :submitCurrencyChanges.secondaryCurrency
                ];

                CalculationEntryValueTwo = soqlEntryCurrencyOne.Rate__c.setScale(8);
                entryValueTwo = bitcoinValue * CalculationEntryValueTwo.setScale(3);

                // Actions for non Bitcoin currencies on defaultCurrency
            } else if (submitCurrencyChanges.defaultCurrency != bitcoinBTC &&
                    submitCurrencyChanges.secondaryCurrency != submitCurrencyChanges.defaultCurrency &&
                    (submitCurrencyChanges.entryValueOne != 0 || submitCurrencyChanges.entryValueOne != null)) {

                soqlEntryCurrencyOne = [
                        SELECT RateVsBitcoin__c, Currency__c
                        FROM Rate_Code__c
                        WHERE Currency__c = :submitCurrencyChanges.defaultCurrency
                ];

                soqlEntryCurrencyTwo = [
                        SELECT Rate__c, Currency__c
                        FROM Rate_Code__c
                        WHERE Currency__c = :submitCurrencyChanges.secondaryCurrency
                ];

                noBitcoinValue = submitCurrencyChanges.entryValueOne * soqlEntryCurrencyOne.RateVsBitcoin__c;
                entryValueTwo = noBitcoinValue * soqlEntryCurrencyTwo.Rate__c.setScale(3);
            }

        } catch (ValidationException e) {
            message = e.getMessage();
            error = true;
        }

        result.put('entryValueTwo', entryValueTwo);
        result.put('message', message);
        result.put('error', error);
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> secondaryCurrencyEntryChanges(SubmitCurrencyChanges submitCurrencyChanges) {
        Map<String, Object> result = new Map<String, Object>();
        String message = '';
        Boolean error = false;

        try {

            if (submitCurrencyChanges == null) {
                throw new ValidationException('Currency data error. Contact your administrator');
            }

            else if (submitCurrencyChanges.secondaryCurrency == bitcoinBTC &&
                    submitCurrencyChanges.defaultCurrency != bitcoinBTC &&
                    (submitCurrencyChanges.entryValueTwo != 0 || submitCurrencyChanges.entryValueTwo != null)) {
                bitcoinValue = submitCurrencyChanges.entryValueTwo;

                soqlEntryCurrencyTwo = [
                        SELECT Rate__c, Currency__c
                        FROM Rate_Code__c
                        WHERE Currency__c = :submitCurrencyChanges.defaultCurrency
                ];

                CalculationEntryValueTwo = soqlEntryCurrencyTwo.Rate__c.setScale(8);
                entryValueOne = bitcoinValue * CalculationEntryValueTwo.setScale(3);

                // Actions for non Bitcoin currencies on secondaryCurrency
            } else if (submitCurrencyChanges.secondaryCurrency != bitcoinBTC &&
                    submitCurrencyChanges.secondaryCurrency != submitCurrencyChanges.defaultCurrency &&
                    (submitCurrencyChanges.entryValueTwo != 0 || submitCurrencyChanges.entryValueTwo != null)) {
                noBitcoinValue = 0;

                soqlEntryCurrencyTwo = [
                        SELECT RateVsBitcoin__c, Currency__c
                        FROM Rate_Code__c
                        WHERE Currency__c = :submitCurrencyChanges.secondaryCurrency
                ];
                soqlEntryCurrencyOne = [
                        SELECT Rate__c, Currency__c
                        FROM Rate_Code__c
                        WHERE Currency__c = :submitCurrencyChanges.defaultCurrency
                ];

                noBitcoinValue = submitCurrencyChanges.entryValueTwo * soqlEntryCurrencyTwo.RateVsBitcoin__c;
                entryValueOne = noBitcoinValue * soqlEntryCurrencyOne.Rate__c.setScale(3);
            }

        } catch (ValidationException e) {
            message = e.getMessage();
            error = true;
        }

        result.put('entryValueOne', entryValueOne);
        result.put('message', message);
        result.put('error', error);
        return result;

    }

    public class SubmitCurrencyChanges {
        @AuraEnabled public Decimal entryValueOne { get; set; }
        @AuraEnabled public Decimal entryValueTwo { get; set; }
        @AuraEnabled public String defaultCurrency { get; set; }
        @AuraEnabled public String secondaryCurrency { get; set; }

    }

}