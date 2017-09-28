    param
    (
        [Parameter(Mandatory)]
        [String]$Input_Territory,

        [Parameter(Mandatory)]
        [String]$Input_ADDomain
    )

Start-Transcript C:\DCcreateOU.txt

# Create OU's
$topou = "$Input_Territory" + "_Infrastructure"
New-ADOrganizationalUnit -Name $topou -Path "DC=$Input_ADDomain,DC=COM"
New-ADOrganizationalUnit -Name "Users" -Path "OU=$topou,DC=$Input_ADDomain,DC=COM"
New-ADOrganizationalUnit -Name "Computers" -Path "OU=$topou,DC=$Input_ADDomain,DC=COM"
New-ADOrganizationalUnit -Name "Groups" -Path "OU=$topou,DC=$Input_ADDomain,DC=COM"
New-ADOrganizationalUnit -Name "Service Accounts" -Path "OU=$topou,DC=$Input_ADDomain,DC=COM"
New-ADOrganizationalUnit -Name "Service Groups" -Path "OU=$topou,DC=$Input_ADDomain,DC=COM"
Stop-Transcript