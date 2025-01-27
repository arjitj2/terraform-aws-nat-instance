#!/bin/bash -x

# Enable logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

REGION="$(/opt/aws/bin/ec2-metadata -z | sed 's/placement: \(.*\).$/\1/')"
INSTANCE_ID="$(/opt/aws/bin/ec2-metadata -i | cut -d' ' -f2)"

# Disable source/dest check
aws ec2 modify-instance-attribute --no-source-dest-check \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID"

# Attach our pre-created ENI as eth1
aws ec2 attach-network-interface \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --device-index 1 \
  --network-interface-id "${eni_id}"

# Wait for network interface to be ready
while ! ip link show dev eth1; do
  sleep 1
done

# start SNAT
systemctl enable snat
systemctl start snat
