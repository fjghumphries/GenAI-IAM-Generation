# ============================================================================
# Dynatrace Provider Configuration
# ============================================================================
# Configure the Dynatrace provider using environment variables:
#   - DT_CLIENT_ID: OAuth client ID
#   - DT_CLIENT_SECRET: OAuth client secret
#   - DT_ACCOUNT_ID: Dynatrace account UUID
#   - DYNATRACE_ENV_URL: Environment URL (for environment-level policies)
#
# Required OAuth permissions:
#   - account-idm-read: View users and groups
#   - account-idm-write: Manage users and groups
#   - iam-policies-management: View and manage policies
#   - account-env-read: View environments
# ============================================================================

provider "dynatrace" {
  # The provider will use environment variables for authentication:
  # DT_CLIENT_ID, DT_CLIENT_SECRET, DT_ACCOUNT_ID
  # Optionally: DYNATRACE_ENV_URL for environment-specific resources
}
