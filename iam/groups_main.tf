# ============================================================================
# IAM Groups Configuration
# ============================================================================
# Groups are created at the account level and can be assigned policies
# at either the account level (all environments) or environment level.
#
# Group Hierarchy:
# - BU Level Groups: Access to all data within a Business Unit
#   - {BU}-Admins: Full admin access within the BU
#   - {BU}-Users: Read-only access within the BU
#
# - Landscape Level Groups: Access to specific landscape only
#   - {Landscape}-Admins: Can change settings scoped to landscape
#   - {Landscape}-Users: Read-only access to landscape data
#
# Note: Using lifecycle ignore_changes for permissions because we manage
# permissions via dynatrace_iam_policy_bindings_v2 resource
# ============================================================================

# ------------------------------------------------------------------------------
# BU-Level Admin Groups
# These users have full access to all data and settings within their BU
# ------------------------------------------------------------------------------

resource "dynatrace_iam_group" "bu_admins" {
  for_each = var.business_units

  name        = "${each.key}-Admins"
  description = "Administrators for ${each.value.description}. Full access to all ${each.key} data and settings."

  lifecycle {
    ignore_changes = [permissions]
  }
}

# ------------------------------------------------------------------------------
# BU-Level User Groups
# These users have read access to all data within their BU
# No write access to settings
# ------------------------------------------------------------------------------

resource "dynatrace_iam_group" "bu_users" {
  for_each = var.business_units

  name        = "${each.key}-Users"
  description = "Users for ${each.value.description}. Read access to all ${each.key} data."

  lifecycle {
    ignore_changes = [permissions]
  }
}

# ------------------------------------------------------------------------------
# Landscape-Level Admin Groups
# These users can change settings for entities within their landscape
# Scoped by security_context to their specific landscape
# ------------------------------------------------------------------------------

resource "dynatrace_iam_group" "landscape_admins" {
  for_each = var.landscapes

  name        = "${each.key}-Admins"
  description = "Administrators for ${each.value.description} (${each.value.bu}). Can manage settings for this landscape."

  lifecycle {
    ignore_changes = [permissions]
  }
}

# ------------------------------------------------------------------------------
# Landscape-Level User Groups
# These users have read-only access to data within their landscape
# Most restrictive access - only their specific landscape
# ------------------------------------------------------------------------------

resource "dynatrace_iam_group" "landscape_users" {
  for_each = var.landscapes

  name        = "${each.key}-Users"
  description = "Users for ${each.value.description} (${each.value.bu}). Read-only access to landscape data."

  lifecycle {
    ignore_changes = [permissions]
  }
}
