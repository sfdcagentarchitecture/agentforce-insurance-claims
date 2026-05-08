#!/bin/bash
sf org login web --alias claim-portal --instance-url https://login.salesforce.com
sf config set target-org claim-portal
echo "✅ Authenticated to Claim Portal org"
