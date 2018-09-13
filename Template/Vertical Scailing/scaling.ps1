param(
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,
 
 [Parameter(Mandatory=$True)]
 [string]
 $AutomationAccountName,
 
 [Parameter(Mandatory=$True)]
 [string]
 $VMScalesetName
)
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )
    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}
$ErrorActionPreference = "Stop"
Write-Host "Logging in...";
Login-AzureRmAccount;
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;
$resourceProviders = @("microsoft.network","microsoft.compute");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}
$date = New-Object System.DateTimeOffset((Get-Date).AddYears(2))
Import-AzureRMAutomationRunbook -Name "ScaleUp" -Path "ScaleUp.ps1" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Type PowerShell -Published
$webhook_1 = New-AzureRmAutomationWebhook -Name "scaleupwebhook" -IsEnabled $True -ExpiryTime "$date" -RunbookName "ScaleUp" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Force
Import-AzureRMAutomationRunbook -Name "ScaleDown" -Path "ScaleDown.ps1" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Type PowerShell -Published
$webhook_2 = New-AzureRmAutomationWebhook -Name "scaledownwebhook" -IsEnabled $True -ExpiryTime "$date" -RunbookName "ScaleDown" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Force
Write-Host "Starting deployment...";
Write-Host
Write-Host "Please Wait...";
$scalename = Get-AzureRmVmss -ResourceGroupName $resourceGroupName -Name $VMScalesetName
$actionWebhook_1 = New-AzureRmAlertRuleWebhook -ServiceUri "$($webhook_1.WebhookURI)"
$actionWebhook_2 = New-AzureRmAlertRuleWebhook -ServiceUri "$($webhook_2.WebhookURI)"
Add-AzureRmMetricAlertRule -Name "Scaleupalert" -Location "$($scalename.Location)" -ResourceGroupName $resourceGroupName -TargetResourceId "$($scalename.Id)" -MetricName "Percentage CPU" -Operator GreaterThan -Threshold "80" -WindowSize "00:05:00" -Action $actionWebhook_1 -TimeAggregationOperator Total
Add-AzureRmMetricAlertRule -Name "Scaledownalert" -Location "$($scalename.Location)" -ResourceGroupName $resourceGroupName -TargetResourceId "$($scalename.Id)" -MetricName "Percentage CPU" -Operator LessThan -Threshold "5" -WindowSize "00:05:00" -Action $actionWebhook_2 -TimeAggregationOperator Total
Write-Host "Deployment complete...";