#!/usr/bin/env bash

HOSTED_ZONE_ID="Z0312968CKFOEXAMPLE"
DOMAIN_NAME="domain.com"

name_sever_list=""
for i in {1..4}; do
    echo "- Processing name server: #$i for hosted zone $HOSTED_ZONE_ID"
    name_server=$(aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --query "DelegationSet.NameServers[$(($i-1))]" --output text)
    ipv4=$(dig +short A $name_server)
    ipv6=$(dig +short AAAA $name_server)
    name_sever_list+="Name=ns$i.$DOMAIN_NAME,GlueIps=$ipv4,$ipv6 "

    echo "  - Name Server: $name_server"
    echo "  - IPv4 Address: $ipv4"
    echo "  - IPv6 Address: $ipv6"
done
echo "- Name Server List: $name_sever_list"
echo "- Updating name severs for $DOMAIN_NAME"
aws route53domains update-domain-nameservers --domain-name $DOMAIN_NAME --nameservers $name_sever_list
