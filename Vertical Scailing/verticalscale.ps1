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

 [string]
 $resourceGroupLocation,

 [string]
 $templateFilePath = "vertical_template.json",

 [string]
 $parametersFilePath = "vertical_template_parameters.json"
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
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}
$date = New-Object System.DateTimeOffset((Get-Date).AddYears(2))
Import-AzureRMAutomationRunbook -Name "ScaleUp" -Path "ScaleUp.ps1" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Type PowerShell -Published
$webhook_1 = New-AzureRmAutomationWebhook -Name "scaleupwebhook" -IsEnabled $True -ExpiryTime "$date" -RunbookName "ScaleUp" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Force
Import-AzureRMAutomationRunbook -Name "ScaleDown" -Path "ScaleDown.ps1" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Type PowerShell -Published
$webhook_2 = New-AzureRmAutomationWebhook -Name "scaledownwebhook" -IsEnabled $True -ExpiryTime "$date" -RunbookName "ScaleDown" -ResourceGroupName $resourceGroupName -AutomationAccountName "$AutomationAccountName" -Force
Write-Host "Starting deployment...";
Write-Host
Write-Host "Please Wait...";
if(Test-Path $parametersFilePath) {
    $scaleset = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
}
$scalename = Get-AzureRmVmss -ResourceGroupName $resourceGroupName -Name $scaleset.Parameters['vMscalesetName'].Value
$actionWebhook_1 = New-AzureRmAlertRuleWebhook -ServiceUri "$($webhook_1.WebhookURI)"
$actionWebhook_2 = New-AzureRmAlertRuleWebhook -ServiceUri "$($webhook_2.WebhookURI)"
Add-AzureRmMetricAlertRule -Name "Scaleupalert" -Location "$($scalename.Location)" -ResourceGroupName $resourceGroupName -TargetResourceId "$($scalename.Id)" -MetricName "Percentage CPU" -Operator GreaterThan -Threshold "80" -WindowSize "00:05:00" -Action $actionWebhook_1 -TimeAggregationOperator Total
Add-AzureRmMetricAlertRule -Name "Scaledownalert" -Location "$($scalename.Location)" -ResourceGroupName $resourceGroupName -TargetResourceId "$($scalename.Id)" -MetricName "Percentage CPU" -Operator LessThan -Threshold "5" -WindowSize "00:05:00" -Action $actionWebhook_2 -TimeAggregationOperator Total
Write-Host "Deployment complete...";