# Azure Cloud Lab

Hands-on Azure infrastructure lab documenting my build-out from a 
VMware/AD engineering background into cloud infrastructure.

## Tools
- Azure Portal / Azure CLI
- Terraform (Phase 3)
- GitHub for config management

## Phase 1 — Networking & Virtual Machines ✅
Completed: September 1, 2026

- Created Resource Group: rg-lab-eastus (East US)
- Deployed Virtual Network: vnet-lab-eastus (10.10.0.0/16)
  - Subnet: snet-servers (10.10.1.0/24)
  - Subnet: snet-mgmt (10.10.2.0/24)
- Deployed Windows Server 2025 VM: vm-lab-dc01
- Deployed Ubuntu 24.04 LTS VM: vm-lab-lx01
- Verified RDP access (Windows) and SSH key auth (Linux) from local machine

## Phase 2 — Entra ID & RBAC
In progress

## Phase 3 — Terraform Automation
Planned#
