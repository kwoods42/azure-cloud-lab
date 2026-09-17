<#
.SYNOPSIS
    Report on resources missing the environment tag.

.DESCRIPTION
    Authenticates using managed identity, queries all resources in
    rg-lab-terraform, and reports any missing the environment=lab tag.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-lab-terraform",

    [Parameter(Mandatory=$false)]
    [string]$RequiredTag = "environment",

    [Parameter(Mandatory=$false)]
    [string]$RequiredValue = "lab"
)

Connect-AzAccount -Identity

$Resources = Get-AzResource -ResourceGroupName $ResourceGroup
$NonCompliant = @()

$ExcludedTypes = @(
    "Microsoft.Compute/virtualMachines/extensions"
)

foreach ($Resource in $Resources) {
    if ($ExcludedTypes -contains $Resource.ResourceType) { continue }
    if (-not $Resource.Tags -or -not $Resource.Tags.ContainsKey($RequiredTag)) {
        $NonCompliant += [PSCustomObject]@{
            Name          = $Resource.Name
            Type          = $Resource.ResourceType
            TagPresent    = "No"
            TagValue      = "Missing"
        }
    } elseif ($Resource.Tags[$RequiredTag] -ne $RequiredValue) {
        $NonCompliant += [PSCustomObject]@{
            Name          = $Resource.Name
            Type          = $Resource.ResourceType
            TagPresent    = "Yes"
            TagValue      = $Resource.Tags[$RequiredTag]
        }
    }
}

if ($NonCompliant.Count -eq 0) {
    Write-Output "All resources in $ResourceGroup are compliant."
} else {
    Write-Output "Non-compliant resources found:"
    $NonCompliant | Format-Table -AutoSize
}
