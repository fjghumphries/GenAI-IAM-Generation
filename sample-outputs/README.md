# Dynatrace IAM Configuration

This repository contains Terraform configurations for managing Dynatrace Identity and Access Management (IAM) resources, specifically designed for a Grail-based (3rd Gen) Dynatrace environment.

## Architecture Overview

### Security Context Strategy

All IAM enforcement uses the `dt.security_context` field with the format:

```
BU-STAGE-APPLICATION-COMPONENT
```

Examples:
- `BU1-PROD-PETCLINIC01-API`
- `BU2-PROD-PETCLINIC02-WEB`

### Access Control Hierarchy

```
Account Level
├── BU-Level Groups
│   ├── {BU}-Admins          → Full access to all BU data and settings
│   └── {BU}-Users           → Read access to all BU data
│
└── Application-Level Groups
    ├── {Application}-Admins → Read data + write settings for application
    └── {Application}-Users  → Read-only access to application data
```

## Files Structure

```
sample-outputs/
├── versions.tf                        # Terraform and provider versions
├── provider.tf                        # Dynatrace provider configuration
├── variables.tf                       # Input variables
├── terraform.tfvars.example           # Example variable values
├── outputs.tf                         # Output definitions
├── main.tf                            # Main configuration notes
├── boundaries_main.tf                 # Policy boundary definitions
├── policies_default_policies.tf       # References to Dynatrace default policies
├── policies_templated_policies.tf     # Parameterized custom policies
├── policies_custom_policies.tf        # Additional custom policies
├── groups_main.tf                     # Group definitions
├── bindings_bu_bindings.tf            # BU-level policy bindings
├── bindings_application_bindings.tf   # Application-level policy bindings
└── sample-instructions.md             # Customer input instructions
```

## Prerequisites

1. **Dynatrace Account** with appropriate permissions
2. **OAuth Client** configured with these scopes:
   - `account-idm-read` - View users and groups
   - `account-idm-write` - Manage users and groups
   - `iam-policies-management` - View and manage policies
   - `account-env-read` - View environments

3. **Environment Variables** set:
   ```bash
   export DT_CLIENT_ID="your-client-id"
   export DT_CLIENT_SECRET="your-client-secret"
   export DT_ACCOUNT_ID="your-account-uuid"
   ```

## Usage

### 1. Initialize Terraform

```bash
cd sample-outputs
terraform init
```

### 2. Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Review Changes

```bash
terraform plan
```

### 4. Apply Changes

```bash
terraform apply
```

## Key Concepts

### Boundaries

Boundaries decouple permissions (the "What") from scope (the "Where"). They contain conditions that restrict access based on security_context:

- **BU Boundaries**: `storage:dt.security_context startsWith "BU1-";`
- **Application Boundaries**: Include all stages within an application

### Templated Policies

Parameterized policies reduce management overhead by enabling reuse:

```hcl
ALLOW storage:logs:read 
  WHERE storage:dt.security_context startsWith "${bindParam:security_context_prefix}";
```

Bound with different parameter values for different groups.

### Default Policies

This configuration uses Dynatrace default policies to minimize custom policy overhead:
- `Standard User` - For all users (documents, Davis AI, automation read, SLO read)
- `Read Entities` - Entity access with boundaries
- `Read System Events` - System event access

**Note**: The `Admin User` default policy is intentionally **not used** because it grants unconditional `settings:objects:write` that cannot be scoped via boundaries. Instead, we use a custom `Admin Features` policy that provides admin capabilities without settings write.

## Group Permissions Summary

| Group | Base Policy | Data Access | Settings | Automation | SLOs |
|-------|-------------|-------------|----------|------------|------|
| BU-Admins | Std User + Admin Features | All BU data | Write (scoped) | Full Admin | Manager |
| BU-Users | Standard User | All BU data | Read (global) | Limited | Reader |
| Application-Admins | Standard User | Application data | Write (scoped) | Limited | Manager |
| Application-Users | Standard User | Application data | Read (global) | Limited | Reader |

## Customization

### Adding New Business Units

Add to `variables.tf` or `terraform.tfvars`:

```hcl
business_units = {
  "BU3" = {
    name         = "BU3"
    description  = "New Business Unit"
    applications = ["APP_E", "APP_F"]
  }
}
```

### Adding New Applications

```hcl
applications = {
  "PETCLINIC03" = {
    name        = "PETCLINIC03"
    description = "PetClinic 03 - BU1"
    bu          = "BU1"
    stages      = ["PROD", "DEV"]
  }
}
```

> **Note**: Application map keys must be unique. If an application name is shared across BUs,
> prefix the key with the BU (e.g. `BU1_APPNAME`). The `name` field drives the security context.

## Troubleshooting

### "Boundary does not apply"
Boundaries only apply when their conditions match the permission's supported attributes. Ensure you're using:
- `storage:dt.security_context` for Grail storage permissions
- `settings:dt.security_context` for settings on entities with security context

### Permission Denied
Verify:
1. OAuth client has required scopes
2. Environment variables are set correctly
3. Account ID is correct (without `urn:dtaccount:` prefix)

## References

- [Dynatrace IAM Documentation](https://docs.dynatrace.com/docs/manage/identity-access-management)
- [Policy Statement Syntax](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/manage-user-permissions-policies/iam-policystatement-syntax)
- [Policy Boundaries](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/manage-user-permissions-policies/iam-policy-boundaries)
- [IAM Policy Reference](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/iam-policy-reference)
- [Default Policies](https://docs.dynatrace.com/docs/manage/identity-access-management/permission-management/default-policies)
- [Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
