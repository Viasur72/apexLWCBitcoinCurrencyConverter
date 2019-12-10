/**
 * Created by cnaranjo on 12/7/19.
 */

import { LightningElement, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { fireToast } from 'c/lwcutils';

// images
import bitcoinBackgroundUrl from '@salesforce/resourceUrl/bitcoinBackground_small';

// apex methods
import apexMakeHTTPCall from '@salesforce/apex/ConverterSupportClassLightning.makeHTTPCall';
import apexDefaultCurrencyEntryChanges
  from '@salesforce/apex/ConverterSupportClassLightning.defaultCurrencyEntryChanges';
import apexSecondaryCurrencyEntryChanges
  from '@salesforce/apex/ConverterSupportClassLightning.secondaryCurrencyEntryChanges';

// SObject
import RATE_CODE_OBJECT from '@salesforce/schema/Rate_Code__c';

// picklist fields
import CURRENCY_FIELD from '@salesforce/schema/Rate_Code__c.Currency__c';

export default class Convertersupportlightning extends LightningElement {
  @track currencyOptionsOne;                         // picklist values
  @track currencyOptionsTwo;                         // picklist values
  @track showspinner = false;
  @track defaultCurrency = 'Bitcoin (BTC)';
  @track secondaryCurrency = 'US Dollar (USD)';
  @track entryValueOne;
  @track entryValueTwo;
  @track errorMessage;

  get backgroundStyle () {
    return `height:10rem;background-image:url(${bitcoinBackgroundUrl});background-repeat: no-repeat;`;
  }

  connectedCallback () {
    apexMakeHTTPCall()
      .then(result => {
        if (result['errors']) {
          fireToast(this, 'error', 'Error', result['message']);
        } else {
          this.entryValueOne = result['entryValueOne'];
          this.entryValueTwo = result['entryValueTwo'];
        }
      })
      .catch(error => {
        console.log('Error: ' + error.message);
      });
  }

  @wire(getObjectInfo, { objectApiName: RATE_CODE_OBJECT })
  handleResult ({ error, data }) {
    if (data) {
      this.rtId = data.defaultRecordTypeId;
    }
  }

  @wire(getPicklistValues, { recordTypeId: '$rtId', fieldApiName: CURRENCY_FIELD })
  getPicklistStageName ({ error, data }) {
    if (data) {
      this.currencyOptionsOne = data.values;
      this.currencyOptionsTwo = data.values;
    }
  }

  defaultCurrencyEntryChange (event) {
    let submitCurrencyChanges = {};

    if (event.target.name === 'selectCurrencyOne') {
      this.defaultCurrency = event.target.value;
    }
    if (event.target.name === 'entryValueOne') {
      this.entryValueOne = event.target.value;
    }
    if (!this.entryValueOne) {
      this.setError('Please insert an amount to obtain a rate');
    } else {
      this.clearErrors();
      let spinner = this.template.querySelector('c-lwcspinner');
      spinner.openSpinner();

      submitCurrencyChanges.entryValueOne = this.entryValueOne;
      submitCurrencyChanges.entryValueTwo = this.entryValueTwo ? this.entryValueTwo : 0;
      submitCurrencyChanges.defaultCurrency = this.defaultCurrency;
      submitCurrencyChanges.secondaryCurrency = this.secondaryCurrency;

      apexDefaultCurrencyEntryChanges({
        submitCurrencyChanges: submitCurrencyChanges
      })
        .then(result => {
          if (result['error']) {
            fireToast(this, 'error', 'Error', result['message']);
          } else {
            this.entryValueTwo = result['entryValueTwo'];
          }
        })
        .catch(error => {
          fireToast(this, 'error', 'Error', 'Something Wrong');
        })
        .finally(() => {
          spinner.closeSpinner();
        });
    }
  }

  secondaryCurrencyEntryChange (event) {
    let submitCurrencyChanges = {};

    if (event.target.name === 'selectCurrencyTwo') {
      this.secondaryCurrency = event.target.value;
    }
    if (event.target.name === 'entryValueTwo') {
      this.entryValueTwo = event.target.value;
    }

    if (!this.entryValueTwo) {
      this.setError('Please insert an amount to obtain a rate');
    } else {
      this.clearErrors();
      let spinner = this.template.querySelector('c-lwcspinner');
      spinner.openSpinner();

      submitCurrencyChanges.entryValueOne = this.entryValueOne ? this.entryValueOne : 0;
      submitCurrencyChanges.entryValueTwo = this.entryValueTwo;
      submitCurrencyChanges.defaultCurrency = this.defaultCurrency;
      submitCurrencyChanges.secondaryCurrency = this.secondaryCurrency;

      apexSecondaryCurrencyEntryChanges({
        submitCurrencyChanges: submitCurrencyChanges
      })
        .then(result => {
          if (result['error']) {
            fireToast(this, 'error', 'Error', result['message']);
          } else {
            this.entryValueOne = result['entryValueOne'];
          }
        })
        .catch(error => {
          fireToast(this, 'error', 'Error', 'Something Wrong');
        })
        .finally(() => {
          spinner.closeSpinner();
        });
    }
  }

  setError (message) {
    this.errorMessage = message;
  }

  clearErrors () {
    this.errorMessage = undefined;
  }

}