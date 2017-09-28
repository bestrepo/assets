    param
    (
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

$domainAdminPasswordSecureString = ConvertTo-SecureString -String $domainAdminPassword -AsPlainText -Force
$DomainCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $domainAdminName, $domainAdminPasswordSecureString

Invoke-Command -ComputerName localhost -ScriptBlock {
Start-Transcript C:\cseSQLADFSinstallPart1.txt

# Created by Adam Cosby - Copyright IAM Technology Group Limited (Trading as IAM Cloud)
# Lewis Added the ability to copy source files from repo via a mapped drive.

### START VARIABLES

    #OtherSettings
    #GroupOU = "OU=Service Groups,OU=" + $VAR_Territory + "_Infrastructure,DC=" + $VAR_ADDomain + ",DC=iamcloud-int,DC=com"
    #ServiceOU = "OU=Service Accounts,OU=" + $VAR_Territory + "_Infrastructure,DC=" + $VAR_ADDomain + ",DC=iamcloud-int,DC=com"
    $GroupOU = "OU=Service Groups,OU=" + $VAR_Territory + "_Infrastructure,DC=federate365,DC=com"
    $ServiceOU = "OU=Service Accounts,OU=" + $VAR_Territory + "_Infrastructure,DC=federate365,DC=com"
    $InstallSourcePath = "C:\IAM Cloud\SQL\Source\"
    $ConfigInstallDir = "C:\IAM Cloud\SQL\" + $VAR_ADFSID + "\"
    $ConfigDestPath = $ConfigInstallDir + $VAR_ADFSID + "_Config.ini"
    $SQLBinDir = "C:\SQLServerFull\"
    $adminaccount = 'iacadmin'   
    $ADFSAdminAcc = "ADFS-" + $VAR_ADFSID + "_SVC"
    $SQLDataLocation = "S:\SQLData\" + $VAR_ADFSID + "\"
    $SQLLogLocation = "L:\SQLLog\" + $VAR_ADFSID + "\"
    $SQLBackupLocation = "S:\SQLBackups\" + $VAR_ADFSID + "\"
    $SQLInstance = $env:computername + "\" + $VAR_ADFSID
    $SQLConfigBUQueryFull = ""
    $SQLArtifactBUQueryFull = ""
    $SQLConfigBUQueryDif = ""
    $SQLArtifactBUQueryDif = ""
    
### END VARIABLES

Add-Type -AssemblyName System.IO.Compression.FileSystem

### START FUNCTIONS

# Retrieve all required files from source
function CopyFromSource
{
    # Create Directory
    New-Item -ItemType Directory -Force -Path $ConfigInstallDir > $null

    #copy config from source
    $ConfigurationSourcePath = $InstallSourcePath + "ConfigurationFile.ini"
    Copy-Item -Path $ConfigurationSourcePath -Destination $ConfigDestPath -Force
    
    # Copy databases
    $SQLInstallSource = $InstallSourcePath + "*"
    Copy-Item -Path $SQLInstallSource -Include "*.sql" -Destination $ConfigInstallDir -Force
}

# Handle Configuration
function SQLConfigurationTransforms($path)
{
    Write-Host "        Updating configuration for $path" -ForegroundColor Yellow

    # {ADFSID}
    (Get-Content $path).replace('[ADFSID]', "$VAR_ADFSID") | Set-Content $path
    # {ADDomain}
    (Get-Content $path).replace('[ADDomain]', "$VAR_ADDomain") | Set-Content $path
    # {MSAAcc}
    (Get-Content $path).replace('[MSAAcc]', "$MSAAcc") | Set-Content $path
    # {MasterAdminGroup}
    (Get-Content $path).replace('[MasterAdminGroup]', "$MasterAdminGroup") | Set-Content $path
    # {InstanceAdminGroup}
    (Get-Content $path).replace('[InstanceAdminGroup]', "$InstanceAdminGroup") | Set-Content $path

    Write-Host "        Configuration updated for $path" -ForegroundColor Green
}

# Handle the setpermissions DB
function SQLSetPermissionsTransforms($path)
{
    Write-Host "        Updating username in set permission for $path" -ForegroundColor Yellow
    $SetPermAccountName = $VAR_ADDomain + "\" + $ADFSAdminAcc

    # {IACUSERACCOUNT}
    (Get-Content $path).replace('{IACUSERACCOUNT}', "$SetPermAccountName") | Set-Content $path

    Write-Host "        Configuration username in set permission for $path" -ForegroundColor Green
}


# Handle Configuration
function SQLDataLogTransforms($path)
{
    Write-Host "        Updating log and data paths" -ForegroundColor Yellow

    # {DataLocation}
    (Get-Content $path).replace('[DataLocation]', $SQLDataLocation) | Set-Content $path
    # {LogLocation}
    (Get-Content $path).replace('[LogLocation]', $SQLLogLocation) | Set-Content $path

    Write-Host "        Configuration updated for $path" -ForegroundColor Green
}

# Handle Agent Jobs
### TODO - make this a single function passing in the param as a second orperator
function SQLJobConfigFullTransforms($path)
{
    Write-Host "        Updating job query $path" -ForegroundColor Yellow
    $Query = $SQLConfigBUQueryFull.Replace("'","''")

    # {QUERY}
    (Get-Content $path).replace('{QUERY}', $Query) | Set-Content $path

    Write-Host "        Query updated for $path" -ForegroundColor Green
}
function SQLJobArtifactFullTransforms($path)
{
    Write-Host "        Updating job query $path" -ForegroundColor Yellow
    $Query = $SQLArtifactBUQueryFull.Replace("'","''")

    # {QUERY}
    (Get-Content $path).replace('{QUERY}', $Query) | Set-Content $path

    Write-Host "        Query updated for $path" -ForegroundColor Green
}
function SQLJobConfigDifTransforms($path)
{
    Write-Host "        Updating job query $path" -ForegroundColor Yellow
    $Query = $SQLConfigBUQueryDif.Replace("'","''")

    # {QUERY}
    (Get-Content $path).replace('{QUERY}', $Query) | Set-Content $path

    Write-Host "        Query updated for $path" -ForegroundColor Green
}
function SQLJobArtifactDifTransforms($path)
{
    Write-Host "        Updating job query $path" -ForegroundColor Yellow
    $Query = $SQLArtifactBUQueryDif.Replace("'","''")

    # {QUERY}
    (Get-Content $path).replace('{QUERY}', $Query) | Set-Content $path

    Write-Host "        Query updated for $path" -ForegroundColor Green
}
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}
function GetLatestVersion($path)
{
    # Work out the latest version

    # Get all contents of the directory and loop through them
    $AllVersions = Get-ChildItem -Path $path -Include *.zip -Recurse |Where-Object { !($_.FullName).contains('Archive') }
    [Version]$LatestVersion = "1.0.0.0"
    foreach ($Version in $AllVersions)
    {

        [Version]$CurrentVersion = $Version.Name -Replace("SQL-v","") -Replace(".zip","")

        if ($CurrentVersion -gt $LatestVersion)
        {
            $LatestVersion = $CurrentVersion
        }
    }

    Write-Host "    Latest version of SQLCode is $LatestVersion" -ForegroundColor Yellow

    return $LatestVersion
}
function checkfilepath($path)
{
If(!(test-path $path))
{
New-Item -ItemType Directory -Force -Path $path
}

}

### END FUNCTIONS



### BEGIN PROCESS

Import-Module ServerManager
Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction SilentlyContinue

Write-Host "Installing AD Powershell Tools (if required)" -ForegroundColor Yellow
Add-WindowsFeature RSAT-AD-Powershell
Write-Host "Finished installing AD Powershell Tools" -ForegroundColor Green

#Create Install Directory

checkfilepath("C:\IAM Cloud\")
#new-item -itemtype directory -path "C:\IAM Cloud\"

#Map Z Drive
$uncServer = "\\iacresourcestore.file.core.windows.net"
$uncFullPath = "$uncServer\adfs\IACAuth\SQL"
$username = "Azure\iacresourcestore"
$password = "gXTOO054mG2HCX3r+FqHnpCA+deEwVPr27cEFPnrV+khet5yTbM16lJJe6xUy4Ol5Zm/em9x8d12d5miqY3XDA=="

net use $uncServer $password /USER:$username  
try  
{
$releaseversion = GetLatestVersion "$uncFullPath\"
$selectedrelease = "$uncFullPath\SQL-v$releaseversion.zip"
#copy the backup
Copy-Item "$selectedrelease" -Destination "C:\IAM Cloud\SQL-v$releaseversion.zip"  
}
catch [System.Exception] {  
WriteToLog -msg "could not copy backup to remote server... $_.Exception.Message" -type Error  
}


Unzip "C:\IAM Cloud\SQL-v$releaseversion.zip" "C:\IAM Cloud\"

checkfilepath("S:\SQLData\")
checkfilepath("S:\SQLBackups\")
checkfilepath("L:\SQLLog\")

# Copy from source to local instances
Write-Host "Copying all files from source to local" -ForegroundColor Yellow
CopyFromSource
Write-Host "All files retrieved" -ForegroundColor Green

# Perform all AD functions
Write-Host "Managing AD Objects for the install" -ForegroundColor Yellow
$MSAAcc = $SQLServerID + "-" + $VAR_ADFSID + "_MSA"
$CompName = $env:computername

# Handle MSA
Write-Host "    Checking and creating MSA if required" -ForegroundColor Yellow
$Res1 = Get-ADServiceAccount -Filter {name -eq $MSAAcc}

if ($Res1 -eq $null)
{
    New-ADServiceAccount –Name $MSAAcc -Enabled $true -RestrictToSingleComputer
    Add-ADComputerServiceAccount -Identity $CompName -ServiceAccount $MSAAcc
    Install-ADServiceAccount $MSAAcc
    Write-Host "    AD MSA Created and installed" -ForegroundColor Green
} else {
    Write-Host "    $MSAAcc already exists and we presume already installed" -ForegroundColor Magenta
}

# Handle Groups
Write-Host "    Checking and creating Groups if required" -ForegroundColor Yellow
$MasterAdminGroup = "SQL-GlobalAdmins_GRP"
$InstanceAdminGroup = "SQL-" + $VAR_ADFSID + "_GRP"
$Res2 = Get-ADGroup -Filter {SamAccountName -eq $MasterAdminGroup}
$Res3 = Get-ADGroup -Filter {SamAccountName -eq $InstanceAdminGroup}


#Master Group
if ($Res2 -eq $null)
{
    New-ADGroup -GroupScope DomainLocal -Name $MasterAdminGroup -SamAccountName $MasterAdminGroup -GroupCategory Security -DisplayName $MasterAdminGroup -Path $GroupOU
    Add-AdGroupMember $MasterAdminGroup $adminaccount
    Write-Host "    AD Group $MasterAdminGroup created - $adminaccount has been members added" -ForegroundColor Green
} else {
    Write-Host "    Group $MasterAdminGroup already exists" -ForegroundColor Magenta
}

 #Instance Group
if ($Res3 -eq $null)
{
    Write-Host "    Creating the ADFS service account to be used" -ForegroundColor Yellow
    New-ADUser -Name $ADFSAdminAcc -SamAccountName $ADFSAdminAcc -AccountPassword (ConvertTo-SecureString $VAR_ADFSAdminPassword -AsPlainText -Force) -PasswordNeverExpires $true -Path $ServiceOU -PassThru -Description "Account used for $VAR_ADFSID" | Enable-ADAccount
    
    Write-Host "    Creating the SQL Admin group for this ADFS Instance" -ForegroundColor Yellow
    New-ADGroup -GroupScope DomainLocal -Name $InstanceAdminGroup -SamAccountName $InstanceAdminGroup -GroupCategory Security -DisplayName $InstanceAdminGroup -Path $GroupOU
    Get-ADUser -SearchBase $ServiceOU -Filter {name -eq $ADFSAdminAcc} | ForEach-Object {Add-ADGroupMember -Identity $InstanceAdminGroup -Members $_}
    Write-Host "    AD Group $InstanceAdminGroup and ADFS admin account created ($ADFSAdminAcc / $VAR_ADFSAdminPassword) - this user is added as members" -ForegroundColor Green
} else {
    Write-Host "    Group $InstanceAdminGroup already exists" -ForegroundColor Magenta
}

Write-Host "All AD Objects are handled" -ForegroundColor Green

Stop-Transcript

Restart-Computer -Force
} -Credential $DomainCredentials