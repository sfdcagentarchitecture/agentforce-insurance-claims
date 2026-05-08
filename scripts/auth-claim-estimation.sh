#!/bin/bash
sf org login web --alias claim-estimation --instance-url https://login.salesforce.com
sf config set target-org claim-estimation
echo "✅ Authenticated to Claim Estimation org"
