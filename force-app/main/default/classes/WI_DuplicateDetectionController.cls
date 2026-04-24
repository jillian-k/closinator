/**
 * Controller for the Duplicate Work Item Detection LWC.
 *
 * Surfaces open Work Items tied to Cases that share the caller's phone number
 * (matched across any Account with the same Account.Phone), and lets an agent
 * link the current Case to a selected Work Item and close it in one action.
 *
 * Used by: wi_duplicateWorkItemDetector LWC on the Case Lightning Record Page.
 */
public with sharing class WI_DuplicateDetectionController {

    /**
     * Returns open Work Items that belong to any Account whose Phone matches
     * the current Case's Account.Phone, excluding Work Items whose parent Case
     * is the current Case and excluding Work Items or parent Cases already closed.
     *
     * Returns an empty list when the Case has no Account, no Phone, or no matches.
     *
     * @param caseId  Id of the Case the agent is currently viewing.
     * @return  List of WorkItemResult wrappers ordered by CreatedDate DESC, up to 50.
     */
    @AuraEnabled(cacheable=true)
    public static List<WorkItemResult> getRelatedWorkItems(Id caseId) {
        if (caseId == null) {
            return new List<WorkItemResult>();
        }

        List<Case> currentList = [
            SELECT Id, AccountId, Account.Phone
            FROM Case
            WHERE Id = :caseId
            WITH USER_MODE
            LIMIT 1
        ];
        if (currentList.isEmpty()) {
            return new List<WorkItemResult>();
        }
        Case current = currentList[0];
        if (current.AccountId == null || current.Account == null || String.isBlank(current.Account.Phone)) {
            return new List<WorkItemResult>();
        }
        String phone = current.Account.Phone;

        Set<Id> accountIds = new Map<Id, Account>([
            SELECT Id
            FROM Account
            WHERE Phone = :phone
            WITH USER_MODE
        ]).keySet();
        // Note: if accountIds is empty (unusual - the current Case's Account should at least match),
        // the next query's IN :accountIds clause simply returns zero rows, which is the correct
        // outcome. No explicit short-circuit needed.

        List<Work_Item__c> items = [
            SELECT Id, Name, Status__c, Transfer_to_Division__c,
                   RecordType.Name, CreatedDate, High_Priority__c,
                   Case__c, Case__r.CaseNumber, Case__r.AccountId,
                   Case__r.Incoming_Division__c
            FROM Work_Item__c
            WHERE Case__r.AccountId IN :accountIds
              AND Case__c != :caseId
              AND Status__c != 'Closed'
              AND Case__r.Status != 'Closed'
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        List<WorkItemResult> out = new List<WorkItemResult>();
        for (Work_Item__c w : items) {
            out.add(new WorkItemResult(w));
        }
        return out;
    }

    /**
     * Links the current Case to the given Work Item and sets its Status to Closed.
     * Runs in USER_MODE so FLS/CRUD and validation rules are enforced.
     *
     * If a validation rule blocks the update (e.g. a PVL/OCP Case missing Island),
     * the rule's user-facing error message is surfaced via AuraHandledException
     * so the LWC can display it in a toast.
     *
     * @param caseId       Id of the child Case being closed as a duplicate.
     * @param workItemId   Id of the parent Work Item being linked.
     * @return  The linked Work Item's Name (for success toast).
     */
    @AuraEnabled
    public static String linkAndClose(Id caseId, Id workItemId) {
        if (caseId == null || workItemId == null) {
            throw new AuraHandledException('Both Case Id and Work Item Id are required.');
        }
        try {
            Case c = new Case(Id = caseId);
            c.Work_Item__c = workItemId;
            c.Status = 'Closed';
            Database.update(c, AccessLevel.USER_MODE);

            List<Work_Item__c> wList = [
                SELECT Id, Name
                FROM Work_Item__c
                WHERE Id = :workItemId
                WITH USER_MODE
                LIMIT 1
            ];
            return wList.isEmpty() ? null : wList[0].Name;
        } catch (DmlException e) {
            // Surface the validation rule ErrorMessage (e.g. "Please indicate the Island...")
            // cleanly to the LWC as a toast. Any other non-DML exception propagates and
            // Salesforce's AuraEnabled wrapper presents it as a generic error.
            String msg = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * Wire-friendly projection of a Work_Item__c for the LWC.
     * Avoids exposing the full sObject and keeps the shape stable across queries.
     */
    public class WorkItemResult {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String workItemNumber;
        @AuraEnabled public String workItemUrl;
        @AuraEnabled public String division;
        @AuraEnabled public String status;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String parentCaseNumber;
        @AuraEnabled public Id parentCaseId;
        @AuraEnabled public String parentCaseUrl;
        @AuraEnabled public Boolean highPriority;

        public WorkItemResult(Work_Item__c w) {
            this.workItemId = w.Id;
            this.workItemNumber = w.Name;
            this.workItemUrl = '/' + w.Id;
            this.division = (w.RecordType != null && w.RecordType.Name != null)
                ? w.RecordType.Name
                : w.Transfer_to_Division__c;
            this.status = w.Status__c;
            this.createdDate = w.CreatedDate;
            this.parentCaseNumber = (w.Case__r != null) ? w.Case__r.CaseNumber : null;
            this.parentCaseId = w.Case__c;
            this.parentCaseUrl = (w.Case__c != null) ? '/' + w.Case__c : null;
            this.highPriority = w.High_Priority__c;
        }
    }
}
