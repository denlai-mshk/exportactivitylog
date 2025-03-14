# Ensure the required modules are imported
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Install-Module -Name Az.Accounts -AllowClobber -Force
}
Import-Module Az.Accounts

if (-not (Get-Module -ListAvailable -Name Az.Sql)) {
    Install-Module -Name Az.Sql -AllowClobber -Force
}
Import-Module Az.Sql

if (-not (Get-Module -ListAvailable -Name Az.Compute)) {
    Install-Module -Name Az.Compute -AllowClobber -Force
}
Import-Module Az.Compute

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module -Name powershell-yaml -AllowClobber -Force
}
Import-Module powershell-yaml

# Ensure proper login
<# 
$TenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx"
try {
    Connect-AzAccount -TenantId $TenantId -ErrorAction Stop
} catch {
    Write-Output "Failed to authenticate. Please ensure you are logged in with the correct account."
    exit
}
#>

# Import the list of subscriptions from sublist.txt
$subscriptions = Import-Csv -Path "sublist.txt" -Delimiter ',' -Header "SubscriptionName", "SubscriptionId", "TenantId" | Select-Object -Skip 1

# Import configuration values from config.yaml
$config = (Get-Content -Path "config.yaml" | Out-String | ConvertFrom-Yaml)
$days = [int]$config.Configuration.Days
$maxRecord = [int]$config.Configuration.MaxRecord
$operationNames = $config.Configuration.OperationNames

# Generate the output file name based on the current date and time
$outputFileName = "output-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

# Initialize the output file
if (Test-Path $outputFileName) {
    Remove-Item $outputFileName
}
New-Item -Path $outputFileName -ItemType File

# Add header row to the output file
$header = "OpName, ResourceGroup, SubscriptionId, ResourceId, ResourceType, Timestamp, Action"
Add-Content -Path $outputFileName -Value $header

# Function to log discovery details
function LogDiscovery {
    param (
        [string]$OpName,
        [string]$ResourceGroup,
        [string]$SubscriptionId,
        [string]$ResourceId,
        [string]$ResourceType,
        [string]$Timestamp,
        [string]$Action
    )
    $logEntry = "$OpName, $ResourceGroup, $SubscriptionId, $ResourceId, $ResourceType, $Timestamp, $Action"
    Add-Content -Path $outputFileName -Value $logEntry
}

Write-Output "$(Get-Date -Format HH:mm:ss) Job started"
# Loop through each subscription
$totalSubscriptions = $subscriptions.Count
$subscriptionIndex = 0
foreach ($subscription in $subscriptions) {
    $subscriptionIndex++
    Write-Output "$(Get-Date -Format HH:mm:ss) Processing subscription: $($subscription.SubscriptionName)"
    $SubscriptionId = $subscription.SubscriptionId
    $SubscriptionName = $subscription.SubscriptionName
    $TenantId = $subscription.TenantId
    # Check if SubscriptionId or SubscriptionName is empty
    if ([string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($SubscriptionName)) {
        Write-Output "Error: Missing SubscriptionId or SubscriptionName"
        break
    }

    try {
        # Set the current subscription context
        Set-AzContext -TenantId $TenantId -SubscriptionName $SubscriptionName -ErrorAction Stop

        # Get all resource groups in the subscription
        $resourceGroups = Get-AzResourceGroup
        $totalResourceGroups = $resourceGroups.Count
        $resourceGroupIndex = 0
        foreach ($resourceGroup in $resourceGroups) {
            $ResourceGroupName = $resourceGroup.ResourceGroupName
            $resourceGroupIndex++

            # Get activity logs for resource deletions
            $resources = Get-AzActivityLog -ResourceGroupName $ResourceGroupName -StartTime (Get-Date).AddDays(-$days) -EndTime (Get-Date) -MaxRecord $maxRecord -WarningAction SilentlyContinue

            Write-Output "executing $resourceGroupIndex/$totalResourceGroups resource groups from $subscriptionIndex/$totalSubscriptions subscriptions"

            if ($operationNames.Count -eq 0) {
                # If operationNames is empty, process all resources
                $filteredResources = $resources | Where-Object { $_.Status -eq "Succeeded" }
            } else {
                # Filter resources based on operation names and status
                $filteredResources = $resources | Where-Object {
                    $_.Status -eq "Succeeded" -and $operationNames -contains $_.OperationName
                }
            }

            foreach ($resource in $filteredResources) {
                # Remove sensitive context
                $resource.Authorization = $null
                $resource.Claims = $null
                $resource.HttpRequest = $null

                try {
                    $jsonstring = $resource | ConvertTo-Json -Compress
                    # Remove special characters
                    $jsonstring = $jsonstring -replace '\r', '' -replace '\n', ''
                } catch {
                    Write-Output "Failed to convert resource to JSON. Error: $_"
                    $jsonstring = $resource | Out-String
                    # Remove special characters
                    $jsonstring = $jsonstring -replace '\r', '' -replace '\n', ''
                }
                
                $OpName = $resource.OperationName
                LogDiscovery -OpName $OpName -ResourceGroup $ResourceGroupName -SubscriptionId $SubscriptionId -ResourceId $resource.ResourceId -ResourceType $resource.ResourceType -Timestamp $resource.EventTimestamp -Action $jsonstring
            }

        }
    } catch {
        Write-Output "Failed to set context for subscription $SubscriptionId. Error: $_"
    }
}

Write-Output "$(Get-Date -Format HH:mm:ss) Exporting is completed. Check the $outputFileName for details."
