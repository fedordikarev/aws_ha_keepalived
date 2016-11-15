#!/bin/sh

### Process to monitor 
proc_list="haproxy varnish nginx network"

for proc in $proc_list; do
  service $proc status 2>/dev/null >/dev/null
  if [ $? -eq 0 ]; then
    proc_found=$proc
    break
  fi
done

if [ -z "$proc_found" ]; then
  echo "No process found. Exit."
  exit 1
fi
echo "Found: $proc_found"

my_instance_id=$( /usr/bin/curl -fs http://169.254.169.254/latest/meta-data/instance-id )
region=$( curl -fs http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' )

function get_secondary_ips() {
  instance_id=$1
  not='!' # The way to use exclamation mark with bash
  query="Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[?${not}Primary].PrivateIpAddress"
  aws ec2 describe-instances \
    --output text \
    --region "$region" \
    --instance-ids "${instance_id}" \
    --query "$query"
}
 
function get_ha_tag_value() {
  instance_id="$1"
  aws ec2 describe-instances \
    --output text \
    --region "$region"\
    --instance-ids "${instance_id}" \
    --query "Reservations[*].Instances[*].Tags[?Key=='aws_ha_keepalived'].Value"
}

function get_ha_instances() {
  elastic_ip=$1
  query="Reservations[*].Instances[*].Tags[?Key=='aws_ha_keepalived'].Value"
  aws ec2 describe-instances \
    --output text \
    --region "$region" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --filter "Name=tag:aws_ha_keepalived,Values=${elastic_ip}"
}

elastic_ip=$( get_ha_tag_value "${my_instance_id}" )

if [ -z "${elastic_ip}" ]; then
   echo "Assign \"aws_ha_keepalived\" tag with the value of Elastic IP."
   exit 3
fi

echo "Elastic IP: $elastic_ip"

ha_instances=$( get_ha_instances "${elastic_ip}" )
echo "HA instances: $ha_instances"

for instance in ${ha_instances}; do
  secondary_ips=$( get_secondary_ips "${instance}" )
  secondary_ips_count=$( echo "${secondary_ips}" | wc -l )
  if [ ${secondary_ips_count} -ne 1 -o -z "${secondary_ips}" ]; then
    echo "Instance ${instance} should have exactly one secondary ip"
    exit 3
  fi
  if [ "${instance}" == "${my_instance_id}" ]; then
    local_ip="${secondary_ips}"
  else
    if [ -n "${peer_ips}" ]; then
      peer_ips=$( echo "${peer_ips}"; echo ${secondary_ips} )
    else
      peer_ips="${secondary_ips}"
    fi
  fi
done

echo "
process: $proc_found
region: $region
elastic_ip: $elastic_ip
local_ip: $local_ip
peer_ips: $peer_ips"

if [ -z "$local_ip" -o -z "$peer_ips" ]; then
  echo "At least two instances with exactly one secondary ip must be configured."
  echo "Check your instances configuration"
  exit 4
fi

if [ -w /etc/keepalived/keepalived.conf ]; then
  sed -e "s/%PROCESS%/$proc_found/" \
      -e "s/%LOCAL_IP%/$local_ip/" \
      -e "s/%PEER_IP%/$peer_ips/" \
      /etc/keepalived/keepalived.aws_eip.conf > /etc/keepalived/keepalived.conf
else
  echo "Can't update /etc/keepalived/keepalived.conf"
fi

if [ -w /etc/keepalived/scripts/common.sh ]; then
  sed -e "s/%ELASTIC_IP%/$elastic_ip/" \
      -e "s/%LOCAL_IP%/$local_ip/" \
      -e "s/%REGION%/$region/" \
      /etc/keepalived/scripts/common.sh.tmpl > /etc/keepalived/scripts/common.sh
else
  echo "Can't update /etc/keepalived/scripts/common.sh"
fi
