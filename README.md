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

**Error:** `PublicIPCountLimitReached — Cannot create more than 3 public IP addresses for this subscription in this region.`

**Cause:** Phase 1 VMs were still allocated and holding public IPs, consuming
the free tier limit of 3.

**Fix:** Detached public IPs from Phase 1 NICs using `az network nic ip-config update --remove publicIpAddress`, then deleted the orphaned IPs.
Phase 1 VMs were subsequently deleted entirely since Phase 3 Terraform
reproduced the environment in code.

### Issue 2 — vCPU Quota Exhausted

**Error:** `OperationNotAllowed — exceeds approved Total Regional Cores quota. Current Limit: 4, Current Usage: 4.`

**Cause:** Phase 1 VMs were using non-standard D-series sizes
(`Standard_D2alds_v7`) that consumed all 4 available vCPUs even when
deallocated, due to free tier quota behavior.

**Fix:** Deleted Phase 1 VMs entirely to free quota. Upgraded subscription
from Free Trial to Pay-As-You-Go to remove capacity restrictions.

### Issue 3 — SKU Capacity Restrictions

**Error:** `SkuNotAvailable — Standard_B2s / Standard_B1s / Standard_DS1_v2 not available in eastus / eastus2 / westus2.`

**Cause:** B-series and older D-series VM sizes were at capacity across
multiple regions on the free tier. Affected East US, East US 2, and West US 2
simultaneously.

**Fix:** Queried available SKUs with `az vm list-skus` to find unrestricted
sizes. Switched to `Standard_D2s_v7` which showed no capacity restrictions
in East US.

### Issue 4 — VM Image / Hypervisor Generation Mismatch

**Error:** `BadRequest — 'Standard_D2s_v7' cannot boot Hypervisor Generation '1'. Image must match VM size generation.`

**Cause:** Windows Server 2022 standard image is Gen 1; `Standard_D2s_v7`
is Gen 2 only.

**Fix:** Switched Windows image SKU from `2022-datacenter` to
`2022-datacenter-g2` (the Gen 2 variant).

### Issue 5 — Terraform State Drift

**Error:** `A resource with the ID ... already exists - needs to be imported into State.`

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

---

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

## Phase 4 — Documentation & Resume Integration ✅

---

## Phase 5 — Full AD Portfolio Environment ✅
**Completed: September 7, 2026**

Full Windows environment deployed in Azure, domain-joined and configured
with AD structure, file services, IIS, and M365 integration. Infrastructure
documented as code in `phase5-terraform/`.

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

Phase 5 VMs were provisioned manually via the Azure Portal. The
`phase5-terraform/` folder documents the full infrastructure as code and
can be used to rebuild the environment from scratch. Existing VMs are
intentionally not managed by this config to avoid disrupting the live AD
environment.

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
| vm-lab-app02 | Database Server (SQL Express) | 10.20.1.9 | lab.local |
| vm-lab-dc01-tf | Terraform baseline (Phase 3) | dynamic | standalone |
| vm-lab-lx01-tf | Terraform baseline (Phase 3) | dynamic | standalone |

---

## Phase 6 — Security Hardening ✅
**Completed: September 8, 2026**

Security hardening applied across the full stack — identity, network,
monitoring, and compliance.

### 6.1 — Azure Key Vault ✅

- Deployed `kv-lab-terraform` (Standard SKU, RBAC authorization enabled)
- Migrated Terraform secrets out of `terraform.tfvars` into Key Vault:
  - `sp-client-secret` — Service Principal credential
  - `admin-password` — VM local admin password
- Terraform provider now reads `admin-password` via `data.azurerm_key_vault_secret`
- `client_secret` handled via `ARM_CLIENT_SECRET` environment variable
  sourced from Key Vault at session start (`source lab-env.sh`)
- `client_secret` and `admin_password` removed from `variables.tf` and `terraform.tfvars`
- Granted Service Principal (`sp-terraform-lab`) Key Vault Secrets User role

### 6.2 — Azure Bastion ✅

- Deployed `bastion-lab` (upgraded to Standard SKU in Phase 8.1) in dedicated `AzureBastionSubnet` (10.20.2.0/26)
- All VM access now routed through Bastion over HTTPS via Azure Portal
- Removed public IPs from `vm-lab-dc01-tf` and `vm-lab-lx01-tf`
- Removed RDP (3389) and SSH (22) inbound NSG rules — no direct internet exposure
- Terraform state updated: public IP resources removed, Bastion resources imported

### 6.3 — Defender for Cloud + Azure Monitor ✅

- Enabled Microsoft Defender for Servers P2 (30-day trial, agentless VM scanning active)
- Deployed Log Analytics workspace: `law-lab-eastus` (30-day retention, East US)
- Connected Defender for Cloud to `law-lab-eastus` as the default workspace
- Configured email security alerts via Defender for Cloud portal
- Created Azure Monitor action group: `ag-lab-alerts` (email: lab administrator)
- Created VM CPU alert rule on `vm-lab-dc01-tf` — triggers when CPU < 1%
  (detects unplanned deallocation)

### 6.4 — Azure Policy ✅

Three subscription-scoped policies assigned to enforce governance standards:

| Policy | Scope | Effect |
|---|---|---|
| Require `environment` tag | Subscription | Deny untagged resources |
| Allowed locations | Subscription | East US + global only |
| Allowed VM SKUs | Subscription | B-series and D-series only |

### 6.5 — Conditional Access & MFA ✅

- Activated Microsoft Entra ID P2 trial on `TBGWorks.onmicrosoft.com`
- Security Defaults confirmed disabled (prerequisite for Conditional Access)
- Created Conditional Access policy: `Require MFA for All Users`
  - Scope: All users, All cloud apps
  - Excluded: KevinWoods@TBGWorks.onmicrosoft.com (break-glass admin account)
  - Mode: Report-only (production best practice before enforcement)

**Note:** Conditional Access with MFA is the enterprise-preferred approach
over Security Defaults — requires Entra ID P1/P2 licensing. Report-only
mode logs what would have been enforced without blocking access, which is
the correct rollout pattern in any production environment.

### 6.6 — HTTPS on IIS ✅

- Generated self-signed certificates on `vm-lab-app01` and `vm-lab-app02`
  via `New-SelfSignedCertificate` (2-year validity, bound to `lab.local` FQDN)
- Configured IIS HTTPS binding on port 443 on both app servers
- Opened Windows Firewall for HTTPS (port 443) on both VMs
- Added `AllowHTTPS` NSG inbound rule (port 443, source: VirtualNetwork)
- Verified with `curl.exe -k https://localhost` — HTTP 200 confirmed on both servers
- Terraform updated and verified clean (`No changes`)

### 6.7 — AD Hardening ✅

**Account Lockout Policy** applied via `Set-ADDefaultDomainPasswordPolicy`:
- Lockout threshold: 5 failed attempts
- Lockout duration: 30 minutes
- Observation window: 30 minutes

**Tiered Admin Model** implemented:
- Created dedicated admin account `drice-adm` (Declan Rice Admin)
- `drice-adm` added to `IT-Admins` security group
- `drice` (daily-use account) removed from `IT-Admins`
- Separation of duties: standard account for daily work, admin account
  for elevated tasks only — mirrors enterprise privilege tiering best practice

### 6.8 — NSG Tightening ✅

- Added explicit `DenyAllInbound` rule at priority 4096 (lowest precedence)
- NSG now follows whitelist model: only permitted traffic is explicitly allowed,
  everything else is denied by policy rather than by default

**Final NSG inbound ruleset:**

| Rule | Priority | Protocol | Port | Source | Action |
|---|---|---|---|---|---|
| AllowHTTP | 1003 | TCP | 80 | VirtualNetwork | Allow |
| AllowHTTPS | 1004 | TCP | 443 | VirtualNetwork | Allow |
| DenyAllInbound | 4096 | Any | Any | Any | Deny |

- Terraform updated and verified clean (`No changes`)

---

## Phase 7 — Backup & Disaster Recovery ✅
**Completed: September 9, 2026**

Deployed VM-level backup protection across all lab VMs using Azure Backup
and a centralized Recovery Services Vault.

### 7.1 — Recovery Services Vault ✅

- Deployed `rsv-lab-eastus` (Standard SKU, East US)
- Configured storage redundancy as GeoRedundant — backup data is replicated
  to a secondary region automatically
- Soft delete is AlwaysON — deleted backups are retained 14 days and cannot
  be disabled
- Azure Monitor alerts enabled by default for job failures and failover issues
- Tagged `environment=lab` — required by the Azure Policy enforced in Phase 6.4

**Note:** Initial deployment was blocked by my own tag policy
(`require-environment-tag`). Resolved it by adding `--tags environment=lab`
to the vault creation command — a real-world example of governance controls
enforcing standards across all resource types including DR infrastructure.

### 7.2 — Backup Policy ✅

- Used `DefaultPolicy` (daily backups, 30-day retention, UTC 00:30)
- Custom policy creation was blocked by a known Azure CLI bug — DefaultPolicy
  meets all lab requirements and is the standard starting point in production

### 7.3 — VM Backup Enrollment ✅

Enrolled all six lab VMs in Azure Backup under DefaultPolicy:

| VM | Role | Backup Status |
|---|---|---|
| vm-lab-dc01-tf | Terraform baseline (Windows) | Enrolled ✅ |
| vm-lab-lx01-tf | Terraform baseline (Linux) | Enrolled ✅ |
| vm-lab-dc02 | Domain Controller | Enrolled ✅ |
| vm-lab-fs01 | File Server | Enrolled ✅ |
| vm-lab-app01 | IIS App Server | Enrolled ✅ |
| vm-lab-app02 | Database Server | Enrolled ✅ |

### 7.4 — Backup Verification ✅

- Triggered an on-demand backup of `vm-lab-dc02` to verify the end-to-end
  backup pipeline
- Initial attempt failed: Azure Backup auto-created resource group
  `AzureBackupRG_eastus_1` was blocked by my tag policy — resolved by
  creating a policy exemption (Waiver category) scoped to that resource group
- Second attempt succeeded: snapshot taken, transferred to vault, validated
- Confirmed a recovery point exists in `rsv-lab-eastus`

---

## Phase 8 — Database Tier, Monitoring & Automation
**Started: September 2026**

### 8.1 — Database Server (vm-lab-app02 → vm-lab-db01) ✅
**Completed: September 14, 2026**

Repurposed `vm-lab-app02` as a dedicated database server running SQL Server
Express 2022, adding a database tier to the environment and completing a
three-tier architecture: IIS (web) → app → database.

**Infrastructure changes:**
- Deployed NAT Gateway `natgw-lab` with public IP `pip-lab-natgateway` —
  provides outbound internet access for VMs without exposing them to inbound
  traffic. Required for SQL Server Express download and future Windows Updates.
- Attached NAT Gateway to `snet-servers` subnet
- Configured DNS forwarders on `vm-lab-dc02` (8.8.8.8, 8.8.4.4) for external
  name resolution
- Added `AllowVnetInbound` NSG rule (priority 1000) — allows all intra-VNet
  traffic
- Added `AllowSQL` NSG rule (priority 1005, TCP 1433, source: VirtualNetwork)
- Upgraded Bastion to Standard SKU with native tunneling enabled
- Added `environment=lab` tags to NSG, Bastion, and pip-bastion resources
  to satisfy Azure Policy tag enforcement

**SQL Server Express 2022:**
- Installed via `az vm run-command` (Bastion interactive sessions unavailable
  from local machine — documented as known issue)
- Silent install using full installer `SQLEXPR_x64_ENU.exe` (279MB)
- Instance name: `SQLEXPRESS`
- Data directory: `C:\SQLData`
- Service account: `NT AUTHORITY\NETWORK SERVICE`
- Startup type: Automatic
- Verified: `LabDB` created and confirmed via `sys.databases`

**Troubleshooting log:**

### Issue 1 — VM-to-VM Communication Failure

**Cause:** The `DenyAllInbound` NSG rule added in Phase 6.8 was blocking all
inbound traffic including intra-subnet traffic. Only ports 80 and 443 were
explicitly allowed — ICMP, DNS (53), and all other inter-VM traffic was
being denied by the catch-all deny rule.

**Fix:** Added `AllowVnetInbound` at priority 1000 — permits all traffic
sourced from the VirtualNetwork service tag, restoring intra-subnet
communication while keeping the `DenyAllInbound` rule blocking external
traffic.

### Issue 2 — No Outbound Internet on VMs

**Cause:** Removing public IPs in Phase 6.2 also removed the default outbound
route. VMs had no path to the internet for downloads or external DNS
resolution.

**Fix:** Deployed NAT Gateway `natgw-lab` and attached it to `snet-servers`.
Configured DNS forwarders on dc02 to forward external queries to 8.8.8.8
and 8.8.4.4. Temporarily pointed vm-lab-app02 DNS directly to Google DNS
(8.8.8.8) to unblock the install — will restore to dc02 once DC forwarder
is verified stable.

### Issue 3 — SQL Server Sector Size Mismatch

**Error:** `Cannot use file 'master.mdf' because it was originally formatted
with sector size 4096 and is now on a volume with sector size 8192.`

**Cause:** Azure VM disk (Standard_D2lds_v7) uses 8192-byte physical sectors.
SQL Server 2022 installer created system database files expecting 4096-byte
sectors during the first install attempt which timed out.

**Fix:** Added registry key
`HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device`
with `ForcedPhysicalSectorSizeInBytes = * 4095` to force 4096-byte sector
reporting. Uninstalled SQL Server, deleted corrupted data files, and
reinstalled fresh with explicit data directory flags.

### Issue 4 — SQL Install Timeout

**Cause:** First install attempt used the SSEI bootstrapper (`SQL2022-SSEI-Expr.exe`)
which downloads the full installer at runtime. The combined download and
install exceeded the 90-minute `run-command` timeout.

**Fix:** Downloaded the full installer (`SQLEXPR_x64_ENU.exe`, 279MB) directly
in a separate run-command, then ran the silent install as a second step —
keeping each operation well within the timeout window.

**Updated NSG ruleset:**

| Rule | Priority | Protocol | Port | Source | Action |
|---|---|---|---|---|---|
| AllowVnetInbound | 1000 | Any | Any | VirtualNetwork | Allow |
| AllowHTTP | 1003 | TCP | 80 | VirtualNetwork | Allow |
| AllowHTTPS | 1004 | TCP | 443 | VirtualNetwork | Allow |
| AllowSQL | 1005 | TCP | 1433 | VirtualNetwork | Allow |
| DenyAllInbound | 4096 | Any | Any | Any | Deny |

### 8.2 — GitHub Actions CI/CD for Terraform ✅
**Completed: September 16, 2026**

Implemented a full CI/CD pipeline for Terraform using GitHub Actions, with a
matrix strategy running plan across both Terraform directories in parallel and
auto-apply scoped to the live infrastructure directory on merge to main.

**Pipeline design:**
- `terraform plan` runs in parallel across `phase3-terraform` and
  `phase5-terraform` on every push and pull request via a matrix strategy
- `terraform apply` runs only on `phase3-terraform` on merge to main —
  phase5 is brownfield documentation, not live state, so apply is intentionally
  excluded
- Apply is sequenced to run only after both plans succeed
- Plan artifacts (tfplan files) are uploaded and passed to the apply job —
  the same plan that was reviewed is what gets applied, never a fresh run
- `workflow_dispatch` is available as a manual trigger
- `fail-fast: false` on the matrix ensures a phase5 plan failure does not
  cancel the phase3 plan

**GitHub repository secrets configured:**
- `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`
  — feed the azurerm provider directly via environment variables
- `TF_VAR_subscription_id`, `TF_VAR_client_id`, `TF_VAR_tenant_id`,
  `TF_VAR_admin_password`, `TF_VAR_ssh_public_key` — supply Terraform input
  variables without committing a tfvars file to the repo

---

### Troubleshooting Log — Phase 8.2

#### Issue 1 — Workflow YAML Syntax Error

**Error:** `A sequence was not expected` on line 20.

**Cause:** The workflow file was saved with the heredoc shell wrapper (`cat >
... << 'EOF'`) included as content, making the first line of the file a bash
command rather than valid YAML.

**Fix:** Rewrote the file using a heredoc with a distinct delimiter (`ENDOFFILE`)
to avoid the shell wrapper being captured as file content.

---

#### Issue 2 — Terraform Plan Exit Code 3 Failing the Job

**Error:** `Terraform exited with code 3. Process completed with exit code 1.`

**Cause:** Three compounding factors:
1. `terraform plan -detailed-exitcode` returns exit code 2 when changes are
   detected — not an error, but GitHub Actions treated it as one.
2. `hashicorp/setup-terraform@v3` wraps the Terraform binary and intercepts
   exit codes before shell logic can handle them.
3. GitHub Actions `run` blocks execute with `set -e` by default, causing the
   shell to exit immediately on any non-zero return before `$?` could be
   captured.

**Fix:** Disabled the Terraform wrapper (`terraform_wrapper: false`) and
removed `-detailed-exitcode` entirely. Standard `terraform plan` returns 0
on success and 1 on error — no special handling needed.

---

#### Issue 3 — Format Check Failing the Pipeline

**Error:** `terraform fmt -check` exiting with code 3, failing both plan jobs.

**Cause:** `main.tf` in phase3-terraform had formatting inconsistencies —
misaligned equals signs and improper indentation that accumulated across
multiple manual edits throughout the lab.

**Fix:** Ran `terraform fmt` locally in both directories to auto-correct
formatting, then committed the corrected files. The `-check` flag in CI is
correct behavior — it enforces that all committed code is properly formatted.

---

#### Issue 4 — Undeclared Variable: client_secret (phase5)

**Error:** `Reference to undeclared input variable` — `var.client_secret` on
line 31 of phase5 `main.tf`.

**Cause:** The phase5 provider block still referenced `var.client_secret` from
before Key Vault took over secret management in Phase 6. The variable was
never declared because phase3 handles authentication via the `ARM_CLIENT_SECRET`
environment variable.

**Fix:** Removed the `client_secret` line from the phase5 provider block. The
azurerm provider picks up `ARM_CLIENT_SECRET` from the environment
automatically without needing it explicitly declared.

---

#### Issue 5 — Symlinked Files Not Resolving in CI

**Error:** `No configuration files` — Terraform plan failing in 0 seconds.

**Cause:** `phase5-terraform/terraform.tfvars` and `phase5-terraform/variables.tf`
were symlinks pointing to `../phase3-terraform/`. Git stores symlinks as
symlink objects, not file content. The GitHub Actions runner checked out the
symlinks correctly but the relative target path did not resolve in the runner
environment.

**Fix:** Removed the symlinks and replaced them with real file copies. `terraform.tfvars`
is gitignored and not committed — variables are supplied via `TF_VAR_*`
environment variables from GitHub Secrets instead.

---

#### Issue 6 — Undeclared Variable: admin_password

**Error:** `Reference to undeclared input variable` — `var.admin_password`
referenced in four Windows VM resources in phase5 `main.tf`.

**Cause:** `admin_password` was never declared in `variables.tf` because phase3
retrieves it from Key Vault via a data source rather than as an input variable.
Phase5 references it directly as `var.admin_password` but had no corresponding
declaration.

**Fix:** Added `variable "admin_password" {}` to both `variables.tf` files and
added `TF_VAR_admin_password` to GitHub Secrets, sourced from Key Vault.

---

#### Issue 7 — SSH Key Type Mismatch

**Error:** `the provided ssh-ed25519 SSH key is not supported. Only RSA SSH
keys are supported by Azure`

**Cause:** The local SSH key on Ouroboros6 is ed25519. Azure's azurerm provider
requires RSA keys for Linux VM `admin_ssh_key` blocks. The ed25519 public key
was stored in `TF_VAR_ssh_public_key` and passed to the runner.

**Fix:** Generated a dedicated RSA 4096-bit key pair for CI (`id_rsa_lab`).
Updated `TF_VAR_ssh_public_key` in GitHub Secrets with the RSA public key.
Added a `lifecycle { ignore_changes = [admin_ssh_key] }` block to `vm-lab-lx01-tf`
to prevent Terraform from forcing VM replacement when the key differs from
what was used at creation time.

---

#### Issue 8 — CI Apply Attempting to Destroy Brownfield VMs

**Error:** Phase5 apply attempting to destroy dc02, fs01, app01, app02 —
blocked by the `require-environment-tag` Azure Policy enforced in Phase 6,
and by deallocated VM power state conflicts.

**Cause:** Phase5 Terraform was set up as brownfield documentation using data
sources to reference Phase 3 infrastructure. It was never intended to manage
live VM lifecycle. When apply ran in CI, Terraform detected drift between
the documented state and actual Azure resource configuration and queued
destructive changes.

**Fix:** Removed the `terraform-apply-phase5` job from the workflow entirely.
Phase5 runs plan only — this validates the configuration is syntactically
correct and documents what would change, without risking unintended
destruction of the AD environment. This is the architecturally correct pattern:
plan everywhere, apply only where Terraform owns the resource lifecycle.

**Note:** This was also a real-world demonstration of Phase 6 governance
working as designed — the tag enforcement policy blocked unauthorized resource
modifications from an automated pipeline, exactly as it would in a production
environment.

---

#### Issue 9 — SP Missing Storage Blob Permissions for Remote State

**Error:** `Failed to get existing workspaces: retrieving container client:
retrieving key for Storage Account` — HTTP response nil, connection reset.

**Cause:** The Service Principal `sp-terraform-lab` had Contributor at the
subscription scope but lacked explicit permissions on the storage account
backing the Terraform remote state. GitHub Actions runners authenticate
differently than an interactive CLI session — the runner has no cached
credentials or managed identity fallback.

**Fix:** Assigned `Storage Blob Data Contributor` to `sp-terraform-lab` scoped
directly to `stlabterraformstate`. This is the minimum required permission for
Terraform to read and write state blobs.

---

### 8.3 — Azure Monitor KQL + Workbooks ✅
**Completed: September 16, 2026**

Deployed full observability stack connecting three lab VMs to the existing
Log Analytics workspace `law-lab-eastus` and built a custom Azure Monitor
Workbook surfacing infrastructure health data.

**Azure Monitor Agent deployment:**
- Installed AzureMonitorWindowsAgent extension on vm-lab-dc02, vm-lab-fs01,
  and vm-lab-app02
- Assigned system-managed identity to all three VMs — required for AMA
  authentication to the Data Collection Rule
- Created policy exemption for VM extension deployment (tag policy blocks
  extension resources by default)

**Data Collection Rule — `dcr-lab-windows`:**
- Collects Windows performance counters every 60 seconds:
  `% Processor Time`, `Available MBytes`, `% Free Space`
- Collects Windows Event log (System errors/warnings) and Security events
  (EventID 4624, 4625, 4648 — logon success, failure, explicit credentials)
- Associated with all three VMs and routing to `law-lab-eastus`

**KQL queries developed:**
- VM heartbeat status with online/offline classification
- CPU % over time per computer (5-minute bins)
- Available memory over time per computer (5-minute bins)
- System event count by computer and severity level

**Workbook — `wb-lab-infrastructure`:**
- Four panels: VM Heartbeat Status (grid), CPU % Over Time (line chart),
  Available Memory MB (line chart), System Events by Computer (grid)
- Saved to `rg-lab-terraform`, East US, tagged `environment=lab`
- ARM template exported and committed to repo as
  `workbook-lab-infrastructure.json` — workbook is fully reproducible
  from code

**Troubleshooting log:**

### Issue 1 — No Heartbeat Data After Agent Install
**Cause:** AMA requires a system-assigned managed identity to authenticate
to the Data Collection Rule. VMs had no managed identity assigned.
**Fix:** Assigned system-assigned managed identity to all three VMs via
`az vm identity assign`.

### Issue 2 — Tag Policy Blocking Agent Extension Install
**Cause:** The `require-environment-tag` policy enforced in Phase 6
blocked VM extension deployment. `az vm extension set` has no `--tags`
flag to satisfy the policy inline.
**Fix:** Created a policy exemption (Waiver) scoped to `rg-lab-terraform`
covering the tag policy assignment.

### Issue 3 — SKU Policy Blocking Identity Assignment on vm-lab-app02
**Cause:** Assigning a managed identity to vm-lab-app02 triggered the
`allowed-vm-skus` policy check and was blocked.
**Fix:** Created a targeted policy exemption scoped directly to
`vm-lab-app02` for the SKU policy assignment.

### Issue 4 — SecurityEvent Table Missing
**Cause:** The Security event log XPath queries in the DCR route to the
generic `Event` table rather than `SecurityEvent` — `SecurityEvent` requires
Microsoft Sentinel or Defender for Cloud to be enabled on the workspace.
**Fix:** Used the `Event` table for system event monitoring. Security event
collection (4624/4625/4648) is configured in the DCR and available for
future Sentinel integration.

---

### 8.4 — Azure Automation Runbooks ✅
**Completed: September 17, 2026**

Deployed an Azure Automation Account with PowerShell runbooks authenticated
via system-assigned managed identity, completing a full detect-and-remediate
compliance workflow.

**Automation Account:** `aa-lab-eastus` (East US, Basic SKU)
- System-assigned managed identity: `1e8e684f-ec88-4888-9971-97021b00cabe`
- Contributor role assigned at `rg-lab-terraform` scope

**Runbook 1 — `runbook-vm-startstop.ps1`:**
- Parameters: `Action` (Start or Stop), `ResourceGroup` (default: rg-lab-terraform)
- Authenticates via `Connect-AzAccount -Identity`
- Enumerates all VMs in the resource group and starts or stops them in parallel
- Verified: started all six VMs and stopped all six VMs successfully

**Runbook 2 — `runbook-tag-compliance.ps1`:**
- Parameters: `ResourceGroup`, `RequiredTag`, `RequiredValue` (all defaulted)
- Queries all resources and reports any missing the `environment=lab` tag
- Excludes VM extensions (`Microsoft.Compute/virtualMachines/extensions`)
  which are untaggable child resources
- First run identified 30+ non-compliant resources across the environment

**Tag remediation workflow:**
1. Compliance runbook identified drift — 30+ resources missing `environment=lab`
2. Phase3 Terraform resources fixed by adding `tags` blocks to `main.tf` and
   pushing through CI/CD pipeline
3. Key Vault, Log Analytics workspace, action group, and metric alert imported
   into Terraform state and tagged via `terraform apply`
4. Phase5 brownfield resources (VMs, NICs, disks, public IPs) tagged directly
   via `az tag update` — not managed by Terraform
5. Compliance runbook re-run confirmed: **All resources in rg-lab-terraform
   are compliant**

Both runbooks committed to repo as `.ps1` files and published in the
Automation Account.

**Troubleshooting log:**

### Issue 1 — Tag Policy Blocking Automation Account Identity Assignment
**Cause:** The `allowed-vm-skus` policy blocked assigning a managed identity
to `vm-lab-app02`.
**Fix:** Created a targeted policy exemption scoped to `vm-lab-app02`.

### Issue 2 — Key Vault Import Failing on Permission Model Change
**Cause:** Terraform attempted to change `enable_rbac_authorization` from
`true` to `null` during import, which requires `Microsoft.Authorization/roleAssignments/write`
— a permission the SP doesn't have.
**Fix:** Added `enable_rbac_authorization = true` to the Key Vault resource
block to match the existing Azure configuration and prevent Terraform from
attempting to modify it.

### Issue 3 — Disk Tag Names Truncated in Compliance Report
**Cause:** The runbook output truncated long disk names in the formatted table.
**Fix:** Retrieved full disk names via `az disk list` before tagging.

### Issue 4 — VM Extension Resources Not Taggable
**Cause:** VM extensions (`Microsoft.Compute/virtualMachines/extensions`) are
child resources that cannot be independently tagged via the Azure Resource
Manager tagging API.
**Fix:** Updated the compliance runbook to exclude VM extension resource types
from the compliance check. Parent VM tags already cover these resources from
a governance perspective.

---
## Phase 9 — Networking, DNS & Identity
**Started: September 2026**

### 9.1 — Azure DNS Private Zones ✅
**Completed: September 18, 2026**

Deployed Azure Private DNS zones to provide name resolution within the VNet
for both the AD environment and Key Vault private endpoint access.

**Private DNS Zone — `lab.local`:**
- Created and linked to `vnet-lab-terraform` (registration disabled)
- A records added for all four AD environment VMs:
  - `vm-lab-dc02` → 10.20.1.6
  - `vm-lab-fs01` → 10.20.1.7
  - `vm-lab-app01` → 10.20.1.8
  - `vm-lab-app02` → 10.20.1.9

**Private DNS Zone — `privatelink.vaultcore.azure.net`:**
- Created and linked to `vnet-lab-terraform`
- Private endpoint `pe-lab-keyvault` deployed on `snet-servers` (10.20.1.10)
- Key Vault now resolves privately within the VNet — no public internet path
  required from lab VMs
- DNS zone group attached to private endpoint for automatic record management

All resources imported into Terraform state and managed via `phase3-terraform`.
CI/CD pipeline applied cleanly with no changes after import.

### 9.2 — VNet Peering / Hub-Spoke Topology ✅
**Completed: September 18, 2026**

Redesigned the network topology from a flat single-VNet model to a hub-spoke
architecture, migrating Bastion to a dedicated hub VNet and peering it to the
existing spoke VNet.

**Hub VNet — `vnet-lab-hub` (10.30.0.0/16):**
- Created with dedicated `AzureBastionSubnet` (10.30.1.0/26)
- Houses shared network services — Bastion and future firewall/NVA resources
- Peered to spoke VNet with forwarded traffic enabled

**Spoke VNet — `vnet-lab-terraform` (10.20.0.0/16):**
- Existing workload VNet — all lab VMs remain here
- Peered to hub VNet bidirectionally
- No longer contains Bastion subnet

**Bastion migration:**
- Deployed `bastion-hub` (Standard SKU, tunneling enabled) in hub VNet
- Public IP: `pip-hub-bastion` (20.102.62.64)
- Decommissioned `bastion-lab` and `pip-lab-bastion` from spoke VNet
- Portal confirmed `bastion-hub` as active Bastion for all spoke VMs
- VM reachability verified via `az vm run-command` — dc02 responded to
  hostname query through hub Bastion routing

**VNet Peerings:**
- `peer-hub-to-spoke` — hub → spoke, virtual network access and forwarded traffic enabled
- `peer-spoke-to-hub` — spoke → hub, virtual network access and forwarded traffic enabled

All resources managed in Terraform. CI/CD pipeline ran clean after import.

**Known limitation:** Interactive Bastion RDP/SSH sessions from Ouroboros6
(Zorin OS Linux) remain non-functional due to an unresolved WebSocket/RDP
proxy compatibility issue — consistent with the behavior documented in Phase 6.
All VM administration performed via `az vm run-command` as a workaround.

### 9.3 — Azure Update Manager ✅
**Completed: September 18, 2026**

Deployed Azure Update Manager across the lab VM fleet, providing centralized
patch visibility and a scheduled maintenance window for automated patching.

**Maintenance Configuration — `mc-lab-windows-updates`:**
- Scope: InGuestPatch (OS-level patching)
- Schedule: Monthly, third Tuesday, 8:00 PM Eastern, 2-hour window
- Windows: Critical, Security, and Update Rollup classifications
- Linux: Critical and Security classifications
- Reboot setting: IfRequired
- Patch mode: AutomaticByPlatform with bypassPlatformSafetyChecksOnUserSchedule

**VMs enrolled (dc02, fs01, app02):**
- Patch mode set to `AutomaticByPlatform`
- Assessment mode set to `AutomaticByPlatform`
- Maintenance configuration assigned via `az maintenance assignment create`

**Assessment results:**
- vm-lab-dc02: 3 pending updates (2 security, 1 other)
- vm-lab-app02: 3 pending updates (2 security, 1 other)
- vm-lab-fs01: assessment pending
- Remaining VMs (dc01-tf, lx01-tf, app01): periodic assessment not enabled —
  these are baseline/brownfield VMs outside the maintenance scope

**Update Manager dashboard confirmed:**
- 6 machines visible
- 3 on Customer Managed Schedule
- Pending Windows updates surfaced with classification breakdown
- No pending Linux updates

**Troubleshooting log:**

### Issue 1 — Maintenance CLI Extension Parameter Syntax Broken
**Cause:** The `az maintenance configuration create` CLI extension is in preview
and broke parameter parsing for `--install-patches-windows-parameters`.
**Fix:** Used `az rest` with the ARM API directly to create the maintenance
configuration.

### Issue 2 — bypassPlatformSafetyChecksOnUserSchedule Required
**Cause:** Maintenance assignment failed with `UnsupportedResourceOperation`
because VMs need `bypassPlatformSafetyChecksOnUserSchedule: true` set before
they can be assigned to a customer-managed schedule.
**Fix:** Updated all three VMs via `az rest` PATCH to add the bypass flag to
`automaticByPlatformSettings`.
### 9.4 — Privileged Identity Management (PIM) ⚠️ Blocked
**Attempted: September 18, 2026**

Attempted to configure Azure PIM for just-in-time role activation on
`rg-lab-terraform`, targeting the `Contributor` role for `lab-admin`.

**Intended configuration:**
- Make `Contributor` on `rg-lab-terraform` an eligible assignment rather
  than permanent for lab admin users
- Require MFA and justification on activation
- Set maximum activation duration to 4 hours
- Configure email notification to lab administrator on activation
- Set up quarterly access review for Contributor assignments
- Enable PIM alerts for permanent assignments and unused eligible roles

**Blocker — Tenant/Subscription mismatch:**

PIM for Azure resources requires Entra ID P2 licenses in the same tenant
as the Azure subscription. The lab Azure subscription is linked to the
default directory (personal Microsoft account
tenant), which does not support Entra ID P2 license purchases. The M365
Business Basic trial and Entra ID P2 trial were activated under
`TBGWorks.onmicrosoft.com` (a work/school tenant), but the Azure
subscription cannot be managed from that tenant without a subscription
transfer.

**Resolution path:** Either transfer the subscription to TBGWorks tenant
or create a new Azure subscription under TBGWorks with P2 already licensed.
This is a real-world architecture consideration — in enterprise environments,
Azure subscriptions and Entra ID tenants are always aligned to avoid exactly
this kind of licensing and governance gap.

**What was verified:**
- PIM blade is accessible in the Portal
- Entra ID P2 trial successfully activated in TBGWorks tenant (1/25 assigned)
- PIM role structure and Azure resources onboarding flow reviewed
- Tenant/subscription alignment documented as a prerequisite for PIM deployment
---

## Phase 10 — Disaster Recovery Exercise
**Planned**

Structured DR exercise across three failure scenarios, validating the backup
and recovery infrastructure built in Phase 7 and testing operational runbooks
under simulated incident conditions.

### 10.0 — Pre-Exercise Verification ⬜ Planned
Verify all recovery points are valid and current before beginning DR scenarios.
Confirm Recovery Services Vault health, backup job status, and restore point
availability for all enrolled VMs.

### 10.1 — Scenario: Accidental Resource Deletion ✅ Complete

**10.1a — NSG Destruction Attempt:** Simulated junior admin error targeting nsg-lab-servers.
Azure dependency protection prevented full destruction — the environment self-protected.
Confirmed guardrails working as designed.

**10.1b — Terraform State Destruction:** State blobs deleted from stlabterraformstate,
rendering all resources invisible to Terraform. Full state reconstruction performed via
29 terraform import blocks. Recovery completed in 22 minutes with zero infrastructure
changes — 29 imported, 0 added, 0 changed, 0 destroyed.

### 10.2 — Scenario: Domain Controller Corruption ⬜ Planned
OS-level corruption on vm-lab-dc02 renders the domain unavailable, blocking
authentication for all domain-joined VMs. Recovery via Recovery Services Vault
restore and authoritative AD restore. Tests Azure Backup restore workflow.

### 10.3 — Scenario: Ransomware Attack on File Server ⬜ Planned
Threat actor compromises vm-lab-fs01, encrypts file share contents, and
deletes shadow copies. Recovery involves VM isolation, clean restore from
backup, AD integrity validation, and incident timeline documentation. Most
complex scenario — tests the full IR and recovery workflow.
