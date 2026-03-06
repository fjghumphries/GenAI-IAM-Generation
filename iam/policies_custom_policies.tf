# ============================================================================
# Custom Policies - Specialized Access
# ============================================================================
# These policies provide specialized access patterns that aren't covered
# by default policies or templated policies.
#
# NOTE: Default policies cover most needs:
# - Standard User: documents, SLO read, automation read/limited write, segments, Davis AI
# - Admin User: Full automation admin, SLO write, settings write, extensions, etc.
#
# Custom policies are only needed for:
# - SLO Manager: For Landscape Admins who need SLO write but not full Admin User
# ============================================================================

# ------------------------------------------------------------------------------
# SLO Manager Policy - For Landscape Admins
# ------------------------------------------------------------------------------
# Grants SLO write access for admins who don't need full Admin User privileges.
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
