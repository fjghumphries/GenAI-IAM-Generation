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
# Full access to Grail data + admin features within their BU
# Uses Standard User + Admin Features (custom) instead of Admin User
# to ensure settings:objects:write is ONLY granted via bounded policy
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "bu_admins_data" {
  for_each = var.business_units

  group   = dynatrace_iam_group.bu_admins[each.key].id
  account = var.account_id

  # Standard User provides: documents, Davis AI, segments, SLO read, automation read
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Admin Features adds: full automation admin, SLO write, extensions write,
  # OpenPipeline, App Engine, etc. — WITHOUT settings:objects:write
  policy {
    id = dynatrace_iam_policy.admin_features.id
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
# This is now the ONLY source of settings:objects:write for BU Admins
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
