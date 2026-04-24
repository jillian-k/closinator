# Duplicate Work Item Detection — Demo Guide (April 23, 2026)

Step-by-step script for demoing the Related Work Items LWC in `dcca-devcc`. Every scenario below uses a prefabricated Case + Work Item set so you can run the demo repeatedly without cleanup between runs.

- **Org:** `dcca-devcc` (`https://hi-dcca--devcc.sandbox.my.salesforce.com`)
- **All demo records are prefixed** `DEMO-DWI ` in their Subject and `DemoDWI` in the Person Account last name, so they're easy to filter and (if needed) wipe later.
- **All Cases use the `PVL` (Call Center) record type** — close-blocking validation rules (Force Branch/Island) don't fire on PVL, so `Link & Close` always succeeds cleanly for the demo.
- **Work Items span three record types — OCP, INS, and BREG** — so the LWC's Division column shows real variety across scenarios (and inside the multi-match scenario). PVL Work Items are intentionally skipped; in this sandbox the PVL row of `Work_Item_Routing__mdt` has no notification email configured, so the "Work Item: Update Record on Create" flow errors out at insert. That's a pre-existing org-config gap, not a limitation of the LWC — the LWC itself is division-agnostic.
- **Spoofed contact info:** phones use the obviously fake `808-888-88XX` range. Emails use `jillian+devcc+<name>@terranox.co` subaddressing — real inbox (yours) but no customer data exposed.

---

## Demo roster at a glance

| Scenario | Demo Case (open this) | CaseNumber | Caller | Phone | Division(s) in LWC | Expected LWC state |
|---|---|---|---|---|---|---|
| 1. Single match | DEMO-DWI Repeat Call — Alpha | **00140612** | Alpha DemoDWI | 808-888-8881 | OCP | 1 row → Link & Close |
| 2. **Multiple matches** | DEMO-DWI Repeat Call — Bravo | **00140613** | Bravo DemoDWI | 808-888-8882 | **OCP, INS, BREG** | **3 rows** → agent picks one |
| 3. Single match | DEMO-DWI Repeat Call — Charlie | **00140614** | Charlie DemoDWI | 808-888-8883 | INS | 1 row → Link & Close |
| 4. Single match | DEMO-DWI Repeat Call — Delta | **00140615** | Delta DemoDWI | 808-888-8884 | BREG | 1 row → Link & Close |
| 5. Single match (High Priority) | DEMO-DWI Repeat Call — Echo | **00140616** | Echo DemoDWI | 808-888-8885 | INS | 1 row, High Priority ✓ → Link & Close |
| Bonus A. No matches | DEMO-DWI Repeat Call — Foxtrot | **00140617** | Foxtrot DemoDWI | 808-888-8899 | — | Empty state message |
| Bonus B. Already linked | DEMO-DWI Already Linked (Echo) | **00140618** | Echo DemoDWI | 808-888-8885 | INS | Linked-state card (pre-closed) |

### Direct Lightning links

Click straight into each Demo Case:

- Scenario 1 — https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jiAAD/view
- Scenario 2 — https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jjAAD/view
- Scenario 3 — https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jkAAD/view
- Scenario 4 — https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jlAAD/view
- Scenario 5 — https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jmAAD/view
- Bonus A — https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jnAAD/view
- Bonus B — https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2joAAD/view

---

## Full record inventory (IDs + CaseNumbers + WI Names)

### Person Accounts

| First Name | Phone | Email | Account Id |
|---|---|---|---|
| Alpha | 808-888-8881 | jillian+devcc+alpha@terranox.co | `001cq00000PgEqcAAF` |
| Bravo | 808-888-8882 | jillian+devcc+bravo@terranox.co | `001cq00000PgEqdAAF` |
| Charlie | 808-888-8883 | jillian+devcc+charlie@terranox.co | `001cq00000PgEqeAAF` |
| Delta | 808-888-8884 | jillian+devcc+delta@terranox.co | `001cq00000PgEqfAAF` |
| Echo | 808-888-8885 | jillian+devcc+echo@terranox.co | `001cq00000PgEqgAAF` |
| Foxtrot | 808-888-8899 | jillian+devcc+foxtrot@terranox.co | `001cq00000PgEqhAAF` |

### Original Parent Cases (the Work Item's `Case__c` lookup points here)

| Caller | Subject | CaseNumber | Case Id |
|---|---|---|---|
| Alpha | DEMO-DWI Original 1A (Alpha) | 00140605 | `500cq00000HS2jbAAD` |
| Bravo | DEMO-DWI Original 2A (Bravo — OCP) | 00140606 | `500cq00000HS2jcAAD` |
| Bravo | DEMO-DWI Original 2B (Bravo — INS) | 00140607 | `500cq00000HS2jdAAD` |
| Bravo | DEMO-DWI Original 2C (Bravo — BREG) | 00140608 | `500cq00000HS2jeAAD` |
| Charlie | DEMO-DWI Original 3A (Charlie — INS) | 00140609 | `500cq00000HS2jfAAD` |
| Delta | DEMO-DWI Original 4A (Delta — BREG) | 00140610 | `500cq00000HS2jgAAD` |
| Echo | DEMO-DWI Original 5A (Echo — INS) | 00140611 | `500cq00000HS2jhAAD` |

### Work Items (open — these appear in the LWC)

| Caller | WI Name | Record Type (Division) | INS Branch | High Priority | Parent Case | WI Id |
|---|---|---|---|---|---|---|
| Alpha | WI-00620 | OCP | — | — | 00140605 | `a4Tcq000000MyDdEAK` |
| Bravo | WI-00621 | OCP | — | — | 00140606 | `a4Tcq000000MyDeEAK` |
| Bravo | WI-00622 | INS | Licensing | ✓ High | 00140607 | `a4Tcq000000MyDfEAK` |
| Bravo | WI-00623 | BREG | — | — | 00140608 | `a4Tcq000000MyDgEAK` |
| Charlie | WI-00624 | INS | Licensing | — | 00140609 | `a4Tcq000000MyDhEAK` |
| Delta | WI-00625 | BREG | — | — | 00140610 | `a4Tcq000000MyDiEAK` |
| Echo | WI-00626 | INS | Licensing | ✓ High | 00140611 | `a4Tcq000000MyDjEAK` |

### Repeat-Call Demo Cases (the Case the agent opens)

| Caller | Subject | CaseNumber | Case Id | State |
|---|---|---|---|---|
| Alpha | DEMO-DWI Repeat Call — Alpha (single match) | 00140612 | `500cq00000HS2jiAAD` | Open |
| Bravo | DEMO-DWI Repeat Call — Bravo (MULTI match) | 00140613 | `500cq00000HS2jjAAD` | Open |
| Charlie | DEMO-DWI Repeat Call — Charlie (single match) | 00140614 | `500cq00000HS2jkAAD` | Open |
| Delta | DEMO-DWI Repeat Call — Delta (single match) | 00140615 | `500cq00000HS2jlAAD` | Open |
| Echo | DEMO-DWI Repeat Call — Echo (single match) | 00140616 | `500cq00000HS2jmAAD` | Open |
| Foxtrot | DEMO-DWI Repeat Call — Foxtrot (NO match) | 00140617 | `500cq00000HS2jnAAD` | Open |
| Echo | DEMO-DWI Already Linked (Echo) | 00140618 | `500cq00000HS2joAAD` | Closed, pre-linked to WI-00626 |

---

## Before you demo — 60-second warm-up

1. Log in to `dcca-devcc` as yourself (`jillian@terranox.co.devcc`) or as a user assigned the `UJET_Agent` permission set. Either works.
2. Make sure your browser window is **maximized** — the LWC sits in the right sidebar and narrow windows hide the Link & Close button.
3. Keep a browser tab open to the Work Item list view so after each Link & Close you can optionally pop over and confirm the "Duplicate / Repeat-Call Cases" related list reflects the new link. (This related list has to be added to Work Item layouts manually — see post-deploy steps in the implementation plan; it isn't added yet in `dcca-devcc`, so the child Case lives in the lookup but won't show on the WI record page as a related list until the admin drops it there.)
4. If you've already run a scenario and want to repeat it, just re-run the setup Apex at `docs/duplicate-work-items/create_demo_data.apex` — the script is idempotent (it deletes prior `DEMO-DWI %` records before recreating).

---

## Scenario 1 — Single match (happy path, OCP)

**Story:** Alpha called last week; we opened an OCP consumer-complaint Work Item. She's calling back today with a follow-up. Rather than create a net-new Work Item, we link her new Case to the existing one and close her new Case in a single action.

1. Open Demo Case **00140612** (DEMO-DWI Repeat Call — Alpha). Direct link: https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jiAAD/view
2. Right sidebar: **Related Work Items** card loads.
   - Spinner for ~½ second while `getRelatedWorkItems` runs.
   - One row appears: **WI-00620** · Division **OCP** · Status New · Parent Case **00140605** · High Priority ✗ · Created today.
3. Click the row's radio selector (left of the Work Item link).
4. Click **Link & Close** (bottom-right brand button).
5. Expect:
   - Loading spinner briefly covers the card.
   - **Sticky green success toast** appears at top-right: *"Linked to Work Item WI-00620 (original Case 00140605) and closed this Case."* Both WI-00620 and 00140605 are clickable hyperlinks.
   - Card title flips to **Linked Work Item**. The datatable disappears; in its place is a definition list:
     - **Work Item** → WI-00620 (New)
     - **Original Case** → 00140605
   - The Case's Status (in the highlight panel) has flipped to **Closed**.
6. Click the Work Item link inside the card (or inside the toast) → you land on WI-00620's record page.
7. Hit browser back to return to Case 00140612 and show the linked-state card persists on the closed Case.

**What to point out to the audience:** One click closed the Case and preserved the navigation path. Even after the Case is closed, any agent who revisits this record sees the linked Work Item and the original call's Case as persistent clickable links — no extra search, no opening a related list.

---

## Scenario 2 — Multiple matches, different divisions (the "agent must choose" scenario)

**Story:** Bravo has called DCCA three times this month — once about a consumer complaint (OCP), once about producer licensing (INS), and once about business registration (BREG). Three Work Items are open for his caller profile, spanning three different divisions. He's calling back; the agent needs to pick the right one based on why he's calling.

1. Open Demo Case **00140613** (DEMO-DWI Repeat Call — Bravo (MULTI match)). Direct link: https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jjAAD/view
2. Right sidebar: **Related Work Items** card loads **three rows** — and the Division column is the key differentiator:
   - **WI-00621** — Division **OCP** — Parent Case **00140606** — no High Priority
   - **WI-00622** — Division **INS** — Parent Case **00140607** — **✓ High Priority** (this is the one to pick for the story)
   - **WI-00623** — Division **BREG** — Parent Case **00140608** — no High Priority
3. Narrate: "Three open threads for this caller, three different divisions. In real life an agent would identify which of Bravo's open issues this new call is a follow-up to — by division, by priority, by the parent Case's Subject — and pick the right one." Click the Parent Case link `00140607` in-row — opens the original Bravo INS Case in a new tab — show its Subject confirms it's the INS one.
4. Back on Case 00140613, select **WI-00622**'s row.
5. Click **Link & Close**.
6. Expect the same successful close flow as Scenario 1. Toast links to WI-00622 and original Case 00140607.
7. Highlight that the other two Bravo WIs (WI-00621 and WI-00623) are **still open** — they aren't affected. This Case only gets attached to WI-00622.

**What to point out:** The LWC doesn't assume one result, and Division is front-and-center so the agent can quickly spot the right thread even when the same caller has multiple open issues across different DCCA divisions. No auto-linking, no guessing.

---

## Scenario 3 — Single match, INS (Charlie)

**Story:** Same beats as Scenario 1 with a different caller and a different division. Good one to run if the audience wants to see the flow with a non-OCP Work Item.

1. Open Demo Case **00140614** (DEMO-DWI Repeat Call — Charlie). Direct link: https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jkAAD/view
2. One row: WI-00624 · Division **INS** · Parent Case 00140609.
3. Select, Link & Close. Toast + linked-state card.

---

## Scenario 4 — Single match, BREG (Delta)

1. Open Demo Case **00140615** (DEMO-DWI Repeat Call — Delta). Direct link: https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jlAAD/view
2. One row: WI-00625 · Division **BREG** · Parent Case 00140610.
3. Select, Link & Close. Toast + linked-state card.

---

## Scenario 5 — Single match, High Priority (Echo, INS)

**Story:** Same beats as Scenario 1, but Echo's Work Item is flagged High Priority — useful to highlight the High Priority column in the datatable.

1. Open Demo Case **00140616** (DEMO-DWI Repeat Call — Echo). Direct link: https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jmAAD/view
2. One row: WI-00626 · Division **INS** · Parent Case 00140611 · **✓ High Priority** in the datatable column.
3. Select, Link & Close. Toast + linked-state card.

---

## Bonus A — No matches (empty state)

**Story:** Foxtrot is a first-time caller. No prior Work Items exist for her phone number. The agent proceeds through the normal new-Case flow.

1. Open Demo Case **00140617** (DEMO-DWI Repeat Call — Foxtrot). Direct link: https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2jnAAD/view
2. Right sidebar: **Related Work Items** card shows the message *"No open Work Items were found for this caller's phone number."*
3. No datatable, no Link & Close button. The agent handles the Case normally.

**What to point out:** When there are no matches, the LWC gets out of the way — it doesn't show a cluttered datatable or a disabled button. Agents only see the actionable UI when there's something to act on.

---

## Bonus B — Already-linked state (revisit a closed Case)

**Story:** Show what any agent (or supervisor on audit) sees when they open a Case that's already been linked and closed. Useful for proving that the navigation thread persists without needing the lookup field dropped onto every flexipage.

1. Open Demo Case **00140618** (DEMO-DWI Already Linked (Echo)). Direct link: https://hi-dcca--devcc.sandbox.my.salesforce.com/lightning/r/Case/500cq00000HS2joAAD/view
2. Case Status in the highlight panel: **Closed**.
3. Right sidebar: **Linked Work Item** card is immediately visible (no spinner — the `getRecord` wire resolves on load).
   - **Work Item** → WI-00626 (New)
   - **Original Case** → 00140611
4. Click WI-00626 → lands on the Work Item record page. From there the existing `Work_Item__c.Case__c` field links back to original Case 00140611.

**What to point out:** Everything linked through the LWC is reachable from either direction, at any time, without an admin having to drop the `Case.Work_Item__c` field onto every Case flexipage.

---

## After the demo

### If you want to reset the data (re-run scenarios with "fresh" states)

The setup script at `docs/duplicate-work-items/create_demo_data.apex` is **idempotent**. Running it:

1. Deletes all prior `DEMO-DWI %` Cases,
2. Deletes all child Work Items on those Cases,
3. Deletes all `DemoDWI` Person Accounts,
4. Recreates everything from scratch.

Run it from this workspace with:

```bash
sf apex run -f docs/duplicate-work-items/create_demo_data.apex -o dcca-devcc
```

You'll get a fresh set of Case numbers and Work Item names each run (Salesforce auto-numbers advance), so update the links/numbers above if you commit anything.

### If you want to permanently remove the demo data

Easiest way — an anonymous Apex block (deletion order matters, Cases go first so closed-case validation rules don't fire on updates):

```apex
delete [SELECT Id FROM Case WHERE Subject LIKE 'DEMO-DWI %'];
delete [SELECT Id FROM Work_Item__c WHERE Case__r.Subject LIKE 'DEMO-DWI %'];
delete [SELECT Id FROM Account WHERE LastName = 'DemoDWI'];
```

### Things to know when talking through edge cases with the audience

| Question you might get | Answer |
|---|---|
| *Why are the demo Work Items only OCP / INS / BREG — no PVL?* | Not an LWC limitation. In this sandbox the `PVL` row of `Work_Item_Routing__mdt` has a null `Notification_Email_Address__c`, so the "Work Item: Update Record on Create" flow fails at insert time for any PVL WI. Configure that metadata row with a real notification email in a higher environment and PVL WIs will appear in the LWC exactly the same way OCP/INS/BREG do today. The LWC's SOQL is `RecordType.Name` agnostic. |
| *Is the phone match exact or normalized?* | Exact — SOQL `Account.Phone = :currentCase.Account.Phone`. Normalization is deliberately out of scope for this feature. |
| *What if the caller's phone number is wrong on the Person Account?* | The agent corrects it on the Person Account (Highlight Panel), then hits **Refresh** on the Related Work Items card — the card re-queries with the new phone. |
| *Does this affect the Work Item's automations?* | No. The LWC only modifies the Case. No triggers, flows, or validation rules on the Work Item run as a result of Link & Close. |
| *What about validation rules that block close?* | Most org validation rules exempt `Status = 'Closed'`. The three that don't (PVL/OCP/BREG "Force Branch/Island" rules) fire only on non-PVL record types — all demo Cases are PVL RT so this never trips. If it did, the LWC surfaces the rule's user-facing error message in a sticky error toast. |
| *Can we link to a closed Work Item?* | No. `getRelatedWorkItems` filters out `Status__c = 'Closed'` WIs and WIs whose parent Case is already Closed. |
| *Who can use this?* | Users with the `UJET_Agent` permission set (the 20 existing Call Center Agents). That permset grants Apex class access + FLS on `Case.Work_Item__c` + FLS on `Work_Item__c.Status__c` / `Work_Item__c.Case__c` needed by the `getRecord` wire. |
| *Are those real phone numbers / emails?* | No — demo-only. Phones use the obviously fake `808-888-88XX` range. Emails use `jillian+devcc+<name>@terranox.co` subaddressing (routes to Jillian's inbox for testability, but no customer PII is exposed). |

---

## Quick reference: the demo in one sentence each

1. **Alpha** — one match (OCP), happy path.
2. **Bravo** — **three matches spanning OCP, INS, and BREG**, agent picks the right one.
3. **Charlie** — happy path with an INS Work Item.
4. **Delta** — happy path with a BREG Work Item.
5. **Echo** — happy path with an INS Work Item flagged High Priority.
6. **Foxtrot** — empty-state "no matches" message.
7. **Already-linked** — the persistent navigation card on a closed Case.
