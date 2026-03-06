# ============================================================================
# Policy Bindings - Landscape-Level Groups
# ============================================================================
# Bindings for landscape-specific groups with more restrictive access.
# These users only have access to data within their specific landscape.
#
# Security Context Pattern: BU-STAGE-LANDSCAPE-COMPONENT
# Landscape users access: BU-*-LANDSCAPE-* (all stages within landscape)
# ============================================================================

# ------------------------------------------------------------------------------
# Landscape Admin Bindings
# Can change settings scoped to their landscape
# Read access to all landscape data across stages
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "landscape_admins_data" {
  for_each = var.landscapes

  group   = dynatrace_iam_group.landscape_admins[each.key].id
  account = var.account_id

  # Standard User access for basic environment features
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Scoped data read using templated policy
  # Parameter uses BU- prefix but boundary restricts to specific landscape
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.landscape_boundary[each.key].id]
    parameters = {
      # Using BU prefix in parameter, boundary further restricts to landscape
      "security_context_prefix" = "${each.value.bu}-"
    }
  }

  # Entities read scoped to landscape
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.landscape_boundary[each.key].id]
  }

  # System events (not scoped by security_context typically)
  policy {
    id = data.dynatrace_iam_policy.read_system_events.id
  }
}

# Settings bindings for landscape admins - separate resource
resource "dynatrace_iam_policy_bindings_v2" "landscape_admins_settings" {
  for_each = var.landscapes

  group   = dynatrace_iam_group.landscape_admins[each.key].id
  account = var.account_id

  # Scoped settings write - can modify settings for entities in their landscape
  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.landscape_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = "${each.value.bu}-"
    }
  }

  # SLO management (adds write on top of Standard User read)
  policy {
    id = dynatrace_iam_policy.slo_manager.id
  }

  depends_on = [dynatrace_iam_policy_bindings_v2.landscape_admins_data]
}

# ------------------------------------------------------------------------------
# Landscape User Bindings
# Read-only access to data within their specific landscape
# Most restrictive access pattern
# Standard User provides: documents, SLO read, automation read, segments, Davis AI
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "landscape_users_data" {
  for_each = var.landscapes

  group   = dynatrace_iam_group.landscape_users[each.key].id
  account = var.account_id

  # Standard User access for basic environment features
  # Includes: documents, SLOs read, automation read, segments, Davis AI
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Scoped data read using templated policy with landscape boundary
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.landscape_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = "${each.value.bu}-"
    }
  }

  # Entities read scoped to landscape
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.landscape_boundary[each.key].id]
  }

  # Read-only settings access
  policy {
    id         = dynatrace_iam_policy.scoped_settings_read.id
    boundaries = [dynatrace_iam_policy_boundary.landscape_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = "${each.value.bu}-"
    }
  }
}
