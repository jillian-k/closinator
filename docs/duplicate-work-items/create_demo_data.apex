// ============================================================
// Duplicate Work Item Detection — Demo Data Setup
// Generates 6 Person Accounts, 7 original parent Cases, 7 Work Items
// (mixed OCP / INS / BREG record types), 6 repeat-call Cases, and
// 1 pre-linked Case in dcca-devcc.
// Safe to re-run: any existing "DEMO-DWI" records are deleted first.
//
// Contact info is spoofed:
//   - phones use 808-888-88XX (obviously fake, matches demo convention)
//   - emails use jillian+devcc+<name>@terranox.co (your inbox + subaddressing,
//     so notification emails from the WI create flow land somewhere real
//     without exposing customer data)
// ============================================================

// --- Tidy up any prior run ---------------------------------------
// Delete order matters: Cases first (because a closed pre-linked Case would
// otherwise hit validation rules on any update), then Work Items (which no
// longer have Case child references blocking them since the Case.Work_Item__c
// lookup is a soft lookup, not master-detail), then Accounts.
List<Case> priorCases = [SELECT Id FROM Case WHERE Subject LIKE 'DEMO-DWI %'];
List<Work_Item__c> priorWIs = [
    SELECT Id FROM Work_Item__c
    WHERE Case__c IN (SELECT Id FROM Case WHERE Subject LIKE 'DEMO-DWI %')
];
if (!priorCases.isEmpty()) delete priorCases;
if (!priorWIs.isEmpty()) delete priorWIs;
List<Account> priorAccts = [SELECT Id FROM Account WHERE LastName = 'DemoDWI'];
if (!priorAccts.isEmpty()) delete priorAccts;

System.debug('Tidy-up complete');

// --- Record type IDs ---------------------------------------------
// Cases use PVL RT (cleanest close — no blocking validation rules).
// Work Items mix OCP / INS / BREG — the only RTs whose Work_Item_Routing__mdt
// rows have a populated Notification_Email_Address__c, so the
// "Work Item: Update Record on Create" flow won't blow up on insert.
// (PVL's routing row has a null email in this sandbox, so PVL WIs are skipped.)
Id personAccountRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
    .get('PersonAccount').getRecordTypeId();
Id pvlCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
    .get('PVL').getRecordTypeId();
Map<String,Schema.RecordTypeInfo> wiRtMap =
    Schema.SObjectType.Work_Item__c.getRecordTypeInfosByDeveloperName();
Id ocpWiRtId  = wiRtMap.get('OCP').getRecordTypeId();
Id insWiRtId  = wiRtMap.get('INS').getRecordTypeId();
Id bregWiRtId = wiRtMap.get('BREG').getRecordTypeId();

// --- 1. Create 6 Person Accounts ---------------------------------
List<Account> accts = new List<Account>{
    new Account(FirstName='Alpha',   LastName='DemoDWI', RecordTypeId=personAccountRtId, PersonEmail='jillian+devcc+alpha@terranox.co',   Phone='808-888-8881'),
    new Account(FirstName='Bravo',   LastName='DemoDWI', RecordTypeId=personAccountRtId, PersonEmail='jillian+devcc+bravo@terranox.co',   Phone='808-888-8882'),
    new Account(FirstName='Charlie', LastName='DemoDWI', RecordTypeId=personAccountRtId, PersonEmail='jillian+devcc+charlie@terranox.co', Phone='808-888-8883'),
    new Account(FirstName='Delta',   LastName='DemoDWI', RecordTypeId=personAccountRtId, PersonEmail='jillian+devcc+delta@terranox.co',   Phone='808-888-8884'),
    new Account(FirstName='Echo',    LastName='DemoDWI', RecordTypeId=personAccountRtId, PersonEmail='jillian+devcc+echo@terranox.co',    Phone='808-888-8885'),
    new Account(FirstName='Foxtrot', LastName='DemoDWI', RecordTypeId=personAccountRtId, PersonEmail='jillian+devcc+foxtrot@terranox.co', Phone='808-888-8899')
};
insert accts;
Map<String,Account> acctByFirstName = new Map<String,Account>();
for (Account a : accts) { acctByFirstName.put(a.FirstName, a); }
System.debug('Accounts created: ' + acctByFirstName.keySet());

// --- 2. Create Original Parent Cases -----------------------------
// Alpha: 1 parent, Bravo: 3 parents (for multi-WI demo), Charlie/Delta/Echo: 1 each.
List<Case> origCases = new List<Case>{
    new Case(AccountId=acctByFirstName.get('Alpha').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Original 1A (Alpha)',        Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Original call from Alpha caller — OCP consumer complaint.'),
    new Case(AccountId=acctByFirstName.get('Bravo').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Original 2A (Bravo — OCP)',   Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='First Bravo issue — OCP consumer complaint.'),
    new Case(AccountId=acctByFirstName.get('Bravo').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Original 2B (Bravo — INS)',   Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Second Bravo issue — INS producer licensing question.'),
    new Case(AccountId=acctByFirstName.get('Bravo').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Original 2C (Bravo — BREG)',  Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Third Bravo issue — BREG business registration question.'),
    new Case(AccountId=acctByFirstName.get('Charlie').Id, RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Original 3A (Charlie — INS)', Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Original call from Charlie caller — INS licensing.'),
    new Case(AccountId=acctByFirstName.get('Delta').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Original 4A (Delta — BREG)',  Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Original call from Delta caller — BREG filing question.'),
    new Case(AccountId=acctByFirstName.get('Echo').Id,    RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Original 5A (Echo — INS)',    Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Original call from Echo caller — INS licensing.')
};
insert origCases;
Map<String,Case> origByKey = new Map<String,Case>();
for (Case c : origCases) { origByKey.put(c.Subject, c); }
System.debug('Original parent Cases created: ' + origCases.size());

// --- 3. Create Work Items (one per original Case) ----------------
// OwnerId set explicitly because the "Work Item: Update Record on Create"
// after-create flow needs a non-blank owner at insert.
// INS WIs set INS_Branch__c='Licensing' so the flow's routing lookup resolves
// to the INS_Licensing mdt row (which has a valid notification email).
// OCP and BREG routing rows have Branch__c = null, so no branch is required.
// Across all 7 WIs the LWC's Division column will show OCP, INS, and BREG —
// PVL WIs are intentionally absent because PVL routing has no notification
// email configured in this sandbox.
Id runningUserId = UserInfo.getUserId();
List<Work_Item__c> wis = new List<Work_Item__c>{
    new Work_Item__c(OwnerId=runningUserId, Case__c=origByKey.get('DEMO-DWI Original 1A (Alpha)').Id,        RecordTypeId=ocpWiRtId,  Status__c='New',         High_Priority__c=false, Transfer_to_Division__c='OCP'),
    new Work_Item__c(OwnerId=runningUserId, Case__c=origByKey.get('DEMO-DWI Original 2A (Bravo — OCP)').Id,  RecordTypeId=ocpWiRtId,  Status__c='New',         High_Priority__c=false, Transfer_to_Division__c='OCP'),
    new Work_Item__c(OwnerId=runningUserId, Case__c=origByKey.get('DEMO-DWI Original 2B (Bravo — INS)').Id,  RecordTypeId=insWiRtId,  Status__c='In-Progress', High_Priority__c=true,  Transfer_to_Division__c='INS',  INS_Branch__c='Licensing'),
    new Work_Item__c(OwnerId=runningUserId, Case__c=origByKey.get('DEMO-DWI Original 2C (Bravo — BREG)').Id, RecordTypeId=bregWiRtId, Status__c='New',         High_Priority__c=false, Transfer_to_Division__c='BREG'),
    new Work_Item__c(OwnerId=runningUserId, Case__c=origByKey.get('DEMO-DWI Original 3A (Charlie — INS)').Id,RecordTypeId=insWiRtId,  Status__c='New',         High_Priority__c=false, Transfer_to_Division__c='INS',  INS_Branch__c='Licensing'),
    new Work_Item__c(OwnerId=runningUserId, Case__c=origByKey.get('DEMO-DWI Original 4A (Delta — BREG)').Id, RecordTypeId=bregWiRtId, Status__c='In-Progress', High_Priority__c=false, Transfer_to_Division__c='BREG'),
    new Work_Item__c(OwnerId=runningUserId, Case__c=origByKey.get('DEMO-DWI Original 5A (Echo — INS)').Id,   RecordTypeId=insWiRtId,  Status__c='New',         High_Priority__c=true,  Transfer_to_Division__c='INS',  INS_Branch__c='Licensing')
};
insert wis;
wis = [SELECT Id, Name, Case__c, Case__r.Subject, Transfer_to_Division__c, RecordType.Name, Status__c FROM Work_Item__c WHERE Id IN :wis ORDER BY CreatedDate];
Map<String,Work_Item__c> wiByParentSubject = new Map<String,Work_Item__c>();
for (Work_Item__c w : wis) { wiByParentSubject.put(w.Case__r.Subject, w); }
System.debug('Work Items created: ' + wis.size());

// --- 4. Create Repeat-Call Child Cases ---------------------------
// These are the Cases the agent opens at demo time. NOT yet linked.
List<Case> repeatCases = new List<Case>{
    new Case(AccountId=acctByFirstName.get('Alpha').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Repeat Call — Alpha (single match)',   Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Alpha calls back about the same issue as Original 1A.'),
    new Case(AccountId=acctByFirstName.get('Bravo').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Repeat Call — Bravo (MULTI match)',    Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Bravo calls back; agent must pick the correct WI from three matches spanning OCP, INS, and BREG.'),
    new Case(AccountId=acctByFirstName.get('Charlie').Id, RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Repeat Call — Charlie (single match)', Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Charlie calls back about the same issue as Original 3A.'),
    new Case(AccountId=acctByFirstName.get('Delta').Id,   RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Repeat Call — Delta (single match)',   Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Delta calls back about the same issue as Original 4A.'),
    new Case(AccountId=acctByFirstName.get('Echo').Id,    RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Repeat Call — Echo (single match)',    Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Echo calls back about the same issue as Original 5A.'),
    new Case(AccountId=acctByFirstName.get('Foxtrot').Id, RecordTypeId=pvlCaseRtId, Subject='DEMO-DWI Repeat Call — Foxtrot (NO match)',     Status='New', Origin='Phone', Incoming_Division__c='PVL', Description='Foxtrot — no prior Work Items exist; demos the empty state.')
};
insert repeatCases;
Map<String,Case> repeatByKey = new Map<String,Case>();
for (Case c : repeatCases) { repeatByKey.put(c.Subject, c); }
System.debug('Repeat-call Cases created: ' + repeatCases.size());

// --- 5. Pre-linked bonus Case (demonstrates linked-state view) ----
// Use Echo's WI for the pre-link so Echo's main repeat demo still works
// on the open Echo WI (just via a different Case).
Case preLinked = new Case(
    AccountId = acctByFirstName.get('Echo').Id,
    RecordTypeId = pvlCaseRtId,
    Subject = 'DEMO-DWI Already Linked (Echo)',
    Status = 'Closed',
    Origin = 'Phone',
    Incoming_Division__c = 'PVL',
    Description = 'Pre-closed and linked Case used to demo the LWC linked-state card.',
    Work_Item__c = wiByParentSubject.get('DEMO-DWI Original 5A (Echo — INS)').Id
);
insert preLinked;
System.debug('Pre-linked Case created: ' + preLinked.Id);

// --- 6. Final summary (easy to grep from debug log) --------------
System.debug('========= DEMO DATA SUMMARY =========');
for (Account a : [SELECT Id, FirstName, LastName, Phone, PersonEmail FROM Account WHERE Id IN :accts ORDER BY FirstName]) {
    System.debug('ACCT|' + a.FirstName + '|' + a.Phone + '|' + a.PersonEmail + '|' + a.Id);
}
for (Case c : [SELECT Id, CaseNumber, Subject, AccountId, Status, Work_Item__c FROM Case WHERE Id IN :origCases ORDER BY Subject]) {
    System.debug('ORIG_CASE|' + c.Subject + '|' + c.CaseNumber + '|' + c.Id);
}
for (Work_Item__c w : [SELECT Id, Name, Case__r.Subject, Status__c, High_Priority__c, RecordType.Name, Transfer_to_Division__c, INS_Branch__c FROM Work_Item__c WHERE Id IN :wis ORDER BY Name]) {
    System.debug('WI|' + w.Name + '|' + w.Case__r.Subject + '|' + w.Status__c + '|HP=' + w.High_Priority__c + '|RT=' + w.RecordType.Name + '|Branch=' + w.INS_Branch__c + '|' + w.Id);
}
for (Case c : [SELECT Id, CaseNumber, Subject FROM Case WHERE Id IN :repeatCases ORDER BY Subject]) {
    System.debug('REPEAT_CASE|' + c.Subject + '|' + c.CaseNumber + '|' + c.Id);
}
Case preLinkedRead = [SELECT Id, CaseNumber, Subject, Work_Item__c, Work_Item__r.Name FROM Case WHERE Id = :preLinked.Id];
System.debug('PRELINKED|' + preLinkedRead.Subject + '|' + preLinkedRead.CaseNumber + '|' + preLinkedRead.Id + '|linked to WI:' + preLinkedRead.Work_Item__r.Name);
System.debug('=====================================');
