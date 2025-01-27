#!/bin/bash -x

# Enable logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

REGION="$(/opt/aws/bin/ec2-metadata -z | sed 's/placement: \(.*\).$/\1/')"
INSTANCE_ID="$(/opt/aws/bin/ec2-metadata -i | cut -d' ' -f2)"

echo "Debug: Starting runonce.sh"
echo "Debug: ENI ID to attach: ${eni_id}"
echo "Debug: Instance ID: $${INSTANCE_ID}"

# List all ENIs in the account
echo "Debug: All ENIs:"
aws ec2 describe-network-interfaces --region "$${REGION}" --query 'NetworkInterfaces[*].[NetworkInterfaceId,Description,Status]' --output table

# List ENIs attached to this instance
echo "Debug: ENIs attached to this instance:"
aws ec2 describe-network-interfaces --region "$${REGION}" --filters "Name=attachment.instance-id,Values=$${INSTANCE_ID}" --query 'NetworkInterfaces[*].[NetworkInterfaceId,Attachment.DeviceIndex]' --output table

# Disable source/dest check
aws ec2 modify-instance-attribute --no-source-dest-check \
  --region "$${REGION}" \
  --instance-id "$${INSTANCE_ID}"

# First detach the ENI if it's attached elsewhere
echo "Debug: Attempting to detach ENI ${eni_id} if attached elsewhere"
ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
  --region "$${REGION}" \
  --network-interface-ids "${eni_id}" \
  --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
  --output text)

if [ "$${ATTACHMENT_ID}" != "None" ]; then
  echo "Debug: Detaching ENI ${eni_id} with attachment $${ATTACHMENT_ID}"
  aws ec2 detach-network-interface \
    --region "$${REGION}" \
    --attachment-id "$${ATTACHMENT_ID}" || true
  
  echo "Debug: Waiting for detachment"
  sleep 10
fi

# Attach our pre-created ENI as eth1
end_time=$((SECONDS + 180))
while [ $SECONDS -lt $end_time ]; do
  echo "Attempting to attach ENI ${eni_id}"
  if aws ec2 attach-network-interface \
    --region "$REGION" \
    --instance-id "$INSTANCE_ID" \
    --device-index 1 \
    --network-interface-id "${eni_id}"; then
    
    # Wait for interface to appear
    for i in {1..30}; do
      if ip link show dev eth1; then
        echo "Successfully attached ENI"
        break 2
      fi
      sleep 1
    done
  fi
  echo "Failed to attach ENI, retrying..."
  sleep 5
done

if ! ip link show dev eth1; then
  echo "Failed to attach ENI after 3 minutes"
  exit 1
fi

# start SNAT
systemctl enable snat
systemctl start snat
