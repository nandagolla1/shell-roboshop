#!/bin/bash

# ====== CONFIGURE THESE VARIABLES ======
AMI_ID="ami-09c813fb71547fc4f"            # Amazon Linux 2 (example)
INSTANCE_TYPE="t3.micro"
SECURITY_GROUP_ID="sg-0a962dc0ca01a7cc1"
INSTANCES=("mongodb" "redis" "mysql" "rebbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
ZONE_ID="Z0241085GWXCWOXHL9YW"
DOMAIN_ID="nanda.cyou"

# ====== CREATE INSTANCE WITH TAG ======
for instance in ${INSTANCES[@]}
do
    echo "Launching EC2 instance named: $instance"

    INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SECURITY_GROUP_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query "Instances[0].InstanceId" \
    --output text)

    echo "Instance launched with ID: $INSTANCE_ID"
done