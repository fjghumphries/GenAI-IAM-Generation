# ============================================================================
# Policy Boundaries
# ============================================================================
# Boundaries decouple the "What" (permissions) from the "Where" (conditions).
# They restrict access based on dt.security_context field using startsWith()
# for hierarchical scoping as per the governance rules.
#
# Security Context Format: BU-STAGE-APPLICATION-COMPONENT
# Example: BU1-PROD-PETCLINIC01-API
#
# IMPORTANT:
# - Boundaries don't support AND operator - each line is a separate condition
# - Conditions are applied only to permissions that support them
# - storage:dt.security_context applies to Grail storage permissions
# - settings:dt.security_context applies to settings on entities with security context
# ============================================================================

# ------------------------------------------------------------------------------
# BU-Level Boundaries
# These boundaries restrict access to ALL data within a specific Business Unit
# Uses startsWith to match the hierarchical security context pattern
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "bu_boundary" {
  for_each = var.business_units

  name = "Boundary-${each.key}"

  # Boundary query restricts to all data where security_context starts with BU name
  # This captures all stages, applications, and components within the BU
  query = "storage:dt.security_context startsWith \"${each.key}-\";"
}

# ------------------------------------------------------------------------------
# Application-Level Boundaries  
# These boundaries restrict access to data within a specific Application
# More restrictive than BU boundaries - used for application-specific teams
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "application_boundary" {
  for_each = var.applications

  name = "Boundary-${each.key}"

  # Match all stages within this application for this BU
  # Format: BU-*-APPLICATION to capture PROD, DEV, TEST etc.
  # Using multiple lines for each stage since we can't use AND
  query = <<-EOT
storage:dt.security_context startsWith "${each.value.bu}-PROD-${each.key}";
storage:dt.security_context startsWith "${each.value.bu}-DEV-${each.key}";
storage:dt.security_context startsWith "${each.value.bu}-TEST-${each.key}";
EOT
}

# ------------------------------------------------------------------------------
# Settings Boundaries for Application Admins
# These are applied when application admins need to change settings
# Uses settings:dt.security_context for settings on entities
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "application_settings_boundary" {
  for_each = var.applications

  name = "Boundary-${each.key}-Settings"

  # Settings boundary for entities with this security context
  # Note: This applies only to settings on entities that have security context
  query = <<-EOT
settings:dt.security_context startsWith "${each.value.bu}-PROD-${each.key}";
settings:dt.security_context startsWith "${each.value.bu}-DEV-${each.key}";
settings:dt.security_context startsWith "${each.value.bu}-TEST-${each.key}";
EOT
}

# ------------------------------------------------------------------------------
# BU Settings Boundaries
# For BU admins who need to change settings across the entire BU
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "bu_settings_boundary" {
  for_each = var.business_units

  name = "Boundary-${each.key}-Settings"

  # Settings boundary for all entities within the BU
  query = "settings:dt.security_context startsWith \"${each.key}-\";"
}
