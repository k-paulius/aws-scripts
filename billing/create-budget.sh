#!/usr/bin/env bash

# Create budget with alerts
aws budgets create-budget \
    --account-id 123456789012 \
    --budget file://monthly-10usd-budget.json \
    --notifications-with-subscribers file://notifications-with-subscribers.json

# Verify it was successfully created
aws budgets describe-budgets --account-id 123456789012
