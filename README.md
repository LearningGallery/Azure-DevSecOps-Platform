# Azure DevSecOps Platform

**Enterprise-Grade Infrastructure as Code**

This repository contains a Microsoft Cloud Adoption Framework (CAF)-compliant, zero-trust Azure infrastructure designed to host DevSecOps tooling platforms. The deployment is fully automated using Terraform and orchestrated through a highly resilient GitHub Actions CI/CD pipeline.

---

## 🏛️ Architecture Overview

The infrastructure enforces strict security boundaries and zero-trust principles:

* **Network Isolation:** Deployed within a dedicated Virtual Network (VNet) with segmented subnets (e.g., `snet-containers`).
* **Secure Access:** Utilizes **Azure Bastion (Developer SKU)** for lightweight, secure, and seamless RDP/SSH connectivity directly over the Azure portal without exposing Public IPs.
* **Zero-Trust Storage & Secrets:** Azure Key Vault and Azure Storage Accounts are deployed with default-deny firewalls.
* **Private Connectivity:** Integrated with Azure Private Link and Private DNS Zones (e.g., `privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`) to keep data-plane traffic entirely on the Microsoft backbone.

---

## 🚀 CI/CD Pipeline Design

The deployment lifecycle is managed via GitHub Actions. To prevent blast-radius incidents and matrix-related workflow failures, environments (UAT and PROD) are physically separated into distinct workflow files.

### Workflow Automation Files

The `.github/workflows/` directory contains strictly separated job chains:

* `terraform-plan-uat.yml` / `terraform-plan-prod.yml`: Triggered automatically on pushes to `main`. Runs `terraform fmt`, `init`, and generates a detailed Plan summary.
* `terraform-apply-uat.yml` / `terraform-apply-prod.yml`: Listens for a successful Plan on its respective environment. Pauses execution using **GitHub Environment Protection Rules** until an authorized human reviewer explicitly approves the deployment.
* `terraform-destroy-uat.yml` / `terraform-destroy-prod.yml`: Air-gapped from automated triggers. Executable *only* via manual `workflow_dispatch` to prevent accidental infrastructure teardowns.

### Self-Healing PowerShell Wrappers

Terraform execution is wrapped in robust PowerShell scripts (`Review-TerraformPlan.ps1`, `Apply-Terraform.ps1`, `Destroy-Terraform.ps1`). These scripts provide enterprise features:

* **Dynamic Telemetry & Formatting:** Intercepts native Terraform output and generates clean, color-coded summary tables directly in the GitHub Actions console.
* **Automated Firewall Bypass (Targeted Apply):** Because GitHub Hosted Runners use ephemeral IPs, the scripts automatically execute a surgical `-target` apply to whitelist the current runner's IP on the Key Vault and Storage Account firewalls. It then pauses for 45 seconds to allow Azure network propagation before proceeding with state refreshes, completely eliminating `403 Forbidden` data-plane errors.

---

## 📂 Repository Structure

```text
├── .github/
│   └── workflows/                # CI/CD Pipeline YAMLs (Plan, Apply, Destroy)
├── environment/
│   └── LearningGallery/
│       └── Infra-IaC-Code/
│           ├── uat/              # UAT Environment configuration and TFVars
│           │   └── Terraform-Scripts/ # Execution wrappers
│           └── prod/             # PROD Environment configuration and TFVars
├── modules/                      # Reusable Terraform Modules
│   ├── compute/                  # Virtual Machines, Disks, NICs
│   ├── network/                  # VNet, Bastion (Developer SKU), Private DNS
│   ├── security/                 # Key Vault, NSGs
│   └── storage/                  # Storage Accounts, Containers
└── README.md

```

---

## 🔐 Prerequisites & Setup

To deploy this platform, the following secrets must be securely stored in your GitHub Repository under **Settings > Secrets and variables > Actions**:

| Secret Name | Description |
| --- | --- |
| `AZURE_CLIENT_ID` | The Client ID of the Azure Service Principal used by GitHub Actions. |
| `AZURE_TENANT_ID` | Your Azure Active Directory Tenant ID. |
| `AZURE_SUBSCRIPTION_ID` | The target Azure Subscription ID. |
| `WINDOWS_ADMIN_PASSWORD` | Secure password injected as a variable for Windows VMs. |

**RBAC Requirements:** The executing Service Principal requires `Contributor` access at the subscription or resource group level to deploy infrastructure, and `Storage Blob Data Contributor` to manage blob containers within the strict firewalls.

---

## 🛠️ Deployment Workflow

1. **Develop:** Branch from `main` and update your `.tf` files or `terraform.auto.tfvars`.
2. **Commit & Push:** Merge your changes back to `main`.
3. **Automated Plan:** The GitHub Actions `Plan` workflow will automatically trigger, format the code, and output a detailed infrastructure diff.
4. **Review & Approve:** If the plan succeeds, the `Apply` workflow triggers and enters a "Waiting" state. Reviewers will receive an email prompt. Click **Approve** in the GitHub UI.
5. **Automated Provisioning:** The runner automatically negotiates the firewall bypass, waits for network propagation, and applies the zero-trust infrastructure.