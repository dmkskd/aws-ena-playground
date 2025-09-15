#!/bin/bash

# Detach and delete second ENI
aws ec2 detach-network-interface \
    --network-interface-id "$ENI_ID" \
    --force

echo "Detached ENI: $ENI_ID"

# Wait a moment for detachment
sleep 10

# Delete the ENI
aws ec2 delete-network-interface --network-interface-id "$ENI_ID"
echo "Deleted ENI: $ENI_ID"

# Terminate instance
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
echo "Terminating instance: $INSTANCE_ID"

# Wait for instance to terminate
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
echo "Instance terminated"

# Delete security group
aws ec2 delete-security-group --group-id "$SG_ID"
echo "Deleted security group: $SG_ID"
