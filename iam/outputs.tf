# ============================================================================
# Outputs
# ============================================================================
# These outputs provide useful information after terraform apply
# ============================================================================

# ------------------------------------------------------------------------------
# Group Outputs
# ------------------------------------------------------------------------------

output "bu_admin_groups" {
  description = "Map of BU Admin group IDs"
  value = {
    for key, group in dynatrace_iam_group.bu_admins : key => {
      id   = group.id
      name = group.name
    }
  }
}

output "bu_user_groups" {
  description = "Map of BU User group IDs"
  value = {
    for key, group in dynatrace_iam_group.bu_users : key => {
      id   = group.id
      name = group.name
    }
  }
}

output "landscape_admin_groups" {
  description = "Map of Landscape Admin group IDs"
  value = {
    for key, group in dynatrace_iam_group.landscape_admins : key => {
      id   = group.id
      name = group.name
    }
  }
}

output "landscape_user_groups" {
  description = "Map of Landscape User group IDs"
  value = {
    for key, group in dynatrace_iam_group.landscape_users : key => {
      id   = group.id
      name = group.name
    }
  }
}

# ------------------------------------------------------------------------------
# Boundary Outputs
# ------------------------------------------------------------------------------

output "bu_boundaries" {
  description = "Map of BU-level boundary IDs"
  value = {
    for key, boundary in dynatrace_iam_policy_boundary.bu_boundary : key => {
      id   = boundary.id
      name = boundary.name
    }
  }
}

output "landscape_boundaries" {
  description = "Map of Landscape-level boundary IDs"
  value = {
    for key, boundary in dynatrace_iam_policy_boundary.landscape_boundary : key => {
      id   = boundary.id
      name = boundary.name
    }
  }
}

# ------------------------------------------------------------------------------
# Policy Outputs
# ------------------------------------------------------------------------------

output "custom_policies" {
  description = "Map of custom policy IDs"
  value = {
    scoped_data_read      = dynatrace_iam_policy.scoped_data_read.id
    scoped_settings_read  = dynatrace_iam_policy.scoped_settings_read.id
    scoped_settings_write = dynatrace_iam_policy.scoped_settings_write.id
    slo_manager           = dynatrace_iam_policy.slo_manager.id
  }
}

# ------------------------------------------------------------------------------
# Summary Output
# ------------------------------------------------------------------------------

output "iam_summary" {
  description = "Summary of created IAM resources"
  value = {
    business_units     = keys(var.business_units)
    landscapes         = keys(var.landscapes)
    groups_created     = length(dynatrace_iam_group.bu_admins) + length(dynatrace_iam_group.bu_users) + length(dynatrace_iam_group.landscape_admins) + length(dynatrace_iam_group.landscape_users)
    boundaries_created = length(dynatrace_iam_policy_boundary.bu_boundary) + length(dynatrace_iam_policy_boundary.landscape_boundary) + length(dynatrace_iam_policy_boundary.landscape_settings_boundary) + length(dynatrace_iam_policy_boundary.bu_settings_boundary)
  }
}
