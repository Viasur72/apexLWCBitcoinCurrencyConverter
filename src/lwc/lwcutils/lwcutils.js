/**
 * Created by cnaranjo on 12/8/19.
 */

import {ShowToastEvent} from 'lightning/platformShowToastEvent';

/**
 * Display toasts to provide feedback to a user.
 * @param parent    Component from where is called: usually 'this'
 * @param variant   Available options: info(default), success, error, warning
 * @param title     The title of the toast, displayed as a heading.
 * @param message   A string representing the body of the message.
 */
const fireToast = (parent, variant, title, message) => {
  const showToast = new ShowToastEvent({
    title: title,
    message: message,
    variant: variant,
  });
  parent.dispatchEvent(showToast);
};

const getDetailsFromError = (error) => {
  let errorDetails = '';
  if (Array.isArray(error.body)) {
    errorDetails = error.body.map(e => e.message).join(', ');
  } else if (error.body !== undefined && typeof error.body.message === 'string') {
    errorDetails = error.body.message;
  }

  return errorDetails;
};


export { fireToast, getDetailsFromError };