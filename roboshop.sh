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

    # ====== WAIT FOR INSTANCE TO BE RUNNING ======
    echo "Waiting for instance to be in running state..."
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
    echo "Instance is now running."

    # ====== GET PUBLIC IP ADDRESS ======
    if [ $instance != "frontend" ]
    then
        IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query "Reservations[0].Instances[0].PrivateIpAddress" \
        --output text)
    else
        IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query "Reservations[0].Instances[0].PublicIpAddress" \
        --output text)
    fi


    echo "✅ Instance '$instance' launched successfully."
    echo "🔑 Instance ID: $INSTANCE_ID"
    echo "🌐 Public IP: $IP"

    # Create a JSON file for the record change
    cat > record-set.json <<EOF
    {
    "Comment": "Create or update A record for $instance.$DOMAIN_ID",
    "Changes": [
        {
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "$instance.$DOMAIN_ID",
            "Type": "A",
            "TTL": 1,
            "ResourceRecords": [
            {
                "Value": "$IP"
            }
            ]
        }
        }
    ]
    }
EOF

    # Run the Route 53 update command
    aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch file://record-set.json

    # Clean up
    rm -f record-set.json

done

