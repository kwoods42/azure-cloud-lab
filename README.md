# Azure Cloud Lab

Hands-on Azure infrastructure lab documenting my build-out from a
VMware/AD engineering background into cloud infrastructure.

## Tools
- Azure Portal / Azure CLI
- Terraform (Phase 3+)
- GitHub for config management

---

## Phase 1 — Networking & Virtual Machines ✅
**Completed: September 1, 2026**

- Created Resource Group: `rg-lab-eastus` (East US)
- Deployed Virtual Network: `vnet-lab-eastus` (10.10.0.0/16)
  - Subnet: `snet-servers` (10.10.1.0/24)
  - Subnet: `snet-mgmt` (10.10.2.0/24)
- Deployed Windows Server 2025 VM: `vm-lab-dc01`
- Deployed Ubuntu 24.04 LTS VM: `vm-lab-lx01`
- Verified RDP access (Windows) and SSH key auth (Linux) from local machine

---

## Phase 2 — Entra ID & RBAC ✅
**Completed: September 2026**

- Created Entra ID users: `lab-admin`, `lab-reader`, `lab-operator`
- Created security groups: `grp-lab-admins`, `grp-lab-readers`
- Assigned RBAC roles: Contributor to admins group, Reader to readers group
- Verified read-only access by logging in as `lab-reader`
- Created Service Principal `sp-terraform-lab` for Terraform authentication

---

## Phase 3 — Terraform Automation ✅
**Completed: September 7, 2026**

### 3.1 — Provider Configuration
- Configured `azurerm` provider (~> 3.0) with Service Principal credentials
- Stored credentials in `terraform.tfvars` (excluded from Git via `.gitignore`)

### 3.2 — First Resource Group
- Provisioned `rg-lab-terraform` via Terraform
- Verified resource appeared in Azure Portal in real time
- Committed initial config to GitHub

### 3.3 — Full VNet + VM Stack ✅
Reproduced the entire Phase 1 environment in Terraform code:

**Resources provisioned:**
- Resource Group: `rg-lab-terraform` (East US)
- Virtual Network: `vnet-lab-terraform` (10.20.0.0/16)
  - Subnet: `snet-servers` (10.20.1.0/24)
- Network Security Group: `nsg-lab-servers`
  - Inbound rules: RDP (3389) and SSH (22) restricted to home IP only
- Windows Server 2022 VM: `vm-lab-dc01-tf` (Standard_D2s_v7)
- Ubuntu 22.04 LTS VM: `vm-lab-lx01-tf` (Standard_D2s_v7)
- Public IPs and NICs for both VMs
- NSG associations on both NICs

**Verified:**
- SSH into Linux VM from Ouroboros6 confirmed
- RDP into Windows VM confirmed

---

## Troubleshooting Log — Phase 3.3

This section documents real issues encountered and how they were resolved.
These are the kinds of problems that come up in production environments.

### Issue 1 — Free Tier Public IP Limit
**Error:** `PublicIPCountLimitReached — Cannot create more than 3 public IP
addresses for this subscription in this region.`

**Cause:** Phase 1 VMs were still allocated and holding public IPs, consuming
the free tier limit of 3.

**Fix:** Detached public IPs from Phase 1 NICs using `az network nic
ip-config update --remove publicIpAddress`, then deleted the orphaned IPs.
Phase 1 VMs were subsequently deleted entirely since Phase 3 Terraform
reproduced the environment in code.

### Issue 2 — vCPU Quota Exhausted
**Error:** `OperationNotAllowed — exceeds approved Total Regional Cores quota.
Current Limit: 4, Current Usage: 4.`

**Cause:** Phase 1 VMs were using non-standard D-series sizes
(`Standard_D2alds_v7`) that consumed all 4 available vCPUs even when
deallocated, due to free tier quota behavior.

**Fix:** Deleted Phase 1 VMs entirely to free quota. Upgraded subscription
from Free Trial to Pay-As-You-Go to remove capacity restrictions.

### Issue 3 — SKU Capacity Restrictions
**Error:** `SkuNotAvailable — Standard_B2s / Standard_B1s / Standard_DS1_v2
not available in eastus / eastus2 / westus2.`

**Cause:** B-series and older D-series VM sizes were at capacity across
multiple regions on the free tier. Affected East US, East US 2, and West US 2
simultaneously.

**Fix:** Queried available SKUs with `az vm list-skus` to find unrestricted
sizes. Switched to `Standard_D2s_v7` which showed no capacity restrictions
in East US.

### Issue 4 — VM Image / Hypervisor Generation Mismatch
**Error:** `BadRequest — 'Standard_D2s_v7' cannot boot Hypervisor Generation
'1'. Image must match VM size generation.`

**Cause:** Windows Server 2022 standard image is Gen 1; `Standard_D2s_v7`
is Gen 2 only.

**Fix:** Switched Windows image SKU from `2022-datacenter` to
`2022-datacenter-g2` (the Gen 2 variant).

### Issue 5 — Terraform State Drift
**Error:** `A resource with the ID ... already exists - needs to be imported
into State.`

**Cause:** Multiple partial apply/destroy cycles caused Azure resources to
exist without corresponding Terraform state entries. This happened after
region switches mid-apply triggered race conditions.

**Fix:** Used `terraform import` to reconcile orphaned resources back into
state. For resources that couldn't be imported, deleted them via Azure CLI
(`az group delete`) and cleared state files manually before a clean apply.


---

## Key Lessons Learned

- **Always `terraform destroy` before changing regions** — partial builds
  across region changes cause state drift that's painful to unwind.
- **Free tier subscriptions have hidden capacity limits** that persist even
  when VMs are deallocated. Pay-as-you-go removes these restrictions.
- **Check SKU availability before applying** using `az vm list-skus` — saves
  multiple failed apply cycles.
- **VM image generation must match VM size generation** — D/v5+ sizes are
  Gen 2 only; use `-g2` image SKUs accordingly.
- **`terraform import`** is the right tool when state drifts — don't delete
  and recreate if the resource already exists in Azure.
- **`prevent_deletion_if_contains_resources = false`** in the provider block
  is necessary for clean resource group destroys when child resources are
  in an inconsistent state.

## Phase 3.4 — Remote State Backend ✅
**Completed: September 7, 2026**

Migrated Terraform state from local file to Azure Storage Account backend —
the standard pattern for team environments where multiple engineers share
infrastructure state.

**Resources created:**
- Storage Account: `stlabterraformstate` (Standard LRS, East US)
- Blob Container: `tfstate`
- State file: `lab.terraform.tfstate`

**Backend config added to `main.tf`:**
```hcl
backend "azurerm" {
  resource_group_name  = "rg-lab-terraform"
  storage_account_name = "stlabterraformstate"
  container_name       = "tfstate"
  key                  = "lab.terraform.tfstate"
}
```

**Migration:** Ran `terraform init` after adding the backend block —
Terraform detected the new backend and prompted to migrate existing local
state to Azure Storage. Confirmed with `az storage blob list` that
`lab.terraform.tfstate` landed in the container.

**Verified:** `terraform plan` returned no changes after migration,
confirming state integrity.

---

## Phase 4 — Documentation & Resume Integration (Complete)

								   ---

## Phase 5 — Full AD Portfolio Environment ✅
**Completed: September 7, 2026**

Full enterprise-style Windows environment deployed in Azure, domain-joined
and configured with AD structure, file services, IIS, and M365 integration.
Infrastructure documented as code in `phase5-terraform/`.

### 5.1 — Domain Controller ✅

- Deployed `vm-lab-dc02` (Windows Server 2022, Standard_D2s_v7, East US)
- Installed AD DS role and promoted to Domain Controller: domain `lab.local`
- Configured OU structure: Servers, Workstations, ServiceAccounts
- Created domain users: Declan Rice (`drice`), Mia Hamm (`mhamm`), Bobby Moore (`rmoore`)
- Created security groups: `IT-Admins` (drice), `IT-Users` (mhamm, rmoore)
- Created and linked GPOs: Password Policy, Drive Mapping, Desktop Lockdown
- Configured domain password policy: 12-char minimum, complexity enabled, 90-day max age
- Set static private IP (`10.20.1.6`) and pointed VNet DNS to DC

### 5.2 — File Server ✅

- Deployed `vm-lab-fs01`, domain-joined to `lab.local`
- Installed File and Storage Services role
- Created SMB shares: `\\fs01\Users`, `\\fs01\Dept`, `\\fs01\IT`
- Applied NTFS permissions using AD security groups (no individual user ACEs):
  - IT-Admins: FullControl on all shares
  - IT-Users: Modify on Users and Dept; no access to IT share

### 5.3 — IIS Application Servers ✅

- Deployed `vm-lab-app01` (Standard_D2s_v7) and `vm-lab-app02` (Standard_D2lds_v7)
- Both domain-joined to `lab.local`
- IIS installed on both; static test page deployed to confirm service
- Added NSG inbound rule AllowHTTP (port 80) scoped to VirtualNetwork
- Verified HTTP 200 response from DC (`vm-lab-dc02`) to both app servers across VNet

### 5.4 — Microsoft 365 Integration ✅

- Provisioned M365 Business Basic trial tenant: `TBGWorks.onmicrosoft.com`
- Created and licensed users mirroring AD accounts: drice, mhamm, rmoore
- Assigned Global Administrator role to drice (mirrors IT-Admins group)
- Created distribution group: `IT-Staff`
- Created shared mailbox: `itsupport@TBGWorks.onmicrosoft.com`
- Architectural decision: M365 over on-premises Exchange — lower cost, no
  infrastructure overhead, reflects how most organizations run mail today

### 5.5 — Terraform Documentation ✅

Phase 5 VMs were provisioned manually via the Azure Portal as part of the
learning process. The `phase5-terraform/` folder documents the full
infrastructure as code and can be used to rebuild the environment from
scratch. Existing VMs are intentionally not managed by this config to avoid
disrupting the live AD environment.

**Resources documented:**
- `vm-lab-dc02` — Domain Controller, static IP 10.20.1.6
- `vm-lab-fs01` — File Server
- `vm-lab-app01` / `vm-lab-app02` — IIS Application Servers
- All NICs, public IPs, and NSG associations
- Remote state stored in `stlabterraformstate` / `tfstate` container,
  key: `phase5.terraform.tfstate`

---

## Architecture Summary

| VM | Role | Private IP | Domain |
|---|---|---|---|
| vm-lab-dc02 | Domain Controller (lab.local) | 10.20.1.6 | lab.local |
| vm-lab-fs01 | File Server | 10.20.1.7 | lab.local |
| vm-lab-app01 | IIS App Server | 10.20.1.8 | lab.local |
| vm-lab-app02 | IIS App Server | 10.20.1.9 | lab.local |
| vm-lab-dc01-tf | Terraform baseline (Phase 3) | dynamic | standalone |
| vm-lab-lx01-tf | Terraform baseline (Phase 3) | dynamic | standalone |