# GitHub Copilot Instructions — Dynatrace IAM Generator

This workspace generates Terraform-managed Dynatrace IAM configurations for Grail (3rd Gen) environments from an `instructions.md` specification file. Follow these rules on every interaction.

Always read the `instructions.md`, `LESSONS_LEARNED.md`, and `sample-outputs/` files before making any changes. They contain critical context about the architecture, design decisions, and gotchas.

IMPORTANT! When deciding how to create policies, make sure you understand what is already included in the default policies. This is published here: https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies

IMPORTANT! Always check Dynatrace documentation IAM Reference to understand valid permissions and conditions before creating policies: https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference

---

## Critical IAM Gotchas

These MUST be kept in mind on every policy or binding change:

1. **Never use Admin User default policy for scoped groups.** Admin User grants unconditional `settings:objects:write` which CANNOT be restricted by boundaries. IAM is additive — the most permissive grant always wins. Use a custom "Admin Features" policy that cherry-picks admin capabilities WITHOUT settings write, then grant settings write separately via a bounded Scoped Settings Write policy. See `LESSONS_LEARNED.md` #16.

2. **Validate permission identifiers before creating policies.** Not all permission strings that look logical are valid. Use the IAM policy validation API endpoint or the IAM Policy Reference documentation to confirm. See `LESSONS_LEARNED.md` #17.

3. **Boundaries only scope the permissions they apply to.** If a group has two bindings — one unbounded with broad permissions and one bounded with the same permissions — the unbounded binding wins. Boundaries are not group-level restrictions; they are per-binding restrictions.

---

## Project Structure

- **`instructions.md`** — IAM specification and design rules. Contains a **Customer Input** section where users define their BUs, applications, and stages.
- **`sample-outputs/`** — A complete sample Terraform output for reference (2 BUs, 2 applications, 2 stages).
- **`outputs/`** — The target directory for newly generated Terraform configurations. All generated files go here.
- **`LESSONS_LEARNED.md`** — Gotchas, design decisions, and findings.

---

## Generation Rules

When asked to generate a Terraform IAM configuration:

1. **Read `instructions.md`** to understand the IAM model, group structure, policies, and constraints.
2. **Extract customer input** from the `Customer Input Required` section in `instructions.md`.
3. **Use `sample-outputs/`** as a reference for file structure, naming conventions, and Terraform patterns.
4. **Write all generated files to `outputs/`** — mirror the same file structure as `sample-outputs/`.

---

## Project Context

- **Provider**: dynatrace-oss/dynatrace ~> 1.91
- **IAM model**: Grail 3rd Gen only — no Management Zones, no `environment:roles:*`
- **Security context format**: `BU-STAGE-APPLICATION-COMPONENT` (e.g. `BU1-PROD-PETCLINIC01-API`)
- **IAM is additive**: permissions compound across bindings. Standard User grants unconditional `settings:objects:read` — settings read cannot be scoped via boundaries, only write can.
- **Generated files** (inside `outputs/`):
  - `variables.tf` — BUs, applications, stages definitions
  - `boundaries_main.tf` — boundary resources
  - `policies_*.tf` — default, templated, and custom policies
  - `groups_main.tf` — group resources
  - `bindings_*.tf` — policy binding resources
  - `docs/policies.txt` — human-readable policy reference
  - `docs/groups.txt` — human-readable group reference
  - `docs/bindings.txt` — human-readable bindings reference
  - `README.md` — architecture overview

---

## Mandatory Update Rules

### Rule 1 — Terraform changes → update docs

Whenever any Terraform file is changed (variables, policies, boundaries, groups, bindings), always update ALL of the following to stay in sync:

| File | What to update |
|---|---|
| `outputs/docs/policies.txt` | Policy list, counts, descriptions |
| `outputs/docs/groups.txt` | Group hierarchy, capabilities, counts |
| `outputs/docs/bindings.txt` | Binding tables, boundary references, counts |
| `outputs/README.md` | Architecture overview, group/policy tables, file structure |

Do not wait to be asked — update them as part of the same response that makes the Terraform change.

### Rule 2 — Lessons learned: always update proactively

Update `LESSONS_LEARNED.md` in ANY of these situations:

1. **A Terraform change reveals a design decision** — document why the change was made and what alternative was rejected.
2. **A user question reveals a misconception, gap, or gotcha** — document the finding even if no code changes are applied. The question itself is evidence of something worth capturing.
3. **An error or unexpected behaviour occurs** — document the root cause and fix.
4. **A new insight about Dynatrace IAM behaviour is discovered** — add it immediately.

`LESSONS_LEARNED.md` is a living document. Err on the side of adding entries, not skipping them.

---

## Doc Update Style Guidelines

- Keep all counts accurate (sample config numbers and at-scale projections)
- In `docs/*.txt` files, preserve the existing plain-text section format with `===` and `---` dividers
- In `README.md`, keep tables and code block formatting
- When updating `LESSONS_LEARNED.md`, add a new `##` section or append to an existing relevant section — never delete existing entries
- Never leave stale examples (e.g. old application names like `APPLICATION_A`) after a rename

---

## What NOT to do

- Do not create additional markdown summary files after changes — update the existing docs instead
- Do not leave `outputs/docs/*.txt` files out of sync with the Terraform configuration
- Do not skip a LESSONS_LEARNED update just because the user didn't explicitly ask for one
- Do not write generated files outside of `outputs/` — the root-level files (`instructions.md`, `LESSONS_LEARNED.md`) are project-level, not per-generation
