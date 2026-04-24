import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getRelatedWorkItems from '@salesforce/apex/WI_DuplicateDetectionController.getRelatedWorkItems';
import linkAndClose from '@salesforce/apex/WI_DuplicateDetectionController.linkAndClose';

import CASE_WI_ID_FIELD from '@salesforce/schema/Case.Work_Item__c';
import CASE_WI_NAME_FIELD from '@salesforce/schema/Case.Work_Item__r.Name';
import CASE_WI_STATUS_FIELD from '@salesforce/schema/Case.Work_Item__r.Status__c';
import CASE_WI_PARENT_ID_FIELD from '@salesforce/schema/Case.Work_Item__r.Case__c';
import CASE_WI_PARENT_NUMBER_FIELD from '@salesforce/schema/Case.Work_Item__r.Case__r.CaseNumber';

const CASE_FIELDS = [
    CASE_WI_ID_FIELD,
    CASE_WI_NAME_FIELD,
    CASE_WI_STATUS_FIELD,
    CASE_WI_PARENT_ID_FIELD,
    CASE_WI_PARENT_NUMBER_FIELD
];

const COLUMNS = [
    {
        label: 'Work Item',
        fieldName: 'workItemUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'workItemNumber' }, target: '_blank' },
        initialWidth: 140
    },
    { label: 'Division', fieldName: 'division', type: 'text', initialWidth: 120 },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 110 },
    {
        label: 'Parent Case',
        fieldName: 'parentCaseUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'parentCaseNumber' }, target: '_blank' },
        initialWidth: 140
    },
    {
        label: 'High Priority',
        fieldName: 'highPriority',
        type: 'boolean',
        initialWidth: 110,
        cellAttributes: { alignment: 'center' }
    },
    { label: 'Created', fieldName: 'createdDate', type: 'date', initialWidth: 150 }
];

export default class WiDuplicateWorkItemDetector extends NavigationMixin(LightningElement) {
    @api recordId;

    columns = COLUMNS;
    workItems = [];
    selectedRowIds = [];
    selectedRow = null;
    isLinking = false;
    errorMessage = '';

    wiredResult;
    caseRecord;

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase(result) {
        if (result.data) {
            this.caseRecord = result.data;
        }
    }

    @wire(getRelatedWorkItems, { caseId: '$recordId' })
    wiredWorkItems(result) {
        this.wiredResult = result;
        if (result.data) {
            this.workItems = result.data;
            this.errorMessage = '';
        } else if (result.error) {
            this.workItems = [];
            this.errorMessage = this.extractErrorMessage(result.error);
        }
    }

    // --- Linked-state getters (populated when Case.Work_Item__c is already set) ---

    get linkedWorkItemId() {
        return this.caseRecord ? getFieldValue(this.caseRecord, CASE_WI_ID_FIELD) : null;
    }
    get linkedWorkItemName() {
        return this.caseRecord ? getFieldValue(this.caseRecord, CASE_WI_NAME_FIELD) : null;
    }
    get linkedWorkItemStatus() {
        return this.caseRecord ? getFieldValue(this.caseRecord, CASE_WI_STATUS_FIELD) : null;
    }
    get linkedParentCaseId() {
        return this.caseRecord ? getFieldValue(this.caseRecord, CASE_WI_PARENT_ID_FIELD) : null;
    }
    get linkedParentCaseNumber() {
        return this.caseRecord ? getFieldValue(this.caseRecord, CASE_WI_PARENT_NUMBER_FIELD) : null;
    }
    get linkedWorkItemUrl() {
        return this.linkedWorkItemId ? '/' + this.linkedWorkItemId : null;
    }
    get linkedParentCaseUrl() {
        return this.linkedParentCaseId ? '/' + this.linkedParentCaseId : null;
    }

    get isAlreadyLinked() {
        return !!this.linkedWorkItemId;
    }

    get cardTitle() {
        return this.isAlreadyLinked ? 'Linked Work Item' : 'Related Work Items';
    }

    get showRefreshButton() {
        return !this.isAlreadyLinked;
    }

    // --- Detection-state getters ---

    get isLoading() {
        return (
            this.isLinking ||
            !this.wiredResult ||
            (this.wiredResult.data === undefined && this.wiredResult.error === undefined)
        );
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get hasNoMatches() {
        return !this.isLoading && !this.hasError && this.workItems.length === 0;
    }

    get linkDisabled() {
        return !this.selectedRow || this.isLinking;
    }

    get hideCheckbox() {
        return false;
    }

    // --- Event handlers ---

    handleRowSelection(event) {
        const selected = event.detail.selectedRows;
        this.selectedRow = selected && selected.length ? selected[0] : null;
        this.selectedRowIds = this.selectedRow ? [this.selectedRow.workItemId] : [];
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    async handleLinkAndClose() {
        if (!this.selectedRow) return;
        const selectedWorkItemId = this.selectedRow.workItemId;
        const selectedParentCaseId = this.selectedRow.parentCaseId;
        const selectedParentCaseNumber = this.selectedRow.parentCaseNumber;

        this.isLinking = true;
        try {
            const workItemName = await linkAndClose({
                caseId: this.recordId,
                workItemId: selectedWorkItemId
            });

            const messageData = [{ url: '/' + selectedWorkItemId, label: workItemName }];
            let message = 'Linked to Work Item {0} and closed this Case.';
            if (selectedParentCaseId && selectedParentCaseNumber) {
                messageData.push({ url: '/' + selectedParentCaseId, label: selectedParentCaseNumber });
                message =
                    'Linked to Work Item {0} (original Case {1}) and closed this Case.';
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Case Closed',
                    message,
                    messageData,
                    variant: 'success',
                    mode: 'sticky'
                })
            );

            // Refresh record page so Status + Work Item lookup reflect the change;
            // this also refreshes our getRecord wire, which flips the LWC into its
            // linked state so the agent keeps one-click access to the Work Item
            // and original Case after the Case is closed.
            getRecordNotifyChange([{ recordId: this.recordId }]);
            if (this.wiredResult) {
                refreshApex(this.wiredResult);
            }
            this.selectedRow = null;
            this.selectedRowIds = [];
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to Close Case',
                    message: this.extractErrorMessage(error),
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isLinking = false;
        }
    }

    extractErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body) {
            if (typeof error.body.message === 'string') return error.body.message;
            if (Array.isArray(error.body)) {
                return error.body.map((e) => e.message).join(', ');
            }
            if (error.body.output && Array.isArray(error.body.output.errors)) {
                return error.body.output.errors.map((e) => e.message).join(', ');
            }
        }
        return error.message || 'Unknown error';
    }
}
