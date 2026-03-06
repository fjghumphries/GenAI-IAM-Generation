## 1. Objective

Assist in designing IAM policies and related Terraform configuration for a Dynatrace 3rd Gen (Grail) environment in a large enterprise.

Goals:
- Generate IAM using `dt.security_context` and Grail primary fields
- Avoid 2nd-gen constructs (no Management Zones, no `environment:roles:*`)
- Apply governance constraints defined by the central team
- Keep custom policy count minimal — maximise use of Dynatrace default policies

---

## 2. Group Model

Two levels of groups are created. Both levels have two roles. This is fixed — customers do not change the group structure, only the BU and application names they apply to.

### Levels

| Level | Scope | Example group names |
|---|---|---|
| **BU** | All data within a Business Unit (all applications, all stages) | `BU1-Admins`, `BU1-Users` |
| **Application** | Data within one application only (all stages within it) | `PETCLINIC01-Admins`, `PETCLINIC01-Users` |

### Roles

| Role | Base policy | Data access | Settings | SLO write |
|---|---|---|---|---|
| **Admins** (BU level) | Standard User + Admin Features (custom) | Scoped to BU | Write, scoped to BU | Yes (via Admin Features) |
| **Users** (BU level) | Standard User | Scoped to BU | Read only (global) | No |
| **Admins** (Application level) | Standard User + SLO Manager | Scoped to application | Write, scoped to application | Yes (via SLO Manager) |
| **Users** (Application level) | Standard User | Scoped to application | Read only (global) | No |

IMPORTANT! The Admin User default policy is intentionally NOT used for BU Admins because it grants unconditional `settings:objects:write` which cannot be scoped via boundaries. Instead, use a custom "Admin Features" policy that cherry-picks admin capabilities (automation admin, SLO write, extensions, OpenPipeline, App Engine, etc.) WITHOUT settings write. Settings write is granted separately via the bounded Scoped Settings Write templated policy.

IMPORTANT! When deciding how to create policies, make sure you understand what is already included in the default policies. This is published here: https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies

IMPORTANT! Always check Dynatrace documentation IAM Reference to understand valid permissions and conditions before creating policies: https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference

### Customer Input Required

> **⬇️ EDIT THIS SECTION with your BUs, applications, and stages, then ask Copilot to generate the Terraform configuration. ⬇️**

To generate the Terraform configuration, replace the example values below with your actual environment details:

```
<!-- ===================== CUSTOMER INPUT START ===================== -->

Business Units:
  - BU1 (applications: PETCLINIC01)
  - BU2 (applications: PETCLINIC02)

Stages active per application:
  - PROD, DEV

Application-to-BU mapping:
  - PETCLINIC01 → BU1
  - PETCLINIC02 → BU2

<!-- ===================== CUSTOMER INPUT END ======================= -->
```

> Each application belongs to exactly one BU. If two BUs have apps with the same name, use a unique identifier per application (e.g. `BU1-PETCLINIC` and `BU2-PETCLINIC`).

**Instructions:**
1. Replace the BU names (BU1, BU2, ...) with real business unit identifiers.
2. Replace the application names (PETCLINIC01, ...) with real application/deployment names.
3. List all stages that apply (e.g. PROD, DEV, STAGING, TEST).
4. Ensure every application maps to exactly one BU.
5. Once updated, ask GitHub Copilot to generate the configuration (see the project README for suggested prompts).

---

## 3. Core IAM Principles

### 3.1 Primary Grail Fields

These fields exist across all signals and are usable in IAM policy conditions:

- `dt.security_context` — **primary enforcement field**
- `dt.cost.costcenter`
- `dt.cost.product`

### 3.2 Primary Grail Tags (Customer-defined)

Tags use the `primary_tags.<name>` prefix. Planned tags:
- `primary_tags.bu`
- `primary_tags.application`
- `primary_tags.stage`
- Possible future: tier, SOM, ownership team, criticality, component

> **IAM note**: Primary tags may not be directly usable in IAM policy conditions. `dt.security_context` remains the only reliable IAM enforcement field.

---

## 4. Security Context Strategy

### Format

```
dt.security_context = BU-STAGE-APPLICATION-COMPONENT
```

Examples:
- `BU1-PROD-PETCLINIC01-API`
- `BU2-DEV-PETCLINIC02-WEB`

### Rules

- Security context **must always be populated** at ingest time — data without it cannot be properly scoped
- It is **not multi-value**
- Use `startsWith()` for hierarchical scoping (e.g. all of BU1, or all of BU1-PROD)
- Use exact match only when full precision is required

### Enrichment via OneAgent

Security context and primary tags are set directly on the host using `oneagentctl`. The OneAgent service must be stopped first (or use `--restart-service`).

```bash
sudo ./oneagentctl \
  --set-host-group=PETCLINIC02 \
  --set-host-property="primary_tags.BU=BU2" \
  --set-host-property="primary_tags.stage=PROD" \
  --set-host-property="primary_tags.application=PETCLINIC02" \
  --set-host-property="dt.security_context=BU2-PROD-PETCLINIC02" \
  --restart-service
```

This sets:
- `host-group` — used for OneAgent configuration grouping (separate from IAM)
- `primary_tags.*` — custom tags for filtering, segments, and DQL (not directly usable in IAM policies)
- `dt.security_context` — the **IAM enforcement field**; must match the canonical format exactly

> **Note**: `dt.security_context` is set explicitly here rather than derived. This is the most reliable approach — derivation from tags requires OpenPipeline and introduces a dependency on the enrichment pipeline being in place.

