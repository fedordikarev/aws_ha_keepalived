#!/bin/sh

source /etc/keepalived/scripts/common.sh

### Check network availability (
instance_id=$( /usr/bin/curl -fs --max-time 1 http://169.254.169.254/latest/meta-data/instance-id )
[ -n "${instance_id}" ] || exit 1

### Check DNS availability
# TODO: use dns name according to $region
host -W 1 ec2.amazonaws.com || exit 1
