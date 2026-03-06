# Dynatrace IAM Generator

> [!WARNING]
> **This project is experimental.** The generated Terraform configurations are a starting point, not a production-ready solution. Real-world deployments will require manual review, iterative adjustments through additional Copilot prompts, and thorough testing before applying to a live Dynatrace account. Always validate with `terraform plan` and verify effective permissions in a non-production environment first.

> [!IMPORTANT]
> **LLM Model Matters.** This project was developed and tested with **Claude Opus 4.6** via GitHub Copilot. The quality of generated IAM configurations depends heavily on the model used — different models may misunderstand IAM scoping rules, generate invalid permission identifiers, or fail to follow the design constraints in `instructions.md`. If you switch models, verify outputs carefully.

Generate Terraform-managed IAM configurations for Dynatrace Grail (3rd Gen) environments using GitHub Copilot.

This project uses an [`instructions.md`](instructions.md) specification file to define the IAM model. You fill in your Business Units, applications, and stages — GitHub Copilot reads the spec and generates a complete, ready-to-apply Terraform configuration.

---

## Getting Started with VS Code

1. **Open the repository** in Visual Studio Code:
   ```bash
   code "/path/to/GenAI IAM Generation"
   ```
   Or use **File → Open Folder** and select the repository root.

2. **Install GitHub Copilot** — ensure the [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) and [GitHub Copilot Chat](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat) extensions are installed.

3. **Select Claude Opus 4.6** as the Copilot model — click the model selector in Copilot Chat and choose `Claude Opus 4.6`. This is the tested and recommended model.

4. **Copilot instructions are automatic** — the file [`.github/copilot-instructions.md`](.github/copilot-instructions.md) is automatically loaded by GitHub Copilot when you open this workspace. It contains:
   - Critical IAM gotchas (Admin User scoping, permission validation, boundary rules)
   - Generation rules (read `instructions.md` → extract input → write to `outputs/`)
   - Mandatory documentation update rules
   - Links to Dynatrace IAM reference documentation

   You do not need to paste these instructions manually — Copilot reads them on every interaction.

5. **Key reference files** to review before generating:
   - [`instructions.md`](instructions.md) — IAM specification with a clearly marked **Customer Input** section
   - [`LESSONS_LEARNED.md`](LESSONS_LEARNED.md) — Accumulated gotchas and design decisions
   - [`sample-outputs/`](sample-outputs/) — Complete working example to use as a reference

---

## Project Structure

```
.
├── instructions.md                  # IAM specification — edit the Customer Input section
├── LESSONS_LEARNED.md               # Design decisions, gotchas, Dynatrace IAM findings
├── README.md                        # This file
├── .github/
│   └── copilot-instructions.md      # Rules Copilot follows during generation
│
├── sample-outputs/                  # Complete reference sample (2 BUs, 2 applications, 2 stages)
│   ├── sample-instructions.md       # The instructions.md used to produce this sample
│   ├── *.tf                         # Terraform configuration files
│   ├── docs/                        # Human-readable documentation (see below)
│   │   ├── policies.txt
│   │   ├── groups.txt
│   │   └── bindings.txt
│   └── README.md                    # Architecture overview for the sample config
│
└── outputs/                         # ← YOUR generated Terraform files go here
    ├── *.tf
    ├── docs/
    └── README.md
```

### Key Files

| File | Purpose |
|------|---------|
| [`instructions.md`](instructions.md) | An **example** IAM specification showing the expected format. Contains design rules and a clearly marked Customer Input section. You are encouraged to write your own `instructions.md` tailored to your organisation's IAM requirements — this file is just a starting point. |
| [`LESSONS_LEARNED.md`](LESSONS_LEARNED.md) | A living knowledge base of design decisions, Dynatrace IAM gotchas, and findings accumulated during development. Copilot updates it automatically when new insights arise. Review it to understand *why* the configuration is structured the way it is. |
| `sample-outputs/` | A complete, working example generated from 2 BUs × 2 applications × 2 stages. Use it as a reference to understand what Copilot will produce. The `sample-instructions.md` inside shows the exact input that was used. |
| `outputs/` | Where Copilot writes your generated Terraform files. This directory mirrors the structure of `sample-outputs/`. |

### The `docs/` Folder

Every generated configuration (and the sample) includes a `docs/` subfolder with three plain-text reference files:

| File | Contents |
|------|----------|
| `docs/policies.txt` | Complete list of all IAM policies (default, templated, custom) with descriptions and permission statements. |
| `docs/groups.txt` | Group hierarchy showing every group, its role, base policies, and capabilities at a glance. |
| `docs/bindings.txt` | Mapping of which policies are bound to which groups, with what boundaries and parameters. |

These files are **not consumed by Terraform** — they exist purely as human-readable documentation so you can review and share the IAM design without reading HCL. Copilot keeps them in sync with the `.tf` files automatically.

---

## How to Generate IAM Configurations

### Step 1 — Edit `instructions.md`

Open [`instructions.md`](instructions.md) and find the **Customer Input Required** section. It is clearly marked with `CUSTOMER INPUT START` / `CUSTOMER INPUT END` comments. Replace the example values with your actual environment:

```text
Business Units:
  - FINANCE (applications: SAP01, SAP02)
  - RETAIL (applications: ECOMMERCE01, POS01)

Stages active per application:
  - PROD, STAGING, DEV

Application-to-BU mapping:
  - SAP01 → FINANCE
  - SAP02 → FINANCE
  - ECOMMERCE01 → RETAIL
  - POS01 → RETAIL
```

> **Rules:** Each application belongs to exactly one BU. If two BUs have apps with the same name, use a unique identifier (e.g. `BU1-PETCLINIC`, `BU2-PETCLINIC`).

### Step 2 — Ask Copilot to Generate

Open GitHub Copilot Chat (in VS Code or on github.com) and use one of these prompts:

<details>
<summary><strong>Suggested Prompts</strong> (click to expand)</summary>

**Basic generation:**
```
Generate the Terraform IAM configuration from instructions.md
```

**Full generation with explanation:**
```
Read instructions.md, extract the customer input, and generate the complete
Terraform IAM configuration into outputs/. Include all .tf files, docs, and README.
```

**Re-generate after input changes:**
```
I've updated the customer input in instructions.md. Regenerate the Terraform
configuration in outputs/ to match.
```

**Add a new BU or application:**
```
Add a new BU called LOGISTICS with applications WAREHOUSE01 and FLEET01.
Update all Terraform files and docs in outputs/.
```

</details>

### Step 3 — Review the Output

Copilot generates files in `outputs/` mirroring the structure of `sample-outputs/`:

| File | Purpose |
|------|---------|
| `variables.tf` | BU, application, and stage definitions |
| `boundaries_main.tf` | Policy boundary resources |
| `policies_default_policies.tf` | References to Dynatrace default policies |
| `policies_templated_policies.tf` | Parameterized custom policies |
| `policies_custom_policies.tf` | Additional custom policies |
| `groups_main.tf` | Group definitions |
| `bindings_bu_bindings.tf` | BU-level policy bindings |
| `bindings_application_bindings.tf` | Application-level policy bindings |
| `docs/policies.txt` | Human-readable policy reference |
| `docs/groups.txt` | Human-readable group reference |
| `docs/bindings.txt` | Human-readable bindings reference |
| `README.md` | Architecture overview for the generated config |

---

## How to Initialize and Run Terraform

### Prerequisites

1. **Terraform** v1.0+ — [Install Terraform](https://developer.hashicorp.com/terraform/install)
2. **Dynatrace Account** with appropriate permissions
3. **OAuth Client** configured with these scopes:

   | Scope | Description |
   |-------|-------------|
   | `account-idm-read` | View users and groups |
   | `account-idm-write` | Manage users and groups |
   | `iam-policies-management` | View and manage policies |
   | `account-env-read` | View environments |

### Step 1 — Set Environment Variables

```bash
export DT_CLIENT_ID="your-oauth-client-id"
export DT_CLIENT_SECRET="your-oauth-client-secret"
export DT_ACCOUNT_ID="your-account-uuid"
```

> **Tip:** Store these in a `.env` file (add it to `.gitignore`) and source it: `source .env`

### Step 2 — Initialize Terraform

```bash
cd outputs
terraform init
```

This downloads the [Dynatrace Terraform provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs) and initializes the working directory.

### Step 3 — Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your environment ID and any overrides
```

### Step 4 — Preview Changes

```bash
terraform plan
```

Review the plan carefully — it shows all IAM resources (groups, policies, boundaries, bindings) that will be created.

### Step 5 — Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to create the resources in your Dynatrace account.

### Step 6 — Verify

1. Log into **Dynatrace Account Management**
2. Navigate to **Identity & Access Management → Groups** to verify groups
3. Check **Policies** to confirm policy bindings
4. Use **Effective Permissions** on a test group to validate scoping

> **Note:** Policy binding changes can take a few minutes to propagate. API-level validation is faster than UI verification.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `terraform init` fails | Ensure you have internet access and Terraform v1.0+ installed |
| Authentication errors | Verify `DT_CLIENT_ID`, `DT_CLIENT_SECRET`, and `DT_ACCOUNT_ID` are set correctly |
| `Boundary does not apply` | Ensure boundary conditions use the correct namespace (`storage:` for data, `settings:` for config) |
| Permission denied | Verify OAuth client has all required scopes listed above |
| Slow `terraform plan` | Normal for large configs (>1000 resources). Consider splitting into modules per BU |

---

## References

- [Dynatrace IAM Documentation](https://docs.dynatrace.com/docs/manage/identity-access-management)
- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies) — check what's already included before creating custom policies
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference) — valid permissions and conditions
- [Policy Statement Syntax](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/manage-user-permissions-policies/iam-policystatement-syntax)
- [Policy Boundaries](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/manage-user-permissions-policies/iam-policy-boundaries)
- [Dynatrace Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
