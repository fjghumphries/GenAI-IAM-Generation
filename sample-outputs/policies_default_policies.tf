# ============================================================================
# Default Policies - Data Sources
# ============================================================================
# Reference Dynatrace out-of-the-box default policies.
# These policies are maintained by Dynatrace and stay up-to-date with
# platform changes. Use these with boundaries for scoped access.
#
# Key Default Policies:
# - Standard User: Basic environment access + run apps
# - Read Logs/Metrics/Spans/Events/Entities: Grail data access
# - Settings Reader/Writer: Settings API access
# ============================================================================

# ------------------------------------------------------------------------------
# Dynatrace Access Policies (Feature Access)
# ------------------------------------------------------------------------------

data "dynatrace_iam_policy" "standard_user" {
  name = "Standard User"
}

# NOTE: Admin User default policy is intentionally NOT used.
# It grants unconditional settings:objects:write which cannot be scoped.
# Instead, we use the custom Admin Features policy + bounded Scoped Settings Write.
# See LESSONS_LEARNED.md #16 for details.

data "dynatrace_iam_policy" "pro_user" {
  name = "Pro User"
}

# ------------------------------------------------------------------------------
# Data Access Policies (Grail)
# These grant unconditional access - use with boundaries to restrict scope
# ------------------------------------------------------------------------------

data "dynatrace_iam_policy" "read_logs" {
  name = "Read Logs"
}

data "dynatrace_iam_policy" "read_metrics" {
  name = "Read Metrics"
}

data "dynatrace_iam_policy" "read_spans" {
  name = "Read Spans"
}

data "dynatrace_iam_policy" "read_events" {
  name = "Read Events"
}

data "dynatrace_iam_policy" "read_entities" {
  name = "Read Entities"
}

data "dynatrace_iam_policy" "read_bizevents" {
  name = "Read BizEvents"
}

data "dynatrace_iam_policy" "read_system_events" {
  name = "Read System Events"
}

# ------------------------------------------------------------------------------
# Legacy Policies for Settings Access
# ------------------------------------------------------------------------------

data "dynatrace_iam_policy" "settings_reader" {
  name = "Settings Reader"
}

data "dynatrace_iam_policy" "settings_writer" {
  name = "Settings Writer"
}
