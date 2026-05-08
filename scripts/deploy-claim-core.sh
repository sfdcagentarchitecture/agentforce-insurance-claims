#!/bin/bash
sf project deploy start \
  --target-org claim-portal \
  --source-dir orgs/claim-portal/force-app
echo "✅ Deployed Claim Portal"
