# GitHub Copilot Instructions — Shell IAM

This workspace contains a Terraform-managed Dynatrace IAM configuration for a Grail (3rd Gen) environment. Follow these rules on every interaction.

---

## Project Context

- **Provider**: dynatrace-oss/dynatrace ~> 1.91
- **IAM model**: Grail 3rd Gen only — no Management Zones, no `environment:roles:*`
- **Security context format**: `BU-STAGE-LANDSCAPE-COMPONENT` (e.g. `BU1-PROD-PETCLINIC01-API`)
- **IAM is additive**: permissions compound across bindings. Standard User grants unconditional `settings:objects:read` — settings read cannot be scoped via boundaries, only write can.
- **Key files**:
  - `iam/variables.tf` — BUs, landscapes, stages definitions
  - `iam/boundaries_main.tf` — boundary resources
  - `iam/policies_*.tf` — default, templated, and custom policies
  - `iam/groups_main.tf` — group resources
  - `iam/bindings_*.tf` — policy binding resources
  - `iam/docs/policies.txt` — human-readable policy reference
  - `iam/docs/groups.txt` — human-readable group reference
  - `iam/docs/bindings.txt` — human-readable bindings reference
  - `iam/README.md` — architecture overview
  - `LESSONS_LEARNED.md` — gotchas, design decisions, and findings

---

## Mandatory Update Rules

### Rule 1 — Terraform changes → update docs

Whenever any Terraform file is changed (variables, policies, boundaries, groups, bindings), always update ALL of the following to stay in sync:

| File | What to update |
|---|---|
| `iam/docs/policies.txt` | Policy list, counts, descriptions |
| `iam/docs/groups.txt` | Group hierarchy, capabilities, counts |
| `iam/docs/bindings.txt` | Binding tables, boundary references, counts |
| `iam/README.md` | Architecture overview, group/policy tables, file structure |

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
- Never leave stale examples (e.g. old landscape names like `LANDSCAPE_A`) after a rename

---

## What NOT to do

- Do not create additional markdown summary files after changes — update the existing docs instead
- Do not leave `iam/docs/*.txt` files out of sync with the Terraform configuration
- Do not skip a LESSONS_LEARNED update just because the user didn't explicitly ask for one
