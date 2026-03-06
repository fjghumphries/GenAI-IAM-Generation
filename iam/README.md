# Dynatrace IAM Configuration

This repository contains Terraform configurations for managing Dynatrace Identity and Access Management (IAM) resources, specifically designed for a Grail-based (3rd Gen) Dynatrace environment.

## Architecture Overview

### Security Context Strategy

All IAM enforcement uses the `dt.security_context` field with the format:

```
BU-STAGE-LANDSCAPE-COMPONENT
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
└── Landscape-Level Groups
    ├── {Landscape}-Admins   → Read data + write settings for landscape
    └── {Landscape}-Users    → Read-only access to landscape data
```

## Files Structure

```
iam/
├── versions.tf                      # Terraform and provider versions
├── provider.tf                      # Dynatrace provider configuration
├── variables.tf                     # Input variables
├── terraform.tfvars.example         # Example variable values
├── outputs.tf                       # Output definitions
├── main.tf                          # Main configuration notes
├── boundaries_main.tf               # Policy boundary definitions
├── policies_default_policies.tf     # References to Dynatrace default policies
├── policies_templated_policies.tf   # Parameterized custom policies
├── policies_custom_policies.tf      # Additional custom policies
├── groups_main.tf                   # Group definitions
├── bindings_bu_bindings.tf          # BU-level policy bindings
└── bindings_landscape_bindings.tf   # Landscape-level policy bindings
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
cd iam
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
- **Landscape Boundaries**: Include all stages within a landscape

### Templated Policies

Parameterized policies reduce management overhead by enabling reuse:

```hcl
ALLOW storage:logs:read 
  WHERE storage:dt.security_context startsWith "${bindParam:security_context_prefix}";
```

Bound with different parameter values for different groups.

### Default Policies

This configuration uses Dynatrace default policies to minimize custom policy overhead:
- `Admin User` - For BU Admins (full automation, SLO write, settings write)
- `Standard User` - For all other users (documents, Davis AI, automation read, SLO read)
- `Read Entities` - Entity access with boundaries
- `Read System Events` - System event access

**Note**: Default policies don't include Grail data read (logs, metrics, spans, events). We use templated policies for scoped data access.

## Group Permissions Summary

| Group | Base Policy | Data Access | Settings | Automation | SLOs |
|-------|-------------|-------------|----------|------------|------|
| BU-Admins | Admin User | All BU data | Write (scoped) | Full Admin | Manager |
| BU-Users | Standard User | All BU data | Read (global) | Limited | Reader |
| Landscape-Admins | Standard User | Landscape data | Write (scoped) | Limited | Manager |
| Landscape-Users | Standard User | Landscape data | Read (global) | Limited | Reader |

## Customization

### Adding New Business Units

Add to `variables.tf` or `terraform.tfvars`:

```hcl
business_units = {
  "BU3" = {
    name        = "BU3"
    description = "New Business Unit"
    landscapes  = ["LANDSCAPE_E", "LANDSCAPE_F"]
  }
}
```

### Adding New Landscapes

```hcl
landscapes = {
  "PETCLINIC03" = {
    name        = "PETCLINIC03"
    description = "PetClinic 03 - BU1"
    bu          = "BU1"
    stages      = ["PROD", "DEV"]
  }
}
```

> **Note**: Landscape map keys must be unique. If a landscape name is shared across BUs,
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
- [Terraform Provider](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
