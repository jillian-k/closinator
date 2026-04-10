# Closinator Additional Updates — Changes Summary

**Date:** April 9, 2026
**Branch:** `closinator-additional-updates`
**Org:** dcca-devcc (Sandbox)
**Test Results:** 421 tests, 100% passing

---

## Overview

This changeset fixes silent failures in the Closinator's rule evaluation system where admin-configured fields appeared functional but were silently ignored due to missing fields in the batch query. It also removes a non-functional UI field and improves help text across the CMDT configuration.

---

## Changes by File

### Apex Classes

**`util_closer_CaseDataAccess.cls`**
- Added `RecordType.DeveloperName` to the static batch query in `queryCasesByStatus(Set<String>)`. This fixes record type inclusion/exclusion filters that were previously silently skipped.
- Aligned the base field set in `queryCasesByStatus(Set<String>, Set<String>)` to include `CaseNumber`, `Origin`, `Owner.Name`, `LastModifiedBy.Name`, and `RecordType.DeveloperName` — matching the one-arg method.
- Same alignment applied to `queryCasesWithCustomWhere(String, Set<String>)`.

**`util_closer_RuleViewerController.cls`**
- Removed `stopProcessing` from the rule data map sent to the LWC. The field is non-functional and no longer displayed.

**`util_closer_RuleViewerController_Test.cls`**
- Removed the `stopProcessing` assertion from `testGetActiveRules_VerifyAllFieldMapping` to match the controller change.

### LWC

**`util_closer_RuleViewer.html`**
- Removed the `Stop Processing: Yes` display block that was conditionally rendered when `rule.stopProcessing` was true.

### Custom Metadata Type Fields

**`Additional_Filter_Logic__c`**
- Updated description and help text with full syntax reference, supported operators, AND-only limitation, and available field names.

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

### List Views

**`All_Rules`** and **`Active_Rules`**
- Removed `Stop_Processing__c` column from both list views.

### Documentation

**`outstanding-issues-analysis.md`**
- Updated with org-validated findings from April 9, 2026.
- Corrected Issue 2 status: `LastActivityDate` does not exist on Case in dcca-devcc (Activities not enabled), so the fix is blocked at the org level.
- Marked Issues 3, 4, and 5 as fixed.

---

## What Was NOT Changed

- **`util_closer_RuleEngine.cls`** — No changes. The engine code was already correct; it just needed the right data in the query.
- **`util_closer_CaseStatusBatch.cls`** — No changes. The batch already calls the one-arg `queryCasesByStatus` which now includes the needed fields.
- **`Stop_Processing__c` field definition** — Not deleted. The field remains on the CMDT object for backward compatibility; only removed from visible UI surfaces.
- **`Additional_Filter_Logic__c` dynamic field extraction** — Deferred. Help text documents available fields instead. Can be implemented as a follow-up if admins need to filter on fields beyond the batch query set.

---

## Issue Status After Changes

| Issue | Field | Status |
|---|---|---|
| 1. Additional Filter Logic limited by batch query | `Additional_Filter_Logic__c` | Documented in help text; dynamic extraction deferred |
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
| util_closer_RuleEngine | 83% |

The two classes below 90% have pre-existing uncovered lines unrelated to this changeset. `util_closer_RuleEngine` at 83% is primarily due to the `LastActivityDate` code paths (lines 292+) which cannot execute because the field doesn't exist on Case in this org.
