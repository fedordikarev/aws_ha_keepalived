#!/bin/sh

source /etc/keepalived/scripts/common.sh

### ${elastic_ip} and ${private_ip} are required
[ -n "${elastic_ip}" -a -n "${private_ip}" ] || exit 1

[ -n "${state_file}" ] && touch "${state_file}"

instance_id=$( /usr/bin/curl -fs http://169.254.169.254/latest/meta-data/instance-id )

aws ec2 associate-address \
  --region "${region}" \
  --instance-id "${instance_id}" \
  --public-ip "${elastic_ip}" \
  --private-ip-address "${private_ip}" \
  --allow-reassociation
