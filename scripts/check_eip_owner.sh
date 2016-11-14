#!/bin/sh

source /etc/keepalived/scripts/common.sh

### Do not check owner if we are not in MASTER state
[ -f "${state_file}" ] || exit 0

### ${elastic_ip} and ${private_ip} are required
[ -n "${elastic_ip}" -a -n "${private_ip}" ] || exit 1

### Get instance_id and verify network availability at the same time
instance_id=$( /usr/bin/curl -fs --max-time 1 http://169.254.169.254/latest/meta-data/instance-id )
[ -n "${instance_id}" ] || exit 1

### Check that DNS works
host -W 1 ec2.amazonaws.com >/dev/null || exit 1

check_eip=$( aws ec2 describe-addresses \
  --cli-read-timeout 1 \
  --region "${region}" \
  --output text \
  --public-ips "${elastic_ip}" )
[ $? -eq 0 ] || exit 1        ### Exit in case of API communication error

eip_owner_is_me=$( echo "$check_eip" | awk "(\$5 == \"${instance_id}\") { print }" )
if [ -n "${eip_owner_is_me}" ]; then
  ### Exit 0 if EIP belongs to us
  exit 0
fi

### If we are in MASTER state but Elastic IP belongs to someone else
### Then try to reassociate it
aws ec2 associate-address \
  --region "${region}" \
  --instance-id "${instance_id}" \
  --public-ip "${elastic_ip}" \
  --private-ip-address "${private_ip}" \
  --allow-reassociation

### Exit anyway with error code as we don't know when elastic ip switchover will occurs
exit 1
