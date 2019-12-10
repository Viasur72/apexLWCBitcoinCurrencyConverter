/**
 * Created by cnaranjo on 12/9/19.
 */

import { LightningElement, api } from 'lwc';

export default class Errormessage extends LightningElement {

  @api errorMsg;
  @api withoutHeight = false;

  get getClassName () {
    let className = 'message-height';
    if (this.withoutHeight) {
      className = '';
    }
    return className;
  }
}