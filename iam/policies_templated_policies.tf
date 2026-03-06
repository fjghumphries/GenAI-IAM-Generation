# ============================================================================
# Custom Policies - Using Templating
# ============================================================================
# These policies use the bindParam templating feature for reusability.
# A single policy template can be bound to multiple groups with different
# parameter values, reducing policy management overhead.
#
# Security Context Format: BU-STAGE-LANDSCAPE-COMPONENT
# Uses startsWith() for hierarchical scoping as per governance rules.
#
# IMPORTANT:
# - Parameters must be provided at binding time
# - Changes to bound policies are only allowed if parameter set doesn't change
# - Use comma-separated values for IN operator: "value1,value2,value3"
# ============================================================================

# ------------------------------------------------------------------------------
# Scoped Data Read Policy (Templated)
# ------------------------------------------------------------------------------
# This policy grants read access to Grail data scoped by security_context.
# Use this instead of default "Read *" policies when you need scoped access.
# Bind with boundary for additional restrictions.
#
# Parameters:
#   - security_context_prefix: The dt.security_context prefix to match
#
# Example binding: security_context_prefix = "BU1-" for all BU1 data
# Example binding: security_context_prefix = "BU1-PROD-LANDSCAPE_A" for specific scope
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy" "scoped_data_read" {
  name        = "Scoped Grail Data Read"
  description = "Grants read access to Grail data scoped by security_context prefix. Use bindParam for the scope."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
// Scoped read access to all Grail tables based on security_context
// The security_context_prefix parameter is provided at binding time

// Logs access
ALLOW storage:logs:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";

// Metrics access  
ALLOW storage:metrics:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";

// Spans/traces access
ALLOW storage:spans:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";

// Events access (excluding security events)
ALLOW storage:events:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";

// Business events access
ALLOW storage:bizevents:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";

// Entities access
ALLOW storage:entities:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";

// Smartscape access for topology
ALLOW storage:smartscape:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";

// User sessions and events (DEM data)
ALLOW storage:user.sessions:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW storage:user.events:read 
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
EOT
}

# ------------------------------------------------------------------------------
# Scoped Settings Read Policy (Templated)
# ------------------------------------------------------------------------------
# This policy grants read access to settings on entities with matching security_context.
#
# Parameters:
#   - security_context_prefix: The dt.security_context prefix to match
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy" "scoped_settings_read" {
  name        = "Scoped Settings Read"
  description = "Grants read access to settings scoped by security_context. Use bindParam for the scope."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
// Read settings for entities with matching security_context
ALLOW settings:objects:read 
  WHERE settings:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW settings:schemas:read;
EOT
}

# ------------------------------------------------------------------------------
# Scoped Settings Write Policy (Templated) - For Admins
# ------------------------------------------------------------------------------
# This policy grants write access to settings on entities with matching security_context.
# Should be assigned to landscape admins for scoped configuration changes.
#
# Parameters:
#   - security_context_prefix: The dt.security_context prefix to match
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy" "scoped_settings_write" {
  name        = "Scoped Settings Write"
  description = "Grants write access to settings scoped by security_context. For admins only."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
// Read and write settings for entities with matching security_context
ALLOW settings:objects:read, settings:objects:write
  WHERE settings:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW settings:schemas:read;
EOT
}
