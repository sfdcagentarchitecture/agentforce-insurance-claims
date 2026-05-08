# Agentforce Insurance Claims — Reference Implementation

A two-org Agentforce + Data Cloud implementation for insurance claim submission
and estimation. Built on Salesforce Developer Edition orgs with Agentforce and
Data Cloud enabled.

---

## Architecture Overview

| Org | Purpose |
|---|---|
| `claim-portal` | Customer-facing Experience Site + Claim Submission Agent |
| `claim-estimation` | Estimation engine, Data Cloud, REST API (called by Org 1) |

The two orgs communicate via **Named Credentials + Apex REST** — Org 1 submits
claims and uploads files, Org 2 processes estimation and returns results back
to the agent.

---

## Prerequisites

- Salesforce CLI (`sf`) — [Install guide](https://developer.salesforce.com/tools/salesforcecli)
- Git
- VS Code + [Salesforce Extension Pack](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)
- Two Salesforce Developer Edition orgs with **Agentforce + Data Cloud** enabled
  - Sign up: https://www.salesforce.com/form/signup/freetrial-lex-agentforce/

---

## Getting Started

### 1. Clone the repo
```bash
git clone git@github-sfdcagent:sfdcagentarchitecture/agentforce-insurance-claims.git
cd agentforce-insurance-claims
```

### 2. Authenticate both orgs
```bash
bash scripts/auth-claim-portal.sh
bash scripts/auth-claim-estimation.sh
```

### 3. Deploy to each org
```bash
bash scripts/deploy-claim-portal.sh
bash scripts/deploy-claim-estimation.sh
```

---

## Repo Structure

cat > orgs/claim-portal/sfdx-project.json << 'EOF'
{
  "packageDirectories": [
    {
      "path": "force-app",
      "default": true,
      "package": "ClaimPortal",
      "versionName": "v1.0",
      "versionNumber": "1.0.0.NEXT"
    }
  ],
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "63.0"
}
