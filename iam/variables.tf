# ============================================================================
# Variables Configuration
# ============================================================================
# This file defines all variables used across the IAM configuration.
# Security context format: BU-STAGE-LANDSCAPE-COMPONENT
# Example: BU1-PROD-LANDSCAPE_A-API
# ============================================================================

# ------------------------------------------------------------------------------
# Account Configuration
# ------------------------------------------------------------------------------
variable "account_id" {
  description = "The Dynatrace Account UUID (without urn:dtaccount: prefix)"
  type        = string
}

variable "environment_id" {
  description = "The Dynatrace Environment ID (e.g., abc12345)"
  type        = string
}

# ------------------------------------------------------------------------------
# Business Units (BUs)
# Using sample BU names - in production these would be actual BU identifiers
# ------------------------------------------------------------------------------
variable "business_units" {
  description = "Map of Business Units with their configuration"
  type = map(object({
    name        = string
    description = string
    landscapes  = list(string)
  }))
  default = {
    "BU1" = {
      name        = "BU1"
      description = "Business Unit 1"
      landscapes  = ["PETCLINIC01"]
    }
    "BU2" = {
      name        = "BU2"
      description = "Business Unit 2"
      landscapes  = ["PETCLINIC02"]
    }
  }
}

# ------------------------------------------------------------------------------
# Landscapes (previously called deployments/applications)
# Each landscape belongs to a specific BU
# ------------------------------------------------------------------------------
variable "landscapes" {
  description = "Map of Landscapes with their configuration"
  type = map(object({
    name        = string
    description = string
    bu          = string
    stages      = list(string)
  }))
  # Each landscape belongs to exactly one BU, so no BU prefix needed in keys.
  # The 'name' field is the actual landscape identifier used in security contexts.
  # Security context format: {BU}-{STAGE}-{name}  e.g. BU1-PROD-PETCLINIC01
  default = {
    "PETCLINIC01" = {
      name        = "PETCLINIC01"
      description = "PetClinic 01 - belongs to BU1"
      bu          = "BU1"
      stages      = ["PROD", "DEV"]
    }
    "PETCLINIC02" = {
      name        = "PETCLINIC02"
      description = "PetClinic 02 - belongs to BU2"
      bu          = "BU2"
      stages      = ["PROD", "DEV"]
    }
  }
}

# ------------------------------------------------------------------------------
# Stages (environments within each landscape)
# ------------------------------------------------------------------------------
variable "stages" {
  description = "List of deployment stages"
  type        = list(string)
  default     = ["PROD", "DEV"]  # TEST not used yet; add when needed
}

# ------------------------------------------------------------------------------
# Common Tags for Resources
# ------------------------------------------------------------------------------
variable "tags" {
  description = "Tags to apply to all IAM resources"
  type        = set(string)
  default     = ["managed-by-terraform", "shell-iam"]
}
