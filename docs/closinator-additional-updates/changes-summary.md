# Closinator Additional Updates — Changes Summary

**Date:** April 9–14, 2026
**Branch:** `closinator-additional-updates`
**Org:** dcca-devcc (Sandbox)
**Test Results:** 100% passing

---

## Overview

This changeset fixes silent failures in the Closinator's rule evaluation system where admin-configured fields appeared functional but were silently ignored due to missing fields in the batch query. It also removes a non-functional UI field and improves help text across the CMDT configuration.

---

## Changes by File

### Apex Classes

**`util_closer_RuleEngine.cls`**
- Added `extractFilterFields(List<util_closer_Case_Status_Rule__mdt>)` — scans all rules' `Additional_Filter_Logic__c` values, parses field names, validates them against the Case object schema, and returns the set of additional fields needed in the batch query.
- Added `extractFieldNameFromCondition(String)` — helper that extracts the field API name from a single filter condition string.

**`util_closer_CaseStatusBatch.cls`**
- Modified `start()` to call `extractFilterFields()` before querying. If additional fields are found, it uses the two-arg `queryCasesByStatus()` overload to include them in the SOQL SELECT. This fixes `Additional_Filter_Logic__c` for any valid Case field.

**`util_closer_RuleEngine_Test.cls`**
- Added 13 new test methods covering `extractFilterFields` (valid fields, base query fields, invalid fields, relationship fields, multiple rules, empty rules, no filter logic) and `extractFieldNameFromCondition` (equals, NOT IN, custom fields, relationship fields, blank, null).

**`util_closer_CaseDataAccess.cls`**
- Added `RecordType.DeveloperName` to the static batch query in `queryCasesByStatus(Set<String>)`. This fixes record type inclusion/exclusion filters that were previously silently skipped.
- Aligned the base field set in `queryCasesByStatus(Set<String>, Set<String>)` to include `CaseNumber`, `Origin`, `Owner.Name`, `LastModifiedBy.Name`, and `RecordType.DeveloperName` — matching the one-arg method.
- Same alignment applied to `queryCasesWithCustomWhere(String, Set<String>)`.

**`util_closer_RuleViewerController.cls`**
- Removed `stopProcessing` from the rule data map sent to the LWC. The field is non-functional and no longer displayed.

**`util_closer_RuleViewerController_Test.cls`**
- Removed the `stopProcessing` assertion from `testGetActiveRules_VerifyAllFieldMapping` to match the controller change.

**`util_closer_CaseStatusBatch_Test.cls`**
- Added 8 batch-level integration tests covering the full pipeline for `Additional_Filter_Logic__c` (matching, non-matching, multiple conditions, null field, invalid field) and `Record_Type_Developer_Names__c` (inclusion, exclusion, combined with other filters). These tests verify end-to-end from batch start through field extraction, query execution, rule evaluation, and case status update.

### LWC

**`util_closer_RuleViewer.html`**
- Removed the `Stop Processing: Yes` display block that was conditionally rendered when `rule.stopProcessing` was true.

### Custom Metadata Type Fields

**`Additional_Filter_Logic__c`**
- Updated description and help text to clarify: filters on Case fields only, not child object fields. Directs admins to the Child Record Criteria section for child filtering. Documents that any valid Case field API name can be used and fields are automatically added to the batch query at runtime.

**`Days_Since_Last_Activity__c`**
- Updated description and help text to clarify that the field uses `LastActivityDate` (Tasks/Events, not `LastModifiedDate`) and requires Activities to be enabled on the Case object.

**`Record_Type_Developer_Names__c`**
- Updated description and help text to specify Developer Name (not display label), semicolon separator, and how to find Developer Names in Setup.

**`Exclude_Record_Type_Developer_Names__c`**
- Same updates as `Record_Type_Developer_Names__c`.

**`Child_Filter_Operator__c`**
- Updated description and help text to document that Equals is case-sensitive and Contains is case-insensitive, with examples.

**`Stop_Processing__c`**
- Updated description and help text to note the field is non-functional. The engine always uses first-match-wins.

### Layout

**`util_closer_Case_Status_Rule__mdt-Case Status Rule Layout`**
- Removed `Stop_Processing__c` from the Rule Information section.
- Renamed "Advanced Filtering" section to "Additional Case Filters" to clarify it applies to Case fields only.

### List Views

**`All_Rules`** and **`Active_Rules`**
- Removed `Stop_Processing__c` column from both list views.

### Documentation

**`outstanding-issues-analysis.md`**
- Updated with org-validated findings from April 9, 2026.
- Corrected Issue 2 status: `LastActivityDate` does not exist on Case in dcca-devcc (Activities not enabled), so the fix is blocked at the org level.
- Marked Issues 1, 3, 4, and 5 as fixed. Issue 1 (Additional Filter Logic) fixed via dynamic field extraction on April 13, 2026.

---

## Known Limitations

- **Unrecognized filter syntax silently passes** — If `Additional_Filter_Logic__c` contains a condition that doesn't match any supported pattern (e.g., `>`, `<`, `>=`, `BETWEEN`, or relationship field notation like `Owner.Name`), the condition is treated as met and the case passes the filter. This means a malformed condition could cause a rule to match *more* cases than intended, not fewer. This is pre-existing behavior (line 945 of `util_closer_RuleEngine.cls`) and was not changed in this release. Fields that don't exist on the Case object are validated and logged, but syntax errors in otherwise valid patterns are not caught.
- **OR logic not supported** — `Additional_Filter_Logic__c` splits conditions by `AND` only. Any `OR` in a condition string will be treated as part of a single condition and likely fail to match a pattern, falling into the "silently passes" behavior above.

---

## What Was NOT Changed

- **`Stop_Processing__c` field definition** — Not deleted. The field remains on the CMDT object for backward compatibility; only removed from visible UI surfaces.

---

## Issue Status After Changes

| Issue | Field | Status |
|---|---|---|
| 1. Additional Filter Logic limited by batch query | `Additional_Filter_Logic__c` | Fixed — dynamic field extraction adds referenced fields to query at runtime |
| 2. Days Since Last Activity silently ignored | `Days_Since_Last_Activity__c` | Blocked — `LastActivityDate` not on Case in this org |
| 3. Record Type filters silently ignored | `Record_Type_Developer_Names__c`, `Exclude_Record_Type_Developer_Names__c` | Fixed |
| 4. Stop Processing does nothing | `Stop_Processing__c` | Fixed — removed from UI |
| 5. Insufficient help text | 5 fields | Fixed |

---

## Test Coverage (Closinator Classes)

| Class | Coverage |
|---|---|
| util_closer_BatchMetrics | 100% |
| util_closer_BatchLogService | 100% |
| util_closer_CaseStatusScheduler | 100% |
| util_closer_Logger | 100% |
| util_closer_LogDataAccess | 100% |
| util_closer_RuleViewerController | 100% |
| util_closer_LogViewerController | 98% |
| util_closer_NotificationService | 96% |
| util_closer_CaseLogService | 95% |
| util_closer_SettingsService | 95% |
| util_closer_ChildRecordService | 94% |
| util_closer_CaseDataAccess | 93% |
| util_closer_SchedulerController | 93% |
| util_closer_LogCleanupBatch | 92% |
| util_closer_CaseStatusBatch | 87% |
| util_closer_RuleEngine | 86% |

**442 tests, 100% pass rate.** The two classes below 90% have pre-existing uncovered lines unrelated to this changeset. `util_closer_RuleEngine` at 86% is primarily due to the `LastActivityDate` code paths (lines 292+) which cannot execute because the field doesn't exist on Case in this org.

---

## Why These Issues Weren't Caught Earlier

The test suite has strong coverage of the rule engine logic but a structural blind spot: **no test verifies that the batch query includes the fields the engine needs**. The tests fall into two categories that both pass while the feature is broken:

1. **Engine logic tests** — these hand-build Cases with all the right fields in the SELECT (e.g., `SELECT Id, Status, RecordType.DeveloperName FROM Case`). They prove the filtering logic is correct when given proper data. But this is not the data shape the batch provides.

2. **"Graceful failure" tests** — these intentionally recreate the missing-field scenario and assert the engine doesn't crash. For example:

   - `testEvaluateCases_RecordType_NotQueried` (line 709 of `util_closer_RuleEngine_Test.cls`) loads a Case WITHOUT `RecordType.DeveloperName`, runs the engine, and asserts `changes != null`. It treats "silently skip the record type check" as correct behavior.
   - `testEvaluateCases_LastActivityDate_FieldNotQueried` (line 584) does the same for `LastActivityDate`.

   These tests **document the bug as intended behavior**. The assertion is that the code doesn't crash — not that the feature works.

The gap is a missing **integration test** that connects the batch query to the engine: "given the exact field set from `queryCasesByStatus`, does record type filtering actually work?" That test never existed.

---

## Production Verification and Deployment Guide

These changes were validated and deployed to dcca-devcc (sandbox). The following guidance is for the developer deploying to production.

### Step 1: Verify production org configuration

Run these queries against the production org to understand the current state:

**Check if `LastActivityDate` exists on Case:**
```bash
sf data query \
  --query "SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Case' AND QualifiedApiName = 'LastActivityDate'" \
  --target-org <prod-alias>
```

- If it returns 1 result: Activities tracking is enabled. Add `LastActivityDate` to the batch query SELECT in `util_closer_CaseDataAccess.cls` alongside `RecordType.DeveloperName` before deploying.
- If it returns 0 results: Activities tracking is not enabled. Deploy as-is. The `Days_Since_Last_Activity__c` feature will remain non-functional until Activities are enabled.

**Check current rule configuration:**
```bash
sf data query \
  --query "SELECT DeveloperName, Is_Active__c, Record_Type_Developer_Names__c, Exclude_Record_Type_Developer_Names__c, Days_Since_Last_Activity__c, Additional_Filter_Logic__c, Stop_Processing__c FROM util_closer_Case_Status_Rule__mdt ORDER BY Execution_Order__c" \
  --target-org <prod-alias>
```

Review which rules are using record type filters, activity checks, or additional filter logic. Any rule with `Record_Type_Developer_Names__c` populated has been silently ignoring that filter until this fix is deployed.

### Step 2: Deploy

The following changes are safe to deploy to any org regardless of configuration:

- `util_closer_CaseDataAccess.cls` — batch query with `RecordType.DeveloperName`
- `util_closer_RuleViewerController.cls` — `stopProcessing` removed from API response
- `util_closer_RuleViewerController_Test.cls` — updated assertion
- `util_closer_RuleViewer` LWC — `stopProcessing` block removed from HTML
- All CMDT field metadata (help text and descriptions)
- Page layout and list view changes
- `util_closer_CaseDataAccess.cls` overload alignment

If `LastActivityDate` exists in production, also update line 27 of `util_closer_CaseDataAccess.cls` to add `LastActivityDate` to the static SOQL SELECT.

### Step 3: Validate after deployment

Run all Closinator tests in production:
```bash
sf apex run test \
  --class-names util_closer_CaseDataAccess_Test \
  --class-names util_closer_RuleEngine_Test \
  --class-names util_closer_CaseStatusBatch_Test \
  --class-names util_closer_RuleViewerController_Test \
  --class-names util_closer_ChildRecordService_Test \
  --class-names util_closer_Logger_Test \
  --class-names util_closer_SettingsService_Test \
  --class-names util_closer_CaseStatusScheduler_Test \
  --class-names util_closer_SchedulerController_Test \
  --class-names util_closer_NotificationService_Test \
  --class-names util_closer_LogDataAccess_Test \
  --class-names util_closer_BatchLogService_Test \
  --class-names util_closer_CaseLogService_Test \
  --class-names util_closer_LogCleanupBatch_Test \
  --class-names util_closer_LogViewerController_Test \
  --class-names util_closer_PermissionSet_Test \
  --code-coverage \
  --result-format human \
  --target-org <prod-alias> \
  --wait 10
```

Verify 100% pass rate and review coverage.

### Step 4: Run simulation

Run the Closinator in simulation mode after deployment to confirm record type filters are now working. Review `util_closer_Case_Log__c` records to verify that cases are being correctly included/excluded by record type.

### Recommendation: Enable Activities on Case

If the client wants `Days_Since_Last_Activity__c` to function, Activities tracking must be enabled on the Case object in the org. This is a Salesforce configuration change (Setup > Activity Settings), not a code change. Once enabled, `LastActivityDate` becomes available on Case and should be added to the batch query.
