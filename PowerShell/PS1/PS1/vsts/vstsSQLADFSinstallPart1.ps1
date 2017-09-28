    param
    (
		[Parameter(Mandatory)]
        [String]$resourceGroupName,

	    [Parameter(Mandatory)]
        [String]$targetVMname,

		[Parameter(Mandatory)]
        [String]$vmLocation,

		[Parameter(Mandatory)]
        [String]$cseSQLADFSinstallPart1Uri,

	    [Parameter(Mandatory)]
        [String]$nameOfTheScriptToRun,

		[Parameter(Mandatory)]
        [String]$customScriptExtensionName,

        [Parameter(Mandatory)]
        [String]$domainAdminName,

        [Parameter(Mandatory)]
        [String]$domainAdminPassword,

		[Parameter(Mandatory)]
        [String]$VAR_Territory,

        [Parameter(Mandatory)]
        [String]$VAR_ADFSID,

		[Parameter(Mandatory)]
        [String]$VAR_ADDomain,

        [Parameter(Mandatory)]
        [String]$VAR_ADFSAdminPassword,

		[Parameter(Mandatory)]
        [String]$SQLServerID

    )

Set-AzureRmVMCustomScriptExtension -Argument "-domainAdminName $domainAdminName -domainAdminPassword $domainAdminPassword -VAR_Territory $VAR_Territory -VAR_ADFSID $VAR_ADFSID -VAR_ADDomain $VAR_ADDomain -VAR_ADFSAdminPassword $VAR_ADFSAdminPassword -SQLServerID $SQLServerID" `
	-ResourceGroupName $resourceGroupName `
    -VMName $targetVMname `
    -Location $vmLocation `
    -FileUri $cseSQLADFSinstallPart1Uri `
    -Run $nameOfTheScriptToRun `
    -Name $customScriptExtensionName

Remove-AzureRmVMCustomScriptExtension -Force `
	-ResourceGroupName $resourceGroupName `
    -VMName $targetVMname `
    -Name $customScriptExtensionName
