# Splunk Add-on for OpenTelemetry Collector - Test Environment

## Introduction

Uses Terraform to deploy a Splunk Enterprise Server (in AWS) and a configurable selection of ec2 instances that are then managed by the Splunk Enterprise Deployment Server functionality.  The Deployment Server deploys various role specific configurations to each ec2 instance, but more importantly, and the whole point of this tooling, is also deploys the OTel Collector as a TA.

## Requirements

To use this repo, you need an active AWS account. Where possible resources that qualify for the free tier are used by default to enable deployment to AWS trial accounts with minimal costs.

You will also need a Splunk Observability Account so that the OTel TA can send in metrics.

## Setup

After cloning the repo, you need to generate and configure a terraform.tfvars file that will be unique to you and will not be synced back to the repo (if you are contributing to this repo).

Copy the included terraform.tfvars.example file to terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Update the contents of terraform.tfvars replacing any value that is XXXXX etc to suit your environment.  Note some values have been pre-populated with typical values, ensure you review every setting and update as appropriate.

Any value can be removed or commented out with a #, by doing so Terraform will prompt you for the appropriate value at run time.

S3 is used to store a number of files that are used by the instances, so create a private S3 bucket that can be used for this purpose - ensure it is private and not public - the name will be recorded below in terraform.tfvars.

There are three folders that get synchronized into this bucket at run time (there is no need to manually create these in the bucket):

- config_files
- scripts
- non_public_files

The contents of config_files and scripts are included in the repo, but the non_public_files folder will need to be created in the root of your local repo and populated before your 1st run of terraform.  The non_public_files folder stores files that are not publicly available so you will need to download these from splunkbase / sharepoint and place them in the non_public_files folder.  This folder does not get stored in github.

The following files need to be added from Spunk Base (these will need updating on a regular basis):

- [Splunk Enterprise](https://www.splunk.com/en_us/download/splunk-enterprise.html)
- [Config Explorer](https://splunkbase.splunk.com/app/4353)
- [Splunk Add-On for OpenTelemetry Collector](https://splunkbase.splunk.com/app/7125)
- [Splunk Add-on for Unix and Linux](https://splunkbase.splunk.com/app/833)
- [Splunk Universal Forwarder](https://www.splunk.com/en_us/download/universal-forwarder.html)

The following License Files need to be added (update based on current date window):

- Splunk_Enterprise_NFR_1H_2025.xml

### terraform.tfvars

The following describes each section of terraform.tfvars:

#### Instance Quantities

Choose which ec2 instances you want to deploy by setting the value to 1 (more can be deployed, but one of each is normally sufficient for testing)

```yaml
## Instance Quantities ##
mysql_count         = "1"
ms_sql_count        = "1"
apache_web_count    = "1"
rocky_count         = "0"
```

Note: The Rocky VM is slow to deploy, so deploy the rest first, then add this if required and re-run terraform deploy, it will then be added

##### Optional: deploy a Gateway node and nodes that use the Gateway to send data to O11Y

If you want to test the functionality of the Gateway Mode, add a single Gateway (max 1 gateway) and associated instances.  When deployed these instances will get an agent_config.yaml that is configured to send all OTel traffic via the Gateway Instance.

```yaml
gateway_count        = "0"
mysql_gw_count       = "0"
apache_web_gw_count  = "0"
ms_sql_gw_count      = "0"
```

### AWS Variables

#### Region

When you run the deployment terraform will prompt you for a Region, however if you enable the setting here, and populate it with a numerical value representing your preferred AWS Region, it will save you having to enter a value on each run. The settings for this are controlled via variables.tf, but the valid options are:

- 1: eu-west-1
- 2: eu-west-3
- 3: eu-central-1
- 4: us-east-1
- 5: us-east-2
- 6: us-west-1
- 7: us-west-2
- 8: ap-southeast-1
- 9: ap-southeast-2
- 10: sa-east-1

```yaml
## Region Settings ##
#region = "<REGION>"
```

The "eip" value should be for an Elastic IP in the region that you are using, and this in turn should be mapped to the "fqdn" value within the "certificates" section below.  This will be used to generate certificates on the Splunk Enterprise Server to enable UI access via FQDN and also Log Observer Connect to be used and configured with a FQDN.

```yaml
eip    = "15.188.7.167"
```

#### VPC Settings

A new VPC is created and used for the deployment, this should ensure there are no conflicts with any other deployments you may have.  The number of subnets is controlled by the 'subnet_count' parameter, and defaults to 2 which should be sufficient for most test cases.

Two sets of subnets will be created, a Private and a Public Subnet, so by default 4 subnets will be created. Each Subnet will be created using a CIDR allocated from the 'vpc_cidr_block', so by default the 1st subnet will use 172.32.0.0/24, the 2nd subnet will use 172.32.1.0/24 etc.

```yaml
## VPC Settings ##
vpc_cidr_block = "172.32.0.0/16"
subnet_count   = "2"
```

#### Auth Settings

Terraform needs to authenticate with AWS in order to create the resources and also access each instance using a Key Pair.  Create a user such as "Terraform" within AWS and attach the default "AdministratorAccess" policy.  Add the access_key details to enable your local terraform to authenticate using this account.  Ensure there is a Key Pair created in each region you intend to use so that terraform can login to each ec2 instance to run commands. Ensure the private_key_path maps to the location of your id_rsa file that is associated with the Key Pair you are using.

```yaml
## Auth Settings ##
key_name                = "XXXX"
private_key_path        = "~/.ssh/id_rsa"
instance_type           = "t2.micro"
rocky_instance_type     = "t2.small"
gateway_instance_type   = "t2.small"
aws_access_key_id       = "XXXX"
aws_secret_access_key   = "XXXX"
```

#### S3

S3 is used to store a number of files that are used by the instances, you should have created the bucket and populated it with the required files during the initial setup steps above, enter the name of the bucket here.

```yaml
## S3 ##
s3_bucket_name          = "XXXX"
```

#### Splunk IM/APM Variables

Settings used by Splunk IM/APM for authentication, notifications and APM Environment.  An example of an Environment value would be "tf-demo", it's a simple tag used to identify and link the various components within the Splunk APM UI. Collector Versions can be found [here](https://github.com/signalfx/splunk-otel-collector/releases).

```yaml
### Splunk IM/APM Variables ###
access_token                     = "XXXX"
api_url                          = "https://api.eu0.signalfx.com"
realm                            = "eu0"
environment                      = "otel-ta-testing"
```

#### Splunk Enterprise Variables

You will need to update the versions of Splunk Enterprise and Universal Forwarder install files based on the version you wish to deploy.  

The "splunk_ent_eip" value should be for an EIP in the region that you are using, and this in turn should be mapped to the "fqdn" value within the "certificates" section below.  This will be used to generate certificates on the Splunk Enterprise Server to enable UI access via FQDN and also Log Observer Connect to be used and configured with a FQDN.

The "splunk_private_ip" is set here to enable the Universal Forwarders to 'check-in' with the Splunk Enterprise Instances via their private subnet, if changed it needs to be from the "vpc_cidr_block" setting above.

All the *filename* files should have been added to the "non_public_files" folder which gets synced with S3.

```yaml
### Splunk Enterprise Variables ###
splunk_admin_pwd                        = "XXXX"
splunk_private_ip                       = "172.32.2.10"
gw_private_ip                           = "172.32.2.100"
proxy_server_private_ip                 = "172.32.2.200"
splunk_ent_filename                     = "splunk-9.4.1-e3bdab203ac8-linux-amd64.deb"
splunk_ent_version                      = "9.4.1"
splunk_ent_inst_type                    = "t2.2xlarge"
universalforwarder_filename             = "splunkforwarder-9.4.1-e3bdab203ac8-linux-amd64.deb"
universalforwarder_filename_rpm         = "splunkforwarder-9.4.1-e3bdab203ac8.x86_64.rpm"
windows_universalforwarder_url          = "https://download.splunk.com/products/universalforwarder/releases/9.4.1/windows/splunkforwarder-9.4.1-e3bdab203ac8-windows-x64.msi"
windows_universalforwarder_filename     = "splunkforwarder-9.4.1-e3bdab203ac8-windows-x64.msi"
splunk_enterprise_license_filename      = "Splunk_Enterprise_NFR_1H_2025.xml"
splunk_enterprise_ta_linux_filename     = "splunk-add-on-for-unix-and-linux_920.tgz"
splunk_cloud_uf_filename                = "splunkclouduf.spl"
splunk_ta_otel_filename                 = "splunk-add-on-for-opentelemetry-collector_141.tgz"
config_explorer_filename                = "config-explorer_1716.tgz"

### Certificate Vars ###
certpath    = "/opt/splunk/etc/auth/sloccerts"
passphrase  = "XXXX"
fqdn        = "XXXX"
country     = "GB"
state       = "London"
location    = "London"
org         = "ACME"
```

#### VM Variables

The final sections detail some role specific settings for the Windows MS SQL, Windows Server and MySql Instances.

```yaml
### MS SQL Server Variables ###
ms_sql_user              = "XXXX"
ms_sql_user_pwd          = "XXXX"
ms_sql_administrator_pwd = "XXXX"
ms_sql_instance_type     = "t3.xlarge"

### Windows Server Variables ###
windows_server_administrator_pwd = "XXXX"
windows_server_instance_type     = "t3.xlarge"

### MySQL Server Variables ###
mysql_user     = "XXXX"
mysql_user_pwd = "XXXX"
mysql_instance_type = "t3.xlarge"
```
