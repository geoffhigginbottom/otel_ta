terraform {
  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "~> 9.8"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}
