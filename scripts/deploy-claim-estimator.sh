#!/bin/bash
sf project deploy start \
  --target-org claim-estimation \
  --source-dir orgs/claim-estimation/force-app
echo "✅ Deployed Claim Estimation"
