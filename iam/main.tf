# ============================================================================
# Main Configuration - Module Composition
# ============================================================================
# This file brings together all the IAM components and can be used
# to add any cross-cutting concerns or additional logic.
# ============================================================================

# The configuration is organized into subdirectories:
# - boundaries/  : Policy boundary definitions
# - policies/    : Custom and default policy references  
# - groups/      : Group definitions
# - bindings/    : Policy-to-group bindings

# Note: Terraform automatically loads all .tf files in subdirectories
# if you use the appropriate directory structure or include statements.
