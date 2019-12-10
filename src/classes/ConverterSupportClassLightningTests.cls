/**
 * Created by cnaranjo on 12/10/19.
 */
@IsTest
private class ConverterSupportClassLightningTests {

    // Testing HTTP Get call out
    @IsTest static void runTestCalloutWithStaticResources() {

        // Given
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        mock.setStaticResource('converterMockResponse1');
        mock.setStatusCode(200);
        mock.setHeader('Content-Type', 'application/json');
        Rate_Code__c rate;
        String secondaryCurrency = 'US Dollar (USD)';

        Rate_Code__c rateUS = new Rate_Code__c();
        rateUS.Name = 'US Dollar';
        rateUS.Rate__c = 7231.12;
        rateUS.Currency__c = 'US Dollar (USD)';
        rateUS.Code__c = 'USD';
        insert rateUS;

        rate = [
                SELECT Rate__c, Currency__c
                FROM Rate_Code__c
                WHERE Currency__c = :secondaryCurrency
                LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        Map<String, Object> result = ConverterSupportClassLightning.makeHTTPCall();
        Integer callouts = Limits.getCallouts();
        Test.stopTest();

        // Then
        System.assert(!(Boolean) result.get('error'), 'Error flag not set correctly');
        System.assertEquals(1, callouts, 'The method should make a callout');

    }

    @IsTest static void runTestCalloutToUpdateAndInsertNewCodes() {

        // Given
        List<Rate_Code__c> rcList = TestDataCurrencyConverterCalloutClass.TestRateCodeRecordsInserted();
        System.assertEquals(4, rcList.size());

        StaticResourceCalloutMock mock2 = new StaticResourceCalloutMock();

        // The converterMockResponse2 contains six new code records. Four are already saved in database
        mock2.setStaticResource('converterMockResponse2');
        mock2.setStatusCode(200);
        mock2.setHeader('Content-Type', 'application/json');

        Test.setMock(HttpCalloutMock.class, mock2);

        // When
        Test.startTest();
        Map<String, Object> result = ConverterSupportClassLightning.makeHTTPCall();
        List<Rate_Code__c> inSystemRateCodes = [SELECT Id FROM Rate_Code__c];
        System.debug(inSystemRateCodes.size());

        String responseBody = '[{"code":"BTC","name":"Bitcoin","rate":1},{"code":"VND","name":"Vietnamese Dong","rate":164.776528},{"code":"AFN","name":"Afghan Afghani","rate":496.79773},{"code":"BCH","name":"Bitcoin Cash","rate":12.763562},{"code":"USD","name":"US Dollar","rate":6531.37},{"code":"EUR","name":"Eurozone Euro","rate":5690.07}]';
        List<Codes> restCode = (List<Codes>) JSON.deserialize(responseBody, List<Codes>.class);
        System.debug(restCode.size());

        // We had four rate_Code__c records inserted in database, checking if we have six after second HTTP call
        System.assertEquals(6, restCode.size());
        System.debug(restCode);

        // Updating rate_Code__c record with negative input. Code__c is mandatory
        List<Rate_Code__c> rcListToUpdate = new List<Rate_Code__c>();
        Rate_Code__c rcToUpdate = rcList[3];
        System.debug('Rate Code code on rcList: ' + rcList[3].Code__c);

        rcToUpdate.Code__c = null;
        rcListToUpdate.add(rcToUpdate);

        System.debug('rcListToUpdate size: -------------->' + rcListToUpdate.size());

        try {
            if ((!rcListToUpdate.isEmpty()) && (rcListToUpdate.size() > 0)) {
                update rcListToUpdate;
            }

        } catch (DmlException e) {
            System.debug('The following exception has occurred when insert Rate Code records: ' + e.getMessage());
            System.assert(e.getMessage().contains('Required fields are missing'), 'Update did not fire');
        }

        Test.stopTest();

        // Then
        System.assert(!(Boolean) result.get('error'), 'Error flag not set correctly');
    }

    @IsTest static void runTestCalloutNegativeInsertJSON() {

        // Given
        List<Rate_Code__c> rcList = TestDataCurrencyConverterCalloutClass.TestRateCodeRecordsInserted();
        StaticResourceCalloutMock mock3 = new StaticResourceCalloutMock();

        // The converterMockResponse2 contains six new code records. Four are already saved in database
        mock3.setStaticResource('converterMockResponse2');
        mock3.setStatusCode(200);
        mock3.setHeader('Content-Type', 'application/json');

        Test.setMock(HttpCalloutMock.class, mock3);

        // When
        Test.startTest();
        Map<String, Object> result = ConverterSupportClassLightning.makeHTTPCall();
        String responseBody = '[{"code":"","name":"New Zealand Dollar","rate":10159.894353}]';
        List<Codes> restCode = (List<Codes>) JSON.deserialize(responseBody, List<Codes>.class);

        // Trying to insert a new Rate_Code__c record with missing Code__c
        List<Rate_Code__c> codesList = new List<Rate_Code__c>();
        Set<String> theIncomingKeysToInsert = new Set<String>();

        for (Integer i = 0; i < restCode.size(); i++) {
            theIncomingKeysToInsert.add(restCode[i].code);
        }

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

        try {
            if (!newRateCodesToInsert.isEmpty() && (newRateCodesToInsert.size() > 0)) {
                insert newRateCodesToInsert;
            }
        } catch (DmlException e) {
            System.debug('The following exception has occurred when inserting Rate Code records: ' + e.getMessage());

            // Assert that the error has been fired
            System.assert(e.getMessage().contains('Insert failed.'), 'Insert did not fire');

        }

        Test.stopTest();

        // Then
        // Initially we had four records coming from the rcList and it should remain the same amount
        System.debug('It should remain four records after trying to insert missing data from JSON: ' + rcList.size() + 'records in database');
        System.assertEquals(4, rcList.size(), 'Wrong number of records');
        System.assertEquals(1, restCode.size(), 'Wrong number of records');
    }

    @IsTest static void runTestDefaultCurrencyEntryChangesDefaultCurrencyBitcoin() {

        // Given
        List<Rate_Code__c> rcList = TestDataCurrencyConverterCalloutClass.TestRateCodeRecordsInserted();
        ConverterSupportClassLightning.SubmitCurrencyChanges submitCurrencyChanges = new ConverterSupportClassLightning.SubmitCurrencyChanges();
        submitCurrencyChanges.entryValueOne = 1;
        submitCurrencyChanges.entryValueTwo = 0;
        submitCurrencyChanges.defaultCurrency = rcList[1].Currency__c;
        submitCurrencyChanges.secondaryCurrency = rcList[2].Currency__c;

        // When
        Test.startTest();
        Map<String, Object> result = ConverterSupportClassLightning.defaultCurrencyEntryChanges(submitCurrencyChanges);
        Test.stopTest();

        // Then
        System.assert(!(Boolean) result.get('error'), 'Error flag not set correctly');
        System.assertNotEquals(null, result.get('entryValueTwo'), 'entryValueTwo should not be null');
    }

    @IsTest static void runTestDefaultCurrencyEntryChangesDefaultCurrencyNotBitcoin() {

        // Given
        List<Rate_Code__c> rcList = TestDataCurrencyConverterCalloutClass.TestRateCodeRecordsInserted();
        ConverterSupportClassLightning.SubmitCurrencyChanges submitCurrencyChanges = new ConverterSupportClassLightning.SubmitCurrencyChanges();
        submitCurrencyChanges.entryValueOne = 1;
        submitCurrencyChanges.entryValueTwo = 0;
        submitCurrencyChanges.defaultCurrency = rcList[0].Currency__c;
        submitCurrencyChanges.secondaryCurrency = rcList[2].Currency__c;

        // When
        Test.startTest();
        Map<String, Object> result = ConverterSupportClassLightning.defaultCurrencyEntryChanges(submitCurrencyChanges);
        Test.stopTest();

        // Then
        System.assert(!(Boolean) result.get('error'), 'Error flag not set correctly');
        System.assertNotEquals(null, result.get('entryValueTwo'), 'entryValueTwo should not be null');
    }

    @IsTest static void runTestSecondaryCurrencyEntryChangesDefaultCurrencyBitcoin() {

        // Given
        List<Rate_Code__c> rcList = TestDataCurrencyConverterCalloutClass.TestRateCodeRecordsInserted();
        ConverterSupportClassLightning.SubmitCurrencyChanges submitCurrencyChanges = new ConverterSupportClassLightning.SubmitCurrencyChanges();
        submitCurrencyChanges.entryValueOne = 1;
        submitCurrencyChanges.entryValueTwo = 0;
        submitCurrencyChanges.defaultCurrency = rcList[2].Currency__c;
        submitCurrencyChanges.secondaryCurrency = rcList[1].Currency__c;

        // When
        Test.startTest();
        Map<String, Object> result = ConverterSupportClassLightning.secondaryCurrencyEntryChanges(submitCurrencyChanges);
        Test.stopTest();

        // Then
        System.assert(!(Boolean) result.get('error'), 'Error flag not set correctly');
        System.assertNotEquals(null, result.get('entryValueOne'), 'entryValueOne should not be null');
    }

    @IsTest static void runTestSecondaryCurrencyEntryChangesDefaultCurrencyNotBitcoin() {

        // Given
        List<Rate_Code__c> rcList = TestDataCurrencyConverterCalloutClass.TestRateCodeRecordsInserted();
        ConverterSupportClassLightning.SubmitCurrencyChanges submitCurrencyChanges = new ConverterSupportClassLightning.SubmitCurrencyChanges();
        submitCurrencyChanges.entryValueOne = 1;
        submitCurrencyChanges.entryValueTwo = 0;
        submitCurrencyChanges.defaultCurrency = rcList[0].Currency__c;
        submitCurrencyChanges.secondaryCurrency = rcList[2].Currency__c;

        // When
        Test.startTest();
        Map<String, Object> result = ConverterSupportClassLightning.secondaryCurrencyEntryChanges(submitCurrencyChanges);
        Test.stopTest();

        // Then
        System.assert(!(Boolean) result.get('error'), 'Error flag not set correctly');
        System.assertNotEquals(null, result.get('entryValueOne'), 'entryValueOne should not be null');
    }

}