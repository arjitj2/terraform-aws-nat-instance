#!/bin/bash -x

aws ec2 modify-instance-attribute --no-source-dest-check \
  --region "$(/opt/aws/bin/ec2-metadata -z  | sed 's/placement: \(.*\).$/\1/')" \
  --instance-id "$(/opt/aws/bin/ec2-metadata -i | cut -d' ' -f2)"

# start SNAT
systemctl enable snat
systemctl start snat