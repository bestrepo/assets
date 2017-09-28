    param
    (
		[Parameter(Mandatory)]
        [String]$resourceGroupName,

	    [Parameter(Mandatory)]
        [String]$targetVMname,

		[Parameter(Mandatory)]
        [String]$vmLocation,

		[Parameter(Mandatory)]
        [String]$cseDCcreateOUuri,

	    [Parameter(Mandatory)]
        [String]$nameOfTheScriptToRun,

		[Parameter(Mandatory)]
        [String]$customScriptExtensionName,

        [Parameter(Mandatory)]
        [String]$Input_Territory,

        [Parameter(Mandatory)]
        [String]$Input_ADDomain
    )

Set-AzureRmVMCustomScriptExtension -Argument "-Input_Territory $Input_Territory -Input_ADDomain $Input_ADDomain" `
	-ResourceGroupName $resourceGroupName `
    -VMName $targetVMname `
    -Location $vmLocation `
    -FileUri $cseDCcreateOUuri `
    -Run $nameOfTheScriptToRun `
    -Name $customScriptExtensionName

Remove-AzureRmVMCustomScriptExtension -Force `
	-ResourceGroupName $resourceGroupName `
    -VMName $targetVMname `
    -Name $customScriptExtensionName
