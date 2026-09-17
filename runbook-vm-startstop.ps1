<#
.SYNOPSIS
    Start or stop lab VMs by tag or name.

.DESCRIPTION
    Authenticates using the Automation Account managed identity,
    then starts or stops all VMs in rg-lab-terraform based on the
    Action parameter.

.PARAMETER Action
    Start or Stop

.PARAMETER ResourceGroup
    Target resource group (default: rg-lab-terraform)
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start","Stop")]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-lab-terraform"
)

# Authenticate using managed identity
Connect-AzAccount -Identity

$VMs = Get-AzVM -ResourceGroupName $ResourceGroup

foreach ($VM in $VMs) {
    if ($Action -eq "Start") {
        Write-Output "Starting $($VM.Name)..."
        Start-AzVM -ResourceGroupName $ResourceGroup -Name $VM.Name -NoWait
    } elseif ($Action -eq "Stop") {
        Write-Output "Stopping $($VM.Name)..."
        Stop-AzVM -ResourceGroupName $ResourceGroup -Name $VM.Name -Force -NoWait
    }
}

Write-Output "Action '$Action' completed for all VMs in $ResourceGroup"
