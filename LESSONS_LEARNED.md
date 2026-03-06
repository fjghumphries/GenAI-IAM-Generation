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
  --set-host-property="primary_tags.landscape=PETCLINIC02" \
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

## 1. Landscape-to-BU Mapping is 1:1 (Don't Assume Sharing)

### Finding
During initial setup, landscapes were incorrectly modelled as shared across BUs — creating 4 landscape entries (BU1+PETCLINIC01, BU1+PETCLINIC02, BU2+PETCLINIC01, BU2+PETCLINIC02) when in reality each landscape belongs to exactly one BU.

### Root Cause
The Terraform variables.tf landscape map requires unique keys. When two landscapes have the same name (e.g. two apps both called PETCLINIC01 in different BUs), the natural instinct is to prefix the key with the BU. This led to incorrectly assuming that both BUs had both landscapes.

### Correct Model
- Each landscape belongs to ONE BU only
- If landscape names are globally unique (recommended), use the landscape name directly as the map key
- Only use BU-prefixed keys (e.g. `BU1_APPNAME`) when two different BUs genuinely have separate apps with the same name

### Impact
- Incorrect: 4 landscape boundaries + 8 landscape bindings (wasted resources)
- Correct: 2 landscape boundaries + 4 landscape bindings
- Always clarify this mapping with the customer before applying Terraform

---

## 1. Security Context is King

### Key Insight
The `dt.security_context` field is the **primary enforcement mechanism** for IAM in Grail environments. Unlike Management Zones (2nd Gen), which are deprecated for Grail, security context provides hierarchical, scalable access control.

### Best Practice
- Use a consistent, hierarchical format: `BU-STAGE-LANDSCAPE-COMPONENT`
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
2. Use `Admin User` for admin groups - eliminates need for custom automation/SLO policies
3. Use `Standard User` for regular users - already includes documents, Davis AI, etc.
4. Only create custom policies for Grail data read and scoped settings write

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
- Settings write - Admin User has unconditional, but you can assign scoped write instead
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
Landscape Level (More Restrictive)
├── {Landscape}-Admins (landscape data + scoped settings write)
└── {Landscape}-Users (landscape data only, read only)
```

### Key Insight
- BU groups use `startsWith "BU1-"` - captures all stages/landscapes
- Landscape groups use boundaries that enumerate stages: `startsWith "BU1-PROD-LANDSCAPE_A"; startsWith "BU1-DEV-LANDSCAPE_A";`

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

### Resource Counts at Scale (10 BUs, 2000 Landscapes)
| Resource | Count |
|----------|------:|
| Policies | 7 (3 default + 3 templated + 1 custom) |
| Groups | 4,020 (20 BU + 4,000 Landscape) |
| Boundaries | 4,020 (20 BU + 4,000 Landscape) |
| Bindings | ~6,040 |
| **Total Terraform Resources** | **~14,087** |

### Boundary Breakdown
| Type | Formula | Count |
|------|---------|------:|
| BU Data | 1 × BU | 10 |
| BU Settings | 1 × BU | 10 |
| Landscape Data | 1 × Landscape | 2,000 |
| Landscape Settings | 1 × Landscape | 2,000 |

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

4. **Creating custom SLO Manager/Automation Admin policies for BU Admins** - Already in Admin User

5. **Mixing boundary condition types** in the same binding when conditions don't apply to all permissions

6. **Using Management Zone conditions** for Grail storage permissions

7. **Forgetting to set security_context** in OpenPipeline - data becomes inaccessible to scoped groups

8. **Using `environment:roles:*` permissions** - these are 2nd gen and bypass Grail security_context scoping

9. **Assuming default policies include Grail data read** - They don't! You must create custom policies for storage:logs/metrics/spans/events:read

---

## Summary

The Dynatrace IAM system in Grail is powerful and flexible, but requires careful design:

1. **Security context** is your foundation - get it right in OpenPipeline
2. **Check default policies FIRST** - Standard User and Admin User cover most needs
3. **Grail data read is NEVER in defaults** - you must create custom/templated policies
4. **IAM is additive** - you can't restrict what broader policies grant
5. **Settings read is global** - only settings write can be meaningfully scoped
6. **Boundaries scope data, not features** - use them for storage and settings conditions
7. **Templates scale** - one policy serves thousands of groups via parameters
8. **Test incrementally** - validate effective permissions before rollout

### Minimal Custom Policy Set
For most deployments, you only need:
- **Scoped Grail Data Read** (templated) - logs, metrics, spans, events, bizevents
- **Scoped Settings Write** (templated) - for admins who need scoped config access
- **Scoped Settings Read** (templated) - only useful if NOT using Standard User
- **SLO Manager** (custom) - only for Landscape Admins (BU Admins use Admin User)

Everything else is covered by Standard User and Admin User default policies.
