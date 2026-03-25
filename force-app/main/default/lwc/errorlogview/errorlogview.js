import { LightningElement, wire } from 'lwc';
import getErrorLogs from '@salesforce/apex/ErrorLogControllerV1.getErrorLogs';

const columns = [
    {
        label: 'Time',
        fieldName: 'RequestDateTime__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Class', fieldName: 'ApexClass__c' },
    { label: 'Error Code', fieldName: 'ErrorCode__c' },
    {
        label: 'Message',
        fieldName: 'ErrorMessage__c',
        wrapText: true
    },
    {
        type: 'button',
        typeAttributes: {
            label: 'Detail',
            name: 'detail',
            variant: 'base'
        }
    }
];

export default class Errorlogview extends LightningElement {

    columns = columns;
    logs = [];
    selectedLog;

    //  class property 로 선언
    fromDt = new Date(Date.now() - 24 * 60 * 60 * 1000);
    toDt = new Date();
    status = null;
    limitSize = 50;

    @wire(getErrorLogs, {
        fromDt: '$fromDt',
        toDt: '$toDt',
        status: '$status',
        limitSize: '$limitSize'
    })
    wiredLogs({ data, error }) {
        if (data) {
            this.logs = data;
        } else if (error) {
            console.error('Error loading logs', error);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'detail') {
            this.selectedLog = row;
        }
    }

    closeModal() {
        this.selectedLog = null;
    }
}