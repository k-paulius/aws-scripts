#!/usr/bin/env bash

# reusable delegation set caller reference
DELEG_SET_CALLER_REF="urwcghppf"
# hosted zone caller reference
HOSTED_ZONE_CALLER_REF="7ik9vxran"
# domain name
DOMAIN_NAME="domain.com"

#
# Find an existing or create a new reusable delegation set
#
echo "- Checking if a reusable delegation set exists"
deleg_set_id=$(aws route53 list-reusable-delegation-sets --query "DelegationSets[?CallerReference == '$DELEG_SET_CALLER_REF'].Id" --output text)

if [ -n "$deleg_set_id" ]; then
    echo "- Found a reusable delegation set: $deleg_set_id"
else
    echo "- Reusable delegation set not found"
    echo "- Creating a reusable delegation set"
    deleg_set_id=$(aws route53 create-reusable-delegation-set --caller-reference $DELEG_SET_CALLER_REF --query "DelegationSet.Id" --output text)

    if [ $? -ne 0 ]; then
        echo "- Failed to create a reusable delegation set"
        exit
    fi
    echo "- Successfully created a delegation set: $deleg_set_id"
fi

#
# Find an existing or create a new hosted zone
#
echo "- Checking if a hosted zone exists"
hosted_zone_id=$(aws route53 list-hosted-zones --query "HostedZones[?CallerReference == '$HOSTED_ZONE_CALLER_REF'].Id" --output text)

if [ -n "$hosted_zone_id" ]; then
    echo "- Found a hosted zone: $hosted_zone_id"
else
    echo "- Hosted zone not found"
    echo "- Creating a hosted zone"
    hosted_zone_id=$(aws route53 create-hosted-zone \
                         --name $DOMAIN_NAME \
                         --caller-reference $HOSTED_ZONE_CALLER_REF \
                         --delegation-set-id $deleg_set_id \
                         --hosted-zone-config Comment="$DOMAIN_NAME public DNS zone",PrivateZone=false \
                         --query "HostedZone.Id" --output text
                    )

    if [ $? -ne 0 ]; then
        echo "- Failed to create a hosted zone"
        exit
    fi
    echo "- Successfully created a hosted zone: $hosted_zone_id"
fi

#
# Create records for white-label name servers
#
for i in {1..4}; do
    echo "- Processing name server: #$i for hosted zone: $hosted_zone_id"
    name_server=$(aws route53 get-hosted-zone --id $hosted_zone_id --query "DelegationSet.NameServers[$(($i-1))]" --output text)
    ipv4=$(dig +short A $name_server)
    ipv6=$(dig +short AAAA $name_server)
    echo "  - Name Server: $name_server"
    echo "  - IPv4 Address: $ipv4"
    echo "  - IPv6 Address: $ipv6"

    aws route53 change-resource-record-sets \
        --hosted-zone-id $hosted_zone_id \
        --change-batch '{
                            "Changes": [
                                {
                                    "Action": "UPSERT",
                                    "ResourceRecordSet": {
                                        "Name": "'ns$i.$DOMAIN_NAME'",
                                        "Type": "A",
                                        "TTL": 900,
                                        "ResourceRecords": [
                                            {
                                                "Value": "'$ipv4'"
                                            }
                                        ]
                                    }
                                },
                                {
                                    "Action": "UPSERT",
                                    "ResourceRecordSet": {
                                        "Name": "'ns$i.$DOMAIN_NAME'",
                                        "Type": "AAAA",
                                        "TTL": 900,
                                        "ResourceRecords": [
                                            {
                                                "Value": "'$ipv6'"
                                            }
                                        ]
                                    }
                                }
                            ]
                        }'
    echo "  - Created A and AAAA records for white label name server 'ns$i.$DOMAIN_NAME'"
done

# Update NS and SOA records
aws route53 change-resource-record-sets \
    --hosted-zone-id $hosted_zone_id \
    --change-batch '{
                        "Changes": [
                            {
                                "Action": "UPSERT",
                                "ResourceRecordSet": {
                                    "Name": "'$DOMAIN_NAME'",
                                    "Type": "SOA",
                                    "TTL": 1800,
                                    "ResourceRecords": [
                                        {
                                            "Value": "ns1.'$DOMAIN_NAME'. dns.'$DOMAIN_NAME'. 1 7200 900 1209600 86400"
                                        }
                                    ]
                                }
                            },
                            {
                                "Action": "UPSERT",
                                "ResourceRecordSet": {
                                    "Name": "'$DOMAIN_NAME'",
                                    "Type": "NS",
                                    "TTL": 86400,
                                    "ResourceRecords": [
                                        {
                                            "Value": "ns1.'$DOMAIN_NAME'."
                                        },
                                        {
                                            "Value": "ns2.'$DOMAIN_NAME'."
                                        },
                                        {
                                            "Value": "ns3.'$DOMAIN_NAME'."
                                        },
                                        {
                                            "Value": "ns4.'$DOMAIN_NAME'."
                                        }
                                    ]
                                }
                            }
                        ]
                    }'
echo "- Updated NS and SOA records"
