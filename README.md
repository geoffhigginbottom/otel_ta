# Splunk Add-on for OpenTelemetry Collector - Test Environment

# Introduction

Uses Terraform to deploy a Splunk Enterprise Server (in AWS) and a configurable selection of ec2 instances that are then managed my the Splunk Enterprise Deployment Server functionality.  The Deployment Server deploys a various role specific configurations to each ec2 instance, but more importantly, and the whole point of this tooling, is also deploys the OTel Collector as a TA.

# Requirements

To use this repo, you need an active AWS account. Where possible resources that qualify for the free tier are used by default to enable deployment to AWS trial accounts with minimal costs.

You will also need a Splunk Observability Account so that the OTel TA can send in metrics.

# Setup

After cloning the repo, you need to generate and configure a terraform.tfvars file that will be unique to you and will not be synced back to the repo (if you are contributing to this repo).

Copy the included terraform.tfvars.example file to terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Update the contents of terraform.tfvars replacing any value that is XXXXX etc to suit your environment.  Note some values have been pre-populated with typical values, ensure you review every setting and update as appropriate.

Any value can be removed or commented out with a #, by doing so Terraform will prompt you for the appropriate value at run time.

You will need to download various files to the machine where you run Terraform from, and place them in a folder which is specified in the "splunk_enterprise_files_local_path" variable, these are files that are not easily accessed on the fly by terraform at deployment time.  Other files such as the Universal Forwarder are download by the target ec2 instances directly from splunkbase etc.

# Important

This is still a work in progress so use at your own risk