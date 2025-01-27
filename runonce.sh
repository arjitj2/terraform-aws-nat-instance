#!/bin/bash -x

# Enable logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

echo "Debug: Starting runonce.sh"
echo "Debug: ENI ID to attach: ${eni_id}"

# Get IMDSv2 token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Get instance metadata using IMDSv2
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)

# Debug output
echo "Debug: Token: $TOKEN"
echo "Debug: Instance ID: $INSTANCE_ID"
echo "Debug: Region: $REGION"

# Disable source/dest check
aws ec2 modify-instance-attribute --no-source-dest-check \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID"

# First detach the ENI if it's attached elsewhere
echo "Debug: Attempting to detach ENI ${eni_id} if attached elsewhere"
ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
  --region "$REGION" \
  --network-interface-ids "${eni_id}" \
  --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
  --output text)

if [ "$ATTACHMENT_ID" != "None" ] && [ "$ATTACHMENT_ID" != "null" ]; then
  echo "Debug: Detaching ENI ${eni_id} with attachment $ATTACHMENT_ID"
  aws ec2 detach-network-interface \
    --region "$REGION" \
    --attachment-id "$ATTACHMENT_ID" || true
  
  echo "Debug: Waiting for detachment"
  sleep 10
fi

# Attach ENI and wait for it to appear
echo "Attempting to attach ENI ${eni_id}"
aws ec2 attach-network-interface \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --device-index 1 \
  --network-interface-id "${eni_id}"

# Wait up to 60 seconds for interface to appear
for i in {1..60}; do
  if sudo ip link show dev eth1; then
    echo "Successfully attached ENI"
    break
  fi
  sleep 1
done

if ! sudo ip link show dev eth1; then
  echo "Failed to attach ENI after 1 minute"
  exit 1
fi

# start SNAT
sudo systemctl enable snat
sudo systemctl start snat
