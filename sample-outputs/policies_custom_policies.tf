# ============================================================================
# Custom Policies - Specialized Access
# ============================================================================
# These policies provide specialized access patterns that aren't covered
# by default policies or templated policies.
#
# NOTE: We intentionally avoid using the Admin User default policy because
# it grants unconditional settings:objects:write which cannot be scoped
# via boundaries. Instead, we cherry-pick admin features into a custom
# policy and use the bounded Scoped Settings Write for settings access.
#
# Custom policies:
# - Admin Features: Admin-level capabilities WITHOUT settings write
# - SLO Manager: For Application Admins who need SLO write
# ============================================================================

# ------------------------------------------------------------------------------
# Admin Features Policy - For BU Admins
# ------------------------------------------------------------------------------
# Grants admin-level feature permissions that go beyond Standard User,
# WITHOUT including settings:objects:write. Settings write is handled
# separately via the bounded Scoped Settings Write templated policy.
#
# This replaces the Admin User default policy to avoid granting
# unconditional settings write across the entire environment.
#
# Includes:
#   - Full automation admin (workflows, calendars, rules)
#   - SLO management (read + write)
#   - Extensions management (read + write)
#   - OpenPipeline configuration
#   - App Engine management
#
# NOTE: Hub and ActiveGate permissions are not included because they do
# not have valid IAM permission identifiers in the current API.
# Hub catalog browsing uses hub:catalog:read (already in Standard User).
# ActiveGate management is typically done via environment-level API tokens.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy" "admin_features" {
  name        = "Admin Features (No Settings Write)"
  description = "Admin-level feature access without settings:objects:write. Use with Scoped Settings Write for bounded settings access."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
// Full automation admin (Standard User only has read + SIMPLE write)
ALLOW automation:workflows:read, automation:workflows:write, automation:workflows:run, automation:workflows:admin;
ALLOW automation:calendars:read, automation:calendars:write;
ALLOW automation:rules:read, automation:rules:write;

// SLO management (Standard User only has read)
ALLOW slo:slos:read, slo:slos:write;
ALLOW slo:objective-templates:read;

// Extensions management (Standard User only has read)
ALLOW extensions:definitions:read, extensions:definitions:write;
ALLOW extensions:configurations:read, extensions:configurations:write;

// OpenPipeline configuration
ALLOW openpipeline:configurations:read, openpipeline:configurations:write;

// App Engine management
ALLOW app-engine:apps:install, app-engine:apps:delete, app-engine:apps:run;
EOT
}

# ------------------------------------------------------------------------------
# SLO Manager Policy - For Application Admins
# ------------------------------------------------------------------------------
# Grants SLO write access for admins who don't need full admin privileges.
# Standard User only has read - this adds write capability.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy" "slo_manager" {
  name        = "SLO Manager"
  description = "Full access to manage Service Level Objectives"
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
ALLOW slo:slos:read, slo:slos:write;
ALLOW slo:objective-templates:read;
EOT
}
