import {LightningElement, api} from 'lwc';

export default class Lwcspinner extends LightningElement {

  @api showspinner = false;

  @api
  openSpinner() {
    this.showspinner = true;
  }

  @api
  closeSpinner() {
    this.showspinner = false;
  }
}