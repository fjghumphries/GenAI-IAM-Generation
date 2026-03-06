# ============================================================================
# Policy Bindings - BU-Level Groups
# ============================================================================
# Bindings connect groups to policies, optionally with boundaries.
# These bindings are for BU-level groups (access to all data within a BU).
#
# IMPORTANT: Boundaries are only applied where conditions match the permission.
# - Use storage:dt.security_context boundaries for Grail data policies
# - Use settings:dt.security_context boundaries for settings policies
# - Don't mix boundaries that don't apply to the policy permissions
# ============================================================================

# ------------------------------------------------------------------------------
# BU Admin Bindings
# Full access to Grail data + settings/automation admin within their BU
# Uses Admin User default policy + boundaries for data scoping
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "bu_admins_data" {
  for_each = var.business_units

  group   = dynatrace_iam_group.bu_admins[each.key].id
  account = var.account_id

  # Admin User provides: full automation admin, SLO write, settings write, extensions, etc.
  policy {
    id = data.dynatrace_iam_policy.admin_user.id
  }

  # Scoped data read using templated policy with BU prefix parameter
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = "${each.key}-"
    }
  }

  # Additional data access policies with BU boundary
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id = data.dynatrace_iam_policy.read_system_events.id
  }
}

# Separate binding for scoped settings - uses settings boundary
# Note: Admin User has unconditional settings:write, boundary scopes it
resource "dynatrace_iam_policy_bindings_v2" "bu_admins_settings" {
  for_each = var.business_units

  group   = dynatrace_iam_group.bu_admins[each.key].id
  account = var.account_id

  # Scoped settings write using templated policy
  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.bu_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = "${each.key}-"
    }
  }

  depends_on = [dynatrace_iam_policy_bindings_v2.bu_admins_data]
}

# ------------------------------------------------------------------------------
# BU User Bindings  
# Read-only access to Grail data within their BU
# Uses BU boundary to scope access
# Standard User provides: documents, SLO read, automation read, segments, Davis AI
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "bu_users_data" {
  for_each = var.business_units

  group   = dynatrace_iam_group.bu_users[each.key].id
  account = var.account_id

  # Standard User access for basic environment features
  # Includes: documents, SLOs read, automation read, segments, Davis AI
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Scoped data read using templated policy with BU prefix parameter
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = "${each.key}-"
    }
  }

  # Entities read with BU scope
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  # Read-only settings access
  policy {
    id         = dynatrace_iam_policy.scoped_settings_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = "${each.key}-"
    }
  }
}
