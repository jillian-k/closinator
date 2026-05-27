# Closinator — Outstanding Issues Analysis

**Original Date:** March 23, 2026
**Updated:** April 14, 2026
**Org:** dcca-devcc (Sandbox)
**Source of Truth:** Code retrieved directly from dcca-devcc org on April 9, 2026; Issue 1 fix applied April 13, 2026; documentation and UI clarifications deployed April 14, 2026

---

## Purpose

This analysis identifies rule configuration fields that are presented to the admin in the Custom Metadata Type UI and appear to have functionality, but do not work as expected due to gaps in the underlying Apex implementation.

All five rules in the org use `Record_Type_Developer_Names__c = PVL`, meaning every rule intends to be scoped to PVL cases only. Rules also use `Additional_Filter_Logic__c` to filter on custom Case fields.

---

## Issue 1: Additional Filter Logic — FIXED

**Status:** Fixed
**Field:** `Additional_Filter_Logic__c`
**UI Location:** Additional Case Filters section (previously "Advanced Filtering")
**Applies to:** Case fields only — child object filtering is handled by the Child Record Criteria section

**What was happening:** The evaluation code worked correctly — but only for fields already included in the batch query SELECT. The batch query had a fixed field set (`Id`, `CaseNumber`, `Status`, `LastModifiedDate`, `CreatedDate`, `Origin`, `Owner.Name`, `LastModifiedBy.Name`). If a filter referenced any other field (e.g., `Secondary_Call_Reason__c`, `OwnerId`, `INS_Branch_v2__c`), `getFieldValue` caught the resulting exception and returned null, causing the condition to silently fail or pass.

**Real-world example:** The `Cases_Owned_by_Johnny_C_Li` rule filters on `OwnerId = '0058y000000uWpTAAU'`. Another rule filters on `Secondary_Call_Reason__c = 'Amendments' AND INS_Branch_v2__c = 'Business Registration'`. Neither filter worked because those fields were not in the batch query.

**Supported syntax (AND only, no OR):**
- `Field = 'Value'` / `Field != 'Value'`
- `Field = null` / `Field != null`
- `Field LIKE 'Pattern%'`
- `Field IN ('Value1', 'Value2')` / `Field NOT IN ('Value1', 'Value2')`
- `Field = true` / `Field = false`

**What works reliably:**
- Any standard or custom Case field API name (e.g., `Priority`, `Secondary_Call_Reason__c`, `OwnerId`, `Subject`) — these are validated against the Case schema and automatically added to the batch query.
- A misspelled field name in a valid syntax pattern (e.g., `Prioirty = 'High'`) will cause the field value to be null, which fails the comparison and excludes the case. This is the safe direction.

**Known limitation — unrecognized syntax silently passes:** If the condition doesn't match any supported pattern (e.g., unsupported operator like `>` or `<`, or relationship field notation like `Owner.Name`), the condition is treated as met and the case passes the filter. This is a pre-existing behavior at line 945 of `util_closer_RuleEngine.cls`. Relationship fields `Owner.Name`, `LastModifiedBy.Name`, and `RecordType.DeveloperName` are already in the base query and accessible via other rule fields — they do not need to be used in Additional Filter Logic.

**Fix applied:** Added dynamic field extraction in `util_closer_RuleEngine.extractFilterFields()`. At batch start, all active rules' `Additional_Filter_Logic__c` values are scanned, field names are parsed out and validated against the Case object schema, and valid fields are passed to the two-arg `queryCasesByStatus()` overload. The batch `start()` method in `util_closer_CaseStatusBatch.cls` now calls this extraction before querying.

**UI clarifications:** Layout section renamed from "Advanced Filtering" to "Additional Case Filters." Help text now opens with "Filters on Case fields only" and directs admins to the Child Record Criteria section for child object filtering.

---

## Issue 2: Days Since Last Activity — Cannot Be Fixed in This Org

**Status:** Blocked — `LastActivityDate` does not exist on Case in dcca-devcc
**Field:** `Days_Since_Last_Activity__c`
**UI Location:** Time-Based Criteria section
**Appears to do:** Prevent a rule from matching unless the case has had no activity for at least N days

**What actually happens:** The evaluation code depends on reading `LastActivityDate` from the Case record. In the dcca-devcc org, `LastActivityDate` does not exist on the Case object — Activities tracking is not enabled for Cases. The `SObjectException` is silently caught and the check is always skipped, regardless of whether the field is in the batch query or not.

**Why it can't be fixed with a query change:** Even if we added `LastActivityDate` to the SOQL, the query would fail at compile time because the field doesn't exist. The RuleEngine code uses dynamic field access (`c.get('LastActivityDate')`) which fails gracefully at runtime, but the static SOQL in `CaseDataAccess` would not compile.

**Resolution:** Help text updated to note that this feature requires Activities to be enabled on the Case object. No code changes possible until Activities are enabled. If Activities are enabled in the future, `LastActivityDate` should be added to the batch query (either in the static SOQL or via the two-arg overload).

---

## Issue 3: Record Type Filters — FIXED

**Status:** Fixed
**Fields:** `Record_Type_Developer_Names__c` and `Exclude_Record_Type_Developer_Names__c`
**UI Location:** Record Type Filters section
**Appears to do:** Restrict a rule to specific record types (inclusion) or exclude specific record types (exclusion)

**What was happening:** Same root cause as Issue 2. The evaluation code attempted to read `RecordType.DeveloperName` from the Case record, but the batch query did not include it. Salesforce threw an `SObjectException`, it was silently caught, and the entire record type check was skipped. All five rules in the org set `Record_Type_Developer_Names__c = PVL` — meaning every rule intended to be scoped to PVL cases only, but the filter was silently ignored and rules evaluated against all record types.

**Fix applied:** Added `RecordType.DeveloperName` to the batch query SELECT clause in `util_closer_CaseDataAccess.queryCasesByStatus()`.

---

## Issue 4: Stop Processing — FIXED (Removed from UI)

**Status:** Fixed — removed from admin-visible surfaces
**Field:** `Stop_Processing__c`
**UI Location:** Rule Information section (checkbox)
**Appears to do:** Control whether the system stops evaluating additional rules after a match

**What actually happens:** The code checks the value but both the `true` and `false` branches execute identical logic — they both return immediately with the matched rule's status change. The system always stops at the first match regardless of this field's value. Two rules (`Close_Stale_PVL_New_Cases`, `Never_Reached_an_Agent`) have it set to true, which has no effect.

**Code reference:**

```423:431:force-app/main/default/classes/util_closer_RuleEngine.cls
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            if (caseMatchesRule(c, rule, childRecords)) {
                util_closer_Logger.debug('RuleEngine', 'Case ' + c.Id + ' matches rule ' + rule.DeveloperName);

                if (rule.Stop_Processing__c == true) {
                    return new CaseChange(rule.Target_Status__c, rule.Target_Reason__c);
                }
                return new CaseChange(rule.Target_Status__c, rule.Target_Reason__c);
            }
        }
```

**Resolution:** First-match-wins is the correct and intended behavior. `Stop_Processing__c` removed from:
- CMDT page layout (Rule Information section)
- `All_Rules` and `Active_Rules` list views
- Rule Viewer LWC (controller and HTML)

The field and metadata remain on the object. The Apex code is unchanged — both branches still do the same thing, which is harmless.

---

## Issue 5: Help Text and Descriptions — FIXED

**Status:** Fixed
**Fields:** `Additional_Filter_Logic__c`, `Days_Since_Last_Activity__c`, `Record_Type_Developer_Names__c`, `Exclude_Record_Type_Developer_Names__c`, `Child_Filter_Operator__c`

Help text updated with:
- Supported syntax and operators
- Input format (semicolons, Developer Names vs labels, single quotes)
- Case-only clarification for Additional Filter Logic (directs admins to Child Record Criteria for child objects)
- Case sensitivity notes for Child Filter Operator (Equals is case-sensitive, Contains is case-insensitive)
- Behavioral clarifications (LastActivityDate vs LastModifiedDate)

Layout section "Advanced Filtering" renamed to "Additional Case Filters" for clarity.

---

## Summary

| Field | Issue | Status | Fix |
|---|---|---|---|
| Additional_Filter_Logic__c | Only works for fields in batch query | Fixed | Dynamic field extraction adds referenced fields to query at runtime |
| Days_Since_Last_Activity__c | `LastActivityDate` not on Case object | Blocked | Activities not enabled; help text updated |
| Record_Type_Developer_Names__c | `RecordType.DeveloperName` not in batch query | Fixed | Added to batch query SELECT |
| Exclude_Record_Type_Developer_Names__c | `RecordType.DeveloperName` not in batch query | Fixed | Added to batch query SELECT |
| Stop_Processing__c | Both code branches identical | Fixed | Removed from UI; first-match-wins is correct |
| Help text (5 fields) | Insufficient guidance for admins | Fixed | Updated descriptions and inline help |

## Additional Fixes (Defensive)

- **Two-arg `queryCasesByStatus` overload** — base field set aligned with the one-arg method to prevent future drift. Previously only included `Id, Status, LastModifiedDate, CreatedDate`, missing fields the one-arg method selects.
- **`queryCasesWithCustomWhere`** — same alignment applied.
- **`Stop_Processing__c` field description** — updated to note the field is non-functional.
- **Layout section renamed** — "Advanced Filtering" → "Additional Case Filters" to clarify it applies to Case fields only.
- **Integration tests added** — 8 batch-level tests that verify the full pipeline (batch start → field extraction → query → engine evaluation → case update) for both Additional Filter Logic and Record Type filtering. These close the structural testing gap described in the changes summary.
