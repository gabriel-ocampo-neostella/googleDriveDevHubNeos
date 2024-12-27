import { LightningElement, api } from 'lwc';

export default class DisplayErrors extends LightningElement {
    @api errors = []; // Array to hold error messages
    @api title = 'Error(s) occurred'; // Default title
}