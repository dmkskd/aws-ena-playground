#!/bin/bash

: "${VPC_ID:=vpc-134c0031f6448e3aa}" # Replace with your VPC ID
: "${SUBNET_ID:=subnet-382ed342603bc18aa}"  # Replace with your subnet ID (determines AZ)
: "${AMI_ID:=ami-0fd2b85ee2b4dc969}"  # Amazon Linux 2023 (kernel-6.1) - region specific
: "${INSTANCE_TYPE:=t3.micro}"  # Change as needed (t3.small, m5.large, etc.) - t3.micro in *some* regions is eligible for the free tier

export VPC_ID
export SUBNET_ID
export AMI_ID
export INSTANCE_TYPE

# Create security group and capture ID
SG_ID=$(aws ec2 create-security-group \
    --group-name "ena-playground-sg" \
    --description "Security group for ENA driver testing" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' --output text)

echo "Created security group: $SG_ID"

# Add SSH access
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# Launch instance and capture ID
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ena-playground}]' \
    --query 'Instances[0].InstanceId' --output text)

echo "Created instance: $INSTANCE_ID"

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "Instance is running"

# Create second ENI in same subnet
ENI_ID=$(aws ec2 create-network-interface \
    --subnet-id "$SUBNET_ID" \
    --description "Second ENI for ENA driver testing" \
    --groups "$SG_ID" \
    --query 'NetworkInterface.NetworkInterfaceId' --output text)

echo "Created second ENI: $ENI_ID"

# Attach second ENI to instance
aws ec2 attach-network-interface \
    --network-interface-id "$ENI_ID" \
    --instance-id "$INSTANCE_ID" \
    --device-index 1

echo "Attached ENI $ENI_ID to instance $INSTANCE_ID"

# Display all resource IDs for cleanup reference
echo "========================================"
echo "Resources created - save these for cleanup:"
echo "INSTANCE_ID=$INSTANCE_ID"
echo "ENI_ID=$ENI_ID"
echo "SG_ID=$SG_ID"
echo "VPC_ID=$VPC_ID"
echo "SUBNET_ID=$SUBNET_ID"
echo "========================================"