# IAM Specification

This file defines **what** to generate. For **how** to generate it, see `.github/copilot-instructions.md`. For gotchas and design rationale, see `LESSONS_LEARNED.md`.

---

## 1. Customer Configuration

> **Edit this section with your environment details, then ask Copilot to generate the Terraform configuration.**

### 1.1 Business Units & Applications

Each application belongs to exactly one BU. If two BUs have apps with the same name, use a unique identifier (e.g. `bu1-petclinic`, `bu2-petclinic`).

```yaml
business_units:
  bu1:
    applications: [petclinic01]
  bu2:
    applications: [petclinic02]
  bu3:
    applications: [petclinic03]
```

### 1.2 Stages

Stages active per application (same for all applications):

```yaml
stages: [prod, dev]
```

### 1.3 Security Context Format

```
dt.security_context = {bu}-{stage}-{application}-{component}
```

All values **must be lowercase** (Grail bucket names require it).

Examples:
- `bu1-prod-petclinic01-api`
- `bu2-dev-petclinic02-web`

### 1.4 Primary Tags

Customer-defined tags set on hosts via `oneagentctl`. Used for filtering, segments, and DQL — **not** for IAM enforcement (only `dt.security_context` is used for IAM).

```yaml
primary_tags:
  - primary_tags.bu
  - primary_tags.application
  - primary_tags.stage
  # Possible future: tier, SOM, ownership team, criticality, component
```

### 1.5 Additional Grail Fields

These built-in fields exist across all signals and can be used in IAM policy conditions:

- `dt.security_context` — **primary enforcement field**
- `dt.cost.costcenter`
- `dt.cost.product`

---

## 2. Group Model

Two levels × two roles = **4 group types**. This structure is fixed — only the BU and application names change per customer.

### 2.1 Groups Created

| Level | Role | Group name pattern | Example |
|---|---|---|---|
| BU | Admins | `{bu}-Admins` | `bu1-Admins` |
| BU | Users | `{bu}-Users` | `bu1-Users` |
| Application | Admins | `{app}-Admins` | `petclinic01-Admins` |
| Application | Users | `{app}-Users` | `petclinic01-Users` |

### 2.2 Role Capabilities

| Capability | BU Admins | BU Users | App Admins | App Users |
|---|---|---|---|---|
| **Base policy** | Standard User | Standard User | Standard User | Standard User |
| **Data access** | Scoped to BU | Scoped to BU | Scoped to app | Scoped to app |
| **Settings write** | Yes, scoped to BU | No | Yes, scoped to app | No |
| **Settings read** | Global (via Standard User) | Global (via Standard User) | Global (via Standard User) | Global (via Standard User) |
| **SLO write** | Yes (via Admin Features) | No | Yes (via SLO Manager) | No |
| **Automation admin** | Yes (via Admin Features) | No | No | No |
| **Extensions write** | Yes (via Admin Features) | No | No | No |
| **OpenPipeline write** | Yes (see §3.2) | No | No | No |
| **Anomaly detection write** | Yes (see §3.3) | Yes (see §3.3) | Yes (see §3.3) | Yes (see §3.3) |

---

## 3. Policy Design Rules

### 3.1 Admin Features Policy (BU Admins only)

A **custom** policy that replaces the Admin User default policy. Cherry-picks admin capabilities **without** `settings:objects:write`:

- `automation:workflows:write, admin`
- `automation:calendars:write`
- `automation:rules:write`
- `slo:slos:write`
- `extensions:definitions:write, configurations:write`
- `app-engine:apps:install, run, delete`

Settings write is granted separately via the **Scoped Settings Write** templated policy (`policies_templated_policies.tf`), which uses a `settings:dt.security_context startsWith "{bu}-"` boundary. This means settings changes (entity configuration, alerting, etc.) are restricted to entities whose security context matches the BU prefix. This is the **only** source of `settings:objects:write` in the configuration — Admin Features deliberately omits it.

> **Scoping note:** Feature-level permissions (`automation:*`, `slo:*`, `extensions:*`, `app-engine:*`) are **inherently tenant-wide** — they cannot be scoped by `dt.security_context`, and boundaries have no effect on them. BU Admins can manage automations, SLOs, and extensions across the entire environment. Only `storage:*` and `settings:*` permissions support security context scoping. See `LESSONS_LEARNED.md` #20.

> **Why not Admin User?** Admin User grants unconditional `settings:objects:write` which **cannot** be scoped via boundaries. IAM is additive — the most permissive grant always wins.

### 3.2 OpenPipeline Access

Use **Settings 2.0 schemas**, not the old `openpipeline:configurations:*` API.

**Granted** (BU Admins only) — pipeline creation/editing per signal:
```
settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.<signal>.pipelines"
```
Applied for all 13 signal types:
`bizevents`, `davis.events`, `davis.problems`, `events`, `events.sdlc`, `events.security`, `logs`, `metrics`, `security.events`, `spans`, `system.events`, `user.events`, `usersessions`.

**Not granted** (reserved for central platform team):
- `builtin:openpipeline.<signal>.routing` — routing decisions
- `builtin:openpipeline.<signal>.pipeline-groups` — pipeline group configuration

### 3.3 Anomaly Detection Write

**All** group types (Admins and Users at both levels) get:
```
settings:objects:write WHERE settings:schemaGroup = "group:anomaly-detection"
```
Bound **without boundaries** — the `schemaGroup` condition is the scope control.

### 3.4 SLO Manager Policy (Application Admins only)

A custom policy granting `slo:slos:write`. BU Admins already get this via Admin Features (§3.1), so this policy exists only for Application Admins.

---

## 4. Security Context Enrichment

Security context is set **directly on the host** via `oneagentctl` — not derived from tags via OpenPipeline. This guarantees `dt.security_context` is present from first ingest.

```
azureuser@tomcat-frontend01:/opt/dynatrace/oneagent/agent/tools$ sudo ./oneagentctl \
  --restart-service \
  --set-host-group=bu1-petclinic01 \
  --set-host-property="primary_tags.bu=bu1" \
  --set-host-property="primary_tags.stage=prod" \
  --set-host-property="primary_tags.application=petclinic01" \
  --set-host-property="dt.security_context=bu1-prod-petclinic01" \
  --set-host-property="dt.cost.costcenter=bu1" \
  --set-host-property="dt.cost.product=petclinic01"
```

Key points:
- `--restart-service` is **required** — without it, changes are not applied
- `host-group` follows `{bu}-{application}` format for OneAgent configuration grouping (separate from IAM)
- `primary_tags.*` are for filtering/DQL only — not usable in IAM policies
- `dt.security_context` must match the format in §1.3 exactly
- `dt.cost.costcenter` and `dt.cost.product` are optional Grail cost allocation fields (see §1.5)
- `startsWith()` is used for hierarchical scoping (e.g. all of `bu1-`, or `bu1-prod-`)
