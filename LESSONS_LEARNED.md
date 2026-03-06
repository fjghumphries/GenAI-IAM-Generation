# Lessons Learned: Dynatrace IAM Implementation

This document captures key insights, gotchas, and best practices discovered while implementing IAM for a large-scale Dynatrace Grail environment.

## 0. Set dt.security_context Directly on OneAgent — Don't Rely on Derivation

### Finding
The customer sets `dt.security_context` explicitly via `oneagentctl` rather than deriving it from primary tags in a pipeline. This is the correct and most reliable approach.

### Command Pattern
```bash
sudo ./oneagentctl \
  --set-host-property="dt.security_context=BU2-PROD-PETCLINIC02" \
  --set-host-property="primary_tags.BU=BU2" \
  --set-host-property="primary_tags.stage=PROD" \
  --set-host-property="primary_tags.application=PETCLINIC02" \
  --set-host-group=PETCLINIC02 \
  --restart-service
```

### Why Direct Setting is Better
- Pipeline-based derivation requires the enrichment pipeline to be in place before data is ingested — any gap means data arrives without security_context and cannot be retroactively scoped
- Setting it directly on the host guarantees it is always present from first ingest
- Simpler to audit and troubleshoot

### Gotchas
- **`--restart-service` is required** — without it, changes are silently not applied (the command just warns and exits)
- `host-group` and `dt.security_context` are independent: host-group controls OneAgent configuration grouping; security_context controls IAM scoping
- Primary tags set via `--set-host-property` are NOT the same as `dt.security_context` and cannot be used directly in IAM policies — they are for filtering, segments, and DQL only

---

## 1. Application-to-BU Mapping is 1:1 (Don't Assume Sharing)

### Finding
During initial setup, applications were incorrectly modelled as shared across BUs — creating 4 application entries (BU1+PETCLINIC01, BU1+PETCLINIC02, BU2+PETCLINIC01, BU2+PETCLINIC02) when in reality each application belongs to exactly one BU.

### Root Cause
The Terraform variables.tf application map requires unique keys. When two applications have the same name (e.g. two apps both called PETCLINIC01 in different BUs), the natural instinct is to prefix the key with the BU. This led to incorrectly assuming that both BUs had both applications.

### Correct Model
- Each application belongs to ONE BU only
- If application names are globally unique (recommended), use the application name directly as the map key
- Only use BU-prefixed keys (e.g. `BU1_APPNAME`) when two different BUs genuinely have separate apps with the same name

### Impact
- Incorrect: 4 application boundaries + 8 application bindings (wasted resources)
- Correct: 2 application boundaries + 4 application bindings
- Always clarify this mapping with the customer before applying Terraform

---

## 1. Security Context is King

### Key Insight
The `dt.security_context` field is the **primary enforcement mechanism** for IAM in Grail environments. Unlike Management Zones (2nd Gen), which are deprecated for Grail, security context provides hierarchical, scalable access control.

### Best Practice
- Use a consistent, hierarchical format: `BU-STAGE-APPLICATION-COMPONENT`
- Use `startsWith()` operator for hierarchical scoping
- Ensure security_context is **always populated** via OpenPipeline enrichment
- Never rely solely on segments for security - they provide filtering, not enforcement

### Gotcha
Security context must exist at ingest time. Data without security_context cannot be properly scoped retroactively.

---

## 2. Boundaries: The "Where" of IAM

### Key Insight
Boundaries decouple the "What" (permissions) from the "Where" (scope). This is powerful but has important limitations.

### Best Practices
- Use boundaries with default policies for efficient management
- Create separate boundaries for different condition types (storage vs settings)
- Keep boundaries simple - max 10 conditions per boundary

### Critical Gotchas

#### Boundary Conditions Only Apply Where Applicable
```
Policy: ALLOW storage:logs:read, storage:entities:read;
Boundary 1: storage:host.name = "myHost"
Boundary 2: storage:dt.security_context = "mySC"

Result:
- storage:entities:read becomes UNCONDITIONAL (host.name doesn't apply to entities!)
- storage:logs:read gets both conditions

```
**Solution**: Create separate bindings for policies with different applicable conditions.

#### No AND Operator
Boundaries don't support AND between conditions. Each line is evaluated as a separate condition that produces separate policy statements.

#### Boundaries Don't Apply to DENY Statements
If you need to deny access to specific scopes, you must use explicit DENY statements in the policy, not in boundaries.

---

## 3. Policy Templating: Powerful but with Constraints

### Key Insight
Parameterized policies (`${bindParam:name}`) reduce management overhead significantly when you have repetitive access patterns.

### Best Practice
Create one templated policy (e.g., "Scoped Data Read") and bind it to multiple groups with different parameter values.

### Gotchas
1. **Parameters are immutable after binding**: You cannot change the parameter names in a policy that's already bound to groups.

2. **Parameter validation**: If expected parameters don't match provided parameters at binding time, the API returns a 400 error.

3. **List values**: Use comma-separated strings for `IN` operator values:
   ```
   parameters = {
     "stages" = "PROD,DEV,TEST"
   }
   ```

---

## 4. Default Policies: Know Them Before Creating Custom Ones!

### Key Insight
Dynatrace maintains default policies that stay up-to-date with platform changes. **Always check what's included in Standard User and Admin User before creating custom policies** - you'll likely find the permission is already there.

Refer to the [Default Policies documentation](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies) and the [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference) (also linked in `.github/copilot-instructions.md`).

### Standard User Includes (as of March 2026)
```
// Documents - FULL CRUD
document:documents:read, write, delete
document:environment-shares:*, document:direct-shares:*, document:trash.*

// Grail Metadata (NOT data!)
storage:bucket-definitions:read, storage:fieldset-definitions:read
storage:filter-segments:read, write, delete

// Automation - LIMITED
automation:workflows:read, run
automation:workflows:write WHERE automation:workflow-type = "SIMPLE"
automation:calendars:read, automation:rules:read

// Davis AI - FULL
davis:analyzers:read, execute
davis-copilot:conversations:execute, nl2dql:execute, dql2nl:execute

// SLOs - READ ONLY
slo:slos:read, slo:objective-templates:read

// Settings - READ ONLY (UNCONDITIONAL!)
settings:objects:read, settings:schemas:read

// Notifications - FULL
notification:notifications:read, write

// Plus: hub, extensions:read, vulnerability:read, etc.
```

### Admin User Adds (on top of Standard User)
```
// Automation - FULL ADMIN
automation:workflows:write, admin
automation:calendars:write, automation:rules:write

// Settings - FULL WRITE (UNCONDITIONAL!)
settings:objects:write, admin

// SLOs - WRITE
slo:slos:write

// Extensions - WRITE
extensions:definitions:write, configurations:write

// OpenPipeline - WRITE
openpipeline:configurations:write

// Plus: deployment, oauth2:clients:manage, etc.
```

### What's NOT in Any Default Policy
**Critical**: No default policy includes Grail data read permissions:
- `storage:logs:read` ❌
- `storage:metrics:read` ❌  
- `storage:spans:read` ❌
- `storage:events:read` ❌
- `storage:bizevents:read` ❌

You MUST create custom/templated policies for Grail data access.

### Best Practice
1. Query default policy contents via API or Terraform output before creating custom policies
2. **Do NOT use `Admin User` directly** for admin groups — it grants unconditional `settings:objects:write` that cannot be scoped. Instead, create a custom `Admin Features` policy that cherry-picks the admin capabilities you need (see Lesson #16)
3. Use `Standard User` for all users (including admins) — it provides the base feature set
4. Only create custom policies for Grail data read, scoped settings write, and admin features

---

## 5. IAM is Additive - Understand the Implications

### Key Insight
Permissions in Dynatrace IAM are **additive**. You cannot restrict permissions that a broader policy already grants.

### Critical Example: Settings Read
```
Standard User grants: settings:objects:read (UNCONDITIONAL)
Your custom policy: Scoped Settings Read with boundary

Result: User has BOTH unconditional read AND scoped read
        The unconditional read "wins" - they can read ALL settings
```

### Implications
1. **Accept global settings read**: Everyone with Standard User can read all settings
2. **Only settings:write can be scoped**: Your boundaries only restrict write access
3. **Don't create redundant scoped read policies**: They add nothing if Standard User is assigned

### What You CAN Scope
- Grail data (logs, metrics, spans, events) - NOT in default policies
- Settings write - use bounded Scoped Settings Write policy (never use Admin User for this)
- Entities read - via boundaries

---

## 6. Terraform Provider Specifics

### Separate Bindings by Level
You cannot mix account-level and environment-level policies in the same `dynatrace_iam_policy_bindings_v2` resource.

### Group Permission Conflicts
If using `dynatrace_iam_permission` separately, add to groups:
```hcl
lifecycle {
  ignore_changes = [permissions]
}
```

### Policy ID vs UUID
The policy `id` is a composite string. Use `uuid` when you only need the policy UUID.

---

## 7. Storage Permissions by Table

### Key Insight
Each Grail table has its own permission and may support different conditions.

### Condition Availability
| Table | dt.security_context | k8s.namespace.name | host.name |
|-------|--------------------|--------------------|-----------|
| logs | ✓ | ✓ | ✓ |
| metrics | ✓ | ✓ | ✓ |
| spans | ✓ | ✓ | ✓ |
| events | ✓ | ✓ | ✓ |
| entities | ✓ | ✗ | ✗ |
| bizevents | ✓ | ✓ | ✓ |

### Gotcha
`storage:entities:read` only supports `entity.type` and `dt.security_context` conditions. Applying a `host.name` boundary to an entities permission results in **unconditional access**.

---

## 8. Settings vs Storage Conditions

### Key Insight
Settings permissions (`settings:objects:read/write`) use different condition namespaces than storage permissions.

- **Storage**: `storage:dt.security_context`
- **Settings**: `settings:dt.security_context`

### Best Practice
Create separate boundaries:
```hcl
# For Grail data
resource "dynatrace_iam_policy_boundary" "bu_data" {
  query = "storage:dt.security_context startsWith \"BU1-\";"
}

# For settings on entities  
resource "dynatrace_iam_policy_boundary" "bu_settings" {
  query = "settings:dt.security_context startsWith \"BU1-\";"
}
```

---

## 9. Group Hierarchy Design

### Recommended Pattern

```
Central Operations
├── Account Admins (full access, no boundaries)
│
Business Unit Level
├── {BU}-Admins (all BU data + settings write)
├── {BU}-Users (all BU data, read only)
│
Application Level (More Restrictive)
├── {Application}-Admins (application data + scoped settings write)
└── {Application}-Users (application data only, read only)
```

### Key Insight
- BU groups use `startsWith "BU1-"` - captures all stages/applications
- Application groups use boundaries that enumerate stages: `startsWith "BU1-PROD-APPLICATION_A"; startsWith "BU1-DEV-APPLICATION_A";`

---

## 10. Avoid 2nd Gen Permission Namespaces

### Key Insight
Several permission namespaces are 2nd Gen constructs and should NOT be used in Grail-only environments:

| 2nd Gen (Avoid) | 3rd Gen Alternative |
|-----------------|---------------------|
| `environment:roles:viewer` | Use `Standard User` default policy |
| `environment:roles:operator` | Use specific 3rd gen permissions |
| `environment:management-zone` | Use `storage:dt.security_context` |
| `tenant:*` | Use account-level policies |

### Why This Matters
- `environment:roles:*` permissions don't respect Grail security_context
- They provide broad, unscoped access to the entire environment
- Mixing 2nd and 3rd gen permissions creates inconsistent access patterns

### Migration Pattern
```
Old: ALLOW environment:roles:viewer;
New: (Use "Standard User" default policy instead)

Old: environment:management-zone startsWith "[App1]"
New: storage:dt.security_context startsWith "BU1-PROD-APP1"
```

---

## 11. Testing and Validation

### Best Practice
1. Create a test group with minimal users
2. Apply policies with boundaries
3. Validate using "Effective Permissions" in Account Management
4. Test actual access via the Dynatrace UI

### Gotcha
Policy binding changes can take a few minutes to propagate. API-level validation is faster than UI verification.

---

## 12. Scaling Considerations

### When to Use Templating
- **Use Templates**: When >3 groups need the same policy with different scope
- **Use Boundaries**: When applying default policies to scoped groups
- **Use Custom Policies**: Only when default policies don't cover the need

### Resource Counts at Scale (10 BUs, 2000 Applications)
| Resource | Count |
|----------|------:|
| Policies | 8 (3 default + 3 templated + 2 custom) |
| Groups | 4,020 (20 BU + 4,000 Application) |
| Boundaries | 4,020 (20 BU + 4,000 Application) |
| Bindings | ~6,040 |
| **Total Terraform Resources** | **~14,087** |

### Boundary Breakdown
| Type | Formula | Count |
|------|---------|------:|
| BU Data | 1 × BU | 10 |
| BU Settings | 1 × BU | 10 |
| Application Data | 1 × Application | 2,000 |
| Application Settings | 1 × Application | 2,000 |

### Performance
- Max 100 statements per policy
- Max 10 conditions per boundary  
- At 16K resources, `terraform plan` may take several minutes
- Consider splitting into modules per BU if performance degrades

---

## 13. Common Mistakes to Avoid

1. **Creating custom policies without checking default policy contents** - Standard User and Admin User cover most common needs

2. **Trying to scope settings:read** - Standard User grants unconditional read, your scoped policy adds nothing

3. **Creating custom SLO Reader/Automation User/Document Reader policies** - Already in Standard User

4. **Creating custom SLO Manager/Automation Admin policies for BU Admins** - Already in Admin Features custom policy

5. **Mixing boundary condition types** in the same binding when conditions don't apply to all permissions

6. **Using Management Zone conditions** for Grail storage permissions

7. **Forgetting to set security_context** in OpenPipeline - data becomes inaccessible to scoped groups

8. **Using `environment:roles:*` permissions** - these are 2nd gen and bypass Grail security_context scoping

9. **Assuming default policies include Grail data read** - They don't! You must create custom policies for storage:logs/metrics/spans/events:read

10. **Using Admin User default policy for BU Admins** - It grants unconditional `settings:objects:write` that cannot be scoped via boundaries. Use Standard User + Admin Features custom policy instead

---

## Summary

The Dynatrace IAM system in Grail is powerful and flexible, but requires careful design:

1. **Security context** is your foundation - get it right in OpenPipeline
2. **Check default policies FIRST** - Standard User and Admin User cover most needs (but see #16 for why Admin User should NOT be used directly)
3. **Grail data read is NEVER in defaults** - you must create custom/templated policies
4. **IAM is additive** - you can't restrict what broader policies grant
5. **Settings read is global** - only settings write can be meaningfully scoped
6. **Boundaries scope data, not features** - use them for storage and settings conditions
7. **Templates scale** - one policy serves thousands of groups via parameters
8. **Test incrementally** - validate effective permissions before rollout
9. **Never use Admin User if you need scoped settings write** - it grants unconditional settings:objects:write that bypasses boundaries

### Minimal Custom Policy Set
For most deployments, you only need:
- **Admin Features (No Settings Write)** (custom) - for BU Admins: automation admin, SLO write, extensions, OpenPipeline, App Engine — replaces Admin User default policy
- **Scoped Grail Data Read** (templated) - logs, metrics, spans, events, bizevents
- **Scoped Settings Write** (templated) - for admins who need scoped config access
- **Scoped Settings Read** (templated) - only useful if NOT using Standard User
- **SLO Manager** (custom) - only for Application Admins (BU Admins get SLO write via Admin Features)

Standard User covers everything else (documents, Davis AI, segments, SLO read, automation read).
Admin User default policy is intentionally NOT used — see Lesson #16.

---

## 14. Project Restructure: iam/ → sample-outputs/ + outputs/

### Change
Restructured the project from a single `iam/` directory to a generator workflow:
- `iam/` → `sample-outputs/` — the existing Terraform config is now a reference sample
- `outputs/` — new target directory for Copilot-generated configurations
- `.github/copilot-instructions.md` — updated to teach Copilot the new generation workflow
- `instructions.md` — added clear `CUSTOMER INPUT START/END` markers so users know exactly where to edit
- `README.md` (root) — created with generation instructions, suggested prompts, and Terraform usage guide

### Why
- The original structure assumed a single static Terraform config. The new structure supports a repeatable generation workflow: edit input → ask Copilot → get Terraform output.
- Keeping the sample separate ensures it's never accidentally overwritten during a new generation.
- Clear input markers in `instructions.md` reduce user confusion about where to provide their environment details.

---

## 15. Terminology Rename: Landscape → Application

### Change
Renamed "landscape" to "application" across all project files — documentation, Terraform variables, resource names, comments, and file names (`bindings_landscape_bindings.tf` → `bindings_application_bindings.tf`).

### Why
- "Landscape" was customer-specific terminology from the original engagement. "Application" is a more universally understood term that maps directly to what most Dynatrace users call their monitored workloads.
- Using "application" makes the project more accessible to new users without requiring them to learn domain-specific vocabulary.

### What Changed
- All `.md`, `.txt`, `.tf`, `.tfvars`, `.example` files updated
- Terraform variable `landscapes` → `applications`, resource names `landscape_*` → `application_*`
- File rename: `bindings_landscape_bindings.tf` → `bindings_application_bindings.tf`
- The `sample-outputs/` directory reflects the new naming as a reference

### Impact
- Existing Terraform state from the old `iam/` directory (which used `landscape` naming) is not affected — it lives in `sample-outputs/` as a reference only.
- New generations via `outputs/` will use `application` naming throughout.

---

## 16. Admin User Default Policy Grants Unconditional Settings Write — Boundaries Cannot Scope It

### Finding
When the **Admin User** default policy is bound to a group **without a boundary**, it grants `settings:objects:write` unconditionally — meaning users can change settings on **any** entity in the environment, regardless of `dt.security_context`.

Even if a **separate** binding attaches a `scoped_settings_write` policy with a boundary, the unbounded Admin User policy already grants the broader permission. **IAM is additive**: the most permissive grant wins.

### Root Cause
The Admin User default policy bundles feature-level permissions (automation admin, SLO write, extensions, etc.) together with `settings:objects:write`. You cannot selectively boundary-scope individual permissions within a default policy — it's all or nothing.

### Correct Approach
To properly scope settings write for BU Admins:
1. **Remove** the Admin User default policy from BU Admin bindings
2. **Create a custom `Admin Features (No Settings Write)` policy** that cherry-picks the specific feature-level permissions needed (automation admin, SLO write, extensions management, OpenPipeline, App Engine)
3. **Keep** only `Scoped Settings Write` (with boundary) for settings write access
4. This ensures `settings:objects:write` is only granted through the bounded policy

### Resolution
This has been fixed in the sample configuration:
- Created `Admin Features (No Settings Write)` custom policy in `policies_custom_policies.tf`
- BU Admin bindings now use `Standard User` + `Admin Features` instead of `Admin User`
- The `Admin User` data source has been removed from `policies_default_policies.tf`
- Settings write for BU Admins now comes exclusively from the bounded `Scoped Settings Write` policy

### Key Takeaway
Never bind a default policy that contains `settings:objects:write` without a boundary if you intend to scope settings access. Default policies are convenient but opaque — always audit what permissions they contain before using them in a scoped IAM model.

---

## 17. Not All Permission Identifiers Are Valid — Validate Before Creating Policies

### Finding
Not all permission identifiers that seem logical are actually valid in the Dynatrace IAM API. Attempting to create a policy with an invalid permission identifier will fail at the API level, even if the permission looks like it should exist based on the namespace pattern.

### Invalid Permissions Discovered
- `hub:catalog-items:install` — **NOT VALID**. The hub namespace only supports `hub:catalog:read`; there is no write or install equivalent.
- `activegate:activegates:read` — **NOT VALID**. No valid `activegate:*` permissions exist at all in the IAM permission model.
- `activegate:activegates:write` — **NOT VALID**. Same as above.

### Valid Related Permissions
- `hub:catalog:read` — IS valid, but there is no `hub:catalog:write` or `hub:catalog-items:install` counterpart.

### How to Validate Permissions
Use the IAM policy validation endpoint before creating policies:

```
POST /iam/v1/repo/account/{accountId}/policies/validation
Body: {"name": "test", "statementQuery": "ALLOW hub:catalog-items:install;"}
```

If the permission is invalid, the API returns an error with details about the unrecognized identifier.

### Sprint Environment Endpoints
For sprint/hardening environments, use these endpoints:
- **SSO Token URL**: `https://sso-sprint.dynatracelabs.com/sso/oauth2/token`
- **IAM API Base**: `https://api-hardening.internal.dynatracelabs.com`

The Terraform provider source code (`dynatrace/rest/credentials.go`) uses these constants:
```go
SprintIAMEndpointURL = "https://api-hardening.internal.dynatracelabs.com"
SprintTokenURL       = "https://sso-sprint.dynatracelabs.com/sso/oauth2/token"
```

### Impact on This Configuration
The `Admin Features (No Settings Write)` custom policy originally included `hub:catalog-items:install` and `activegate:activegates:read/write`. These were removed because they are not valid IAM permission identifiers. The policy now only includes: automation (workflows, calendars, rules), SLO management, extensions management, OpenPipeline configuration, and App Engine management.

### Key Takeaway
Always validate permission identifiers against the IAM API before adding them to policies. The existence of a feature in the Dynatrace UI does not guarantee a corresponding IAM permission identifier exists. Use the validation endpoint to test before committing to Terraform.

---

## 18. All IAM Values Must Be Lowercase (Bucket Names, Tags, Keys, Stages)

<<<<<<< HEAD
### Finding
Grail bucket names must be lowercase. Since `dt.security_context` maps to bucket names, all security context values used in IAM boundaries and binding parameters must also be lowercase. Primary_tags keys, host_group values, variable keys, and stage names should all be lowercase for consistency.
=======
### Discovery
Grail bucket names must be lowercase. Since `dt.security_context` maps to bucket names, and primary_tags, host_group, and other fields should be consistent, ALL IAM-related values must be lowercase throughout the configuration.

### Problem
Grail bucket names must be lowercase. Since `dt.security_context` maps to bucket names, all security context values used in IAM boundaries and binding parameters must also be lowercase. Additionally, primary_tags keys, host_group values, variable keys, and stage names should all be lowercase for consistency and to avoid case-mismatch issues.
>>>>>>> 51bb6e0def3667b7b7589876a37177b267557baf

### Solution
All variable keys and values are defined in lowercase directly:

- **Variable keys**: `"bu1"`, `"petclinic01"` (not `"BU1"`, `"PETCLINIC01"`)
- **Variable values**: `name = "bu1"`, `bu = "bu1"`, `stages = ["prod", "dev"]`
- **Primary tag keys**: `primary_tags.bu` (not `primary_tags.BU`)
- **Host group values**: lowercase throughout
- **Security context format**: `bu1-prod-petclinic01-api` (all lowercase)

Terraform's `lower()` function is retained in boundaries and bindings as a safety net, but with all-lowercase keys it is effectively a no-op:

- **Boundaries**: `lower(each.key)` — safety net
- **Binding parameters**: `lower("${each.key}-")` — safety net

Group names derive from the lowercase keys:
- Group name: `bu1-Admins`, `petclinic01-Users`
- Security context prefix: `bu1-`

### Key Takeaway
Define ALL values lowercase at the source (variable keys, stage names, tag keys, etc.) rather than relying solely on runtime conversion. Keep `lower()` as a defensive measure but do not depend on it as the primary mechanism. This ensures consistency across group names, bucket names, IAM conditions, and documentation.
<<<<<<< HEAD

---

## 19. Scoped Grail Data Read (WHERE Clause) Does NOT Grant Bucket Permissions — Default Read Policies Required

### Finding
A user assigned to both BU-Users and BU-Admins received **"No bucket permissions for table logs"** despite having the `Scoped Grail Data Read` templated policy bound with a BU boundary. The policy uses `WHERE storage:dt.security_context startsWith "bu1-"` but this alone does not grant **bucket-level access** to the underlying Grail tables.

### Root Cause
Grail has two permission layers:

1. **Bucket-level permissions** — granted by the Dynatrace default data read policies (`Read Logs`, `Read Metrics`, `Read Spans`, `Read Events`, `Read BizEvents`). These carry the implicit "you may access this table" grant.
2. **Record-level filtering** — the `WHERE` clause on `storage:dt.security_context` filters which records within the table the user can see.

The `Scoped Grail Data Read` templated policy only provides layer 2 (record-level filtering). It contains `ALLOW storage:logs:read WHERE ...` which tells the IAM engine "allow reading logs that match this condition" — but the user also needs the **bucket-level grant** to even open the table. Without it, Grail rejects the request before any record-level filtering occurs.

### Correct Approach
Bind **both**:
- The **default data read policies** (`Read Logs`, `Read Metrics`, etc.) **with boundaries** — these provide the bucket-level grant, scoped by boundary
- The **Scoped Grail Data Read** templated policy (optional, for defense-in-depth) — adds explicit WHERE-clause-level filtering

Since IAM is additive, having both is safe — the effective access is the union, but since both scope to the same prefix, the result is equivalent.

### Fix Applied
Added the following default policies with boundaries to **all** binding resources (BU Admins, BU Users, Application Admins, Application Users):
- `Read Logs` — with BU or application data boundary
- `Read Metrics` — with BU or application data boundary
- `Read Spans` — with BU or application data boundary
- `Read Events` — with BU or application data boundary
- `Read BizEvents` — with BU or application data boundary

The `Read Entities` policy was already bound with boundaries (it worked because entity access has different bucket mechanics). `Read System Events` remains unbounded (it's not scoped by security_context).

### Key Takeaway
**Custom policies with WHERE conditions provide record-level filtering but do NOT grant bucket access.** You must also bind the corresponding Dynatrace default data read policies (with boundaries for scoping) to grant the bucket-level permission. Always test with a real user after applying Terraform changes — `terraform apply` success does not mean effective permissions are correct.

---

## 20. Admin Features Permissions Are Inherently Tenant-Wide — Cannot Be Scoped by Security Context

### Finding
The `Admin Features (No Settings Write)` custom policy contains feature-level permissions: automation admin, SLO management, extensions management, OpenPipeline configuration, and App Engine management. A customer expected these to be scoped to their BU via boundaries, but **these permission namespaces do not support `dt.security_context` conditions**.

### Root Cause
Only two permission namespaces support `dt.security_context`-based scoping:
- `storage:dt.security_context` — applies to `storage:*` permissions (logs, metrics, spans, events, entities, etc.)
- `settings:dt.security_context` — applies to `settings:*` permissions (settings:objects:read/write)

All other permission namespaces are **feature-level** and operate at the environment/tenant level:

| Permission Namespace | Scope | Can Use security_context? |
|---|---|---|
| `storage:*` | Data-level | ✅ Yes |
| `settings:*` | Entity-level | ✅ Yes |
| `automation:*` | Environment-wide | ❌ No |
| `slo:*` | Environment-wide | ❌ No |
| `extensions:*` | Environment-wide | ❌ No |
| `openpipeline:*` | Environment-wide | ❌ No |
| `app-engine:*` | Environment-wide | ❌ No |
| `document:*` | Environment-wide | ❌ No |

Applying a boundary with `storage:dt.security_context` to an `automation:workflows:write` permission simply has **no effect** — the boundary condition doesn't match the permission namespace, so the permission becomes unconditional.

### Impact on BU Admins
BU Admins with the Admin Features policy can:
- ✅ Read/write data scoped to their BU (via bounded data read + scoped settings write)
- ⚠️ Create/edit/run/admin workflows **across the entire environment**
- ⚠️ Create/edit SLOs **across the entire environment**
- ⚠️ Install/write extensions **across the entire environment**
- ⚠️ Write OpenPipeline configurations **across the entire environment**
- ⚠️ Install/run/delete App Engine apps **across the entire environment**

### Design Trade-Off
This is an intentional trade-off in the current IAM model:
- **Data isolation is strict**: BU Admins can only see and modify data/settings within their BU
- **Feature access is shared**: BU Admins can manage automations, SLOs, and extensions tenant-wide

This is acceptable for most organisations because:
1. Automations and SLOs created by a BU admin can only trigger on data they can see (their BU scope), even though the automation object itself is visible tenant-wide
2. Extensions and OpenPipeline are typically managed by a central platform team anyway

### Alternative If Strict Feature Scoping Is Required
If a customer does NOT want BU Admins to have tenant-wide feature access:
1. **Remove** the `Admin Features` policy from BU Admin bindings
2. **Create a central `Platform-Admins` group** with Admin Features for the platform team only
3. BU Admins retain: Standard User + Scoped Data Read + Scoped Settings Write
4. This means BU Admins lose: automation admin, SLO write, extensions write, OpenPipeline write, App Engine admin — but they keep data and settings access within their BU

### Key Takeaway
Boundaries and `dt.security_context` only scope `storage:*` and `settings:*` permissions. Feature-level permissions (`automation`, `slo`, `extensions`, `openpipeline`, `app-engine`) are inherently environment-wide. If a customer requires strict BU-level feature isolation, those permissions should be reserved for a central admin team, not assigned to BU-level groups.
=======
>>>>>>> 51bb6e0def3667b7b7589876a37177b267557baf
