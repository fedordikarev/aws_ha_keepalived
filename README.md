# AWS HighAvailability with Keepalived and Elastic IP
## Intro
Here are some scripts that allows reliably failover Elastic IP with Keepalived.

## Why do I need it?
As there may be some delays or even failures in Elastic IP switchover, Keepalived should
constantly check owner of Elastic IP and allow other instance to become MASTER if something went wrong.

## Requirements
1. VRRP protocol must be allowed for Inbound Secuirty Group.
1. Instances must belong to IAM role with permissions to assign Elastic IP.

## Generating configuration
1. You have to replace `%PROCESS%`, `%REGION%`, `%LOCAL_IP%`, `%PEER_IP%`, `%ELASTIC_IP%` with your actual values.
1. Or you could add tag `aws_ha_keepalived` to instances with the value of your Elastic IP and run `generate_aws_ha_keepalived.sh` script. For that case each instance must have exactly one secondary private ip address which will be used for Keepalived unicast communications and for Elastic IP address assignment.
