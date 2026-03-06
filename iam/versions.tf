# ============================================================================
# Terraform and Provider Configuration
# ============================================================================
# This file defines the required Terraform version and providers.
# The Dynatrace provider is used to manage IAM resources.
# ============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.91"
    }
  }
}
