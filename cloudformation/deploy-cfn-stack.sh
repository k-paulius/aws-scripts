#!/usr/bin/env bash
set -e

DIR_PATH=$(dirname $(readlink -f $0))
CFN_TEMPLATE_FILE="$DIR_PATH/../aws/cfn/cfn-state-bucket.yaml"

ENV="prod"
STACK_NAME="product-$ENV-cfn-state-bucket"

cfn-lint $CFN_TEMPLATE_FILE

stack_id=$(aws cloudformation describe-stacks --query "Stacks[?StackName == '$STACK_NAME'].StackId" --output text)

if [ -z "$stack_id" ]; then
    echo "Existing stack was not found. Creating a new stack."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body "file://$CFN_TEMPLATE_FILE"
else
    echo "Existing stack was found. Updating stack: $stack_id"
    aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-body "file://$CFN_TEMPLATE_FILE"
fi
