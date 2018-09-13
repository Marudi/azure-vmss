param (
	[parameter(Mandatory = $false)]
    [object]$WebhookData
) 
	[OutputType([String])]
	$WebhookBody    =   $WebhookData.RequestBody
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookBody)
	if ($WebhookBody.status -eq "Activated") {
		$connectionName = "AzureRunAsConnection"
		try
		{
		    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
		    "Logging in to Azure..."
		    Add-AzureRmAccount `
		        -ServicePrincipal `
		        -TenantId $servicePrincipalConnection.TenantId `
		        -ApplicationId $servicePrincipalConnection.ApplicationId `
		        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
		}
		catch {
		    if (!$servicePrincipalConnection)
		    {
		        $ErrorMessage = "Connection $connectionName not found."
		        throw $ErrorMessage
		    } else{
		        Write-Error -Message $_.Exception
		        throw $_.Exception
		    }
		}
		$AlertContext = [object]$WebhookBody.context
		$ResourceGroupName = $AlertContext.resourceGroupName
		$VmssName = $AlertContext.resourceName
		$noResize = "noresize"
		$scaleDown = @{
		    "Standard_A0"      = $noResize
		    "Standard_A1"      = "Standard_A0"
		    "Standard_A2"      = "Standard_A1"
		    "Standard_A3"      = "Standard_A2"
		    "Standard_A4"      = "Standard_A3"
		    "Standard_A5"      = $noResize
		    "Standard_A6"      = "Standard_A5"
		    "Standard_A7"      = "Standard_A6"
		    "Standard_A8"      = $noResize
		    "Standard_A9"      = "Standard_A8"
		    "Standard_A10"     = $noResize
		    "Standard_A11"     = "Standard_A10"
		    "Basic_A0"         = $noResize
		    "Basic_A1"         = "Basic_A0"
		    "Basic_A2"         = "Basic_A1"
		    "Basic_A3"         = "Basic_A2"
		    "Basic_A4"         = "Basic_A3"
		    "Standard_D1_v2"   = $noResize
		    "Standard_D2_v2"   = "Standard_D1_v2"
		    "Standard_D3_v2"   = "Standard_D2_v2"
		    "Standard_D4_v2"   = "Standard_D3_v2"
		    "Standard_D5_v2"   = "Standard_D4_v2"
		    "Standard_D11_v2"  = $noResize
		    "Standard_D12_v2"  = "Standard_D11_v2"
		    "Standard_D13_v2"  = "Standard_D12_v2"
		    "Standard_D14_v2"  = "Standard_D13_v2"
			"Standard_DS2_v2"  = "Standard_DS1_v2"
			"Standard_DS1_v2"  = $noResize
		    "Standard_DS1"     = $noResize
		    "Standard_DS2"     = "Standard_DS1"
		    "Standard_DS3"     = "Standard_DS2"
		    "Standard_DS4"     = "Standard_DS3"
		    "Standard_DS11"    = $noResize
		    "Standard_DS12"    = "Standard_DS11"
		    "Standard_DS13"    = "Standard_DS12"
		    "Standard_DS14"    = "Standard_DS13"
		    "Standard_D1"      = $noResize
		    "Standard_D2"      = "Standard_D1"
		    "Standard_D3"      = "Standard_D2"
		    "Standard_D4"      = "Standard_D3" 
		    "Standard_D11"     = $noResize
		    "Standard_D12"     = "Standard_D11"
		    "Standard_D13"     = "Standard_D12"
		    "Standard_D14"     = "Standard_D13"
		    "Standard_G1"      = $noResize
		    "Standard_G2"      = "Standard_G1"
		    "Standard_G3"      = "Standard_G2" 
		    "Standard_G4"      = "Standard_G3"  
		    "Standard_G5"      = "Standard_G4"
		    "Standard_GS1"     = $noResize
		    "Standard_GS2"     = "Standard_GS1"
		    "Standard_GS3"     = "Standard_GS2"
		    "Standard_GS4"     = "Standard_GS3"
		    "Standard_GS5"     = "Standard_GS4"
		}
		try {
		    $vmss = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName -ErrorAction Stop
		} catch {
		    Write-Error "Virtual Machine Scale Set not found"
		    exit
		}
		$currentVmssSize = $vmss.Sku.Name
		Write-Output "`nFound the specified Virtual Machine Scale Set: $VmssName"
		Write-Output "Current size: $currentVmssSize"
		$newVmssSize = ""
		$newVmssSize = $scaleDown[$currentVmssSize]
		if($newVmssSize -eq $noResize) {
		    Write-Output "Virtual Machine Scale Set size $currentVmssSize can't be scaled down."
		} else {
		    Write-Output "`nNew size will be: $newVmssSize"
			$vmss.Sku.Name = $newVmssSize
		    Update-AzureRmVmss -ResourceGroupName $ResourceGroupName -Name $VmssName -VirtualMachineScaleSet $vmss
			Update-AzureRmVmssInstance -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName -InstanceId "*"
		    $updatedVmss = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName
		    $updatedVmssSize = $updatedVmss.Sku.Name
		    Write-Output "`nSize updated to: $updatedVmssSize"
		}
	} else {
		Write-Output "`nAlert not activated"
		exit
	}