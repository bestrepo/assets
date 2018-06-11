[CmdletBinding()]
Param(
    [string]
    $VSTSToken,
    [string]
    $VSTSUrl,
    [string]    
    $windowsLogonAccount,
    [string]
    $windowsLogonPassword
)

$ErrorActionPreference="Stop";

If(-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
{
     throw "Run command in Administrator PowerShell Prompt"
};

# Set Execution

set-executionpolicy unrestricted -Force
     
if(-NOT (Test-Path $env:SystemDrive\'vstsagent'))
{
    mkdir $env:SystemDrive\'vstsagent'
}; 

Set-Location $env:SystemDrive\'vstsagent'; 

for($i=1; $i -lt 100; $i++)
{
    $destFolder="A"+$i.ToString();
    if(-NOT (Test-Path ($destFolder)))
    {
        mkdir $destFolder;
        Set-Location $destFolder;
        break;
    }
}; 

$agentZip="$PWD\agent.zip";

$DefaultProxy=[System.Net.WebRequest]::DefaultWebProxy;
$WebClient=New-Object Net.WebClient; 
$Uri='https://vstsagentpackage.azureedge.net/agent/2.134.2/vsts-agent-win-x64-2.134.2.zip';

if($DefaultProxy -and (-not $DefaultProxy.IsBypassed($Uri)))
{
    $WebClient.Proxy = New-Object Net.WebProxy($DefaultProxy.GetProxy($Uri).OriginalString, $True);
}; 

$WebClient.DownloadFile($Uri, $agentZip);
Add-Type -AssemblyName System.IO.Compression.FileSystem;[System.IO.Compression.ZipFile]::ExtractToDirectory($agentZip, "$PWD");

.\config.cmd --unattended `
             --url $VSTSUrl `
             --auth PAT `
             --token $VSTSToken `
             --pool "Default" `
             --agent $env:COMPUTERNAME `
             --replace `
             --runasservice `
             --work '_work' `
             --windowsLogonAccount $windowsLogonAccount `
             --windowsLogonPassword $windowsLogonPassword 

Remove-Item $agentZip;


# Install Azure powershell module 

Install-Module -Name AzureRM -AllowClobber -force

# Install VS Build Tools

$BuildToolsZip="$PWD\build.exe";

$DefaultProxy=[System.Net.WebRequest]::DefaultWebProxy;
$WebClient=New-Object Net.WebClient; 
$Uri='https://download.visualstudio.microsoft.com/download/pr/12390436/e64d79b40219aea618ce2fe10ebd5f0d/vs_BuildTools.exe';

if($DefaultProxy -and (-not $DefaultProxy.IsBypassed($Uri)))
{
    $WebClient.Proxy = New-Object Net.WebProxy($DefaultProxy.GetProxy($Uri).OriginalString, $True);
}; 

$WebClient.DownloadFile($Uri, $BuildToolsZip);

$args1 = @('--add Microsoft.VisualStudio.Workload.WebBuildTools','--add Microsoft.VisualStudio.Workload.NodeBuildTools','--add Microsoft.VisualStudio.Workload.VCTools','--add Microsoft.VisualStudio.Workload.NetCoreBuildTools','--add Microsoft.VisualStudio.Workload.AzureBuildTools','--add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools','--add Microsoft.VisualStudio.Workload.MSBuildTools','--add Microsoft.VisualStudio.Component.NuGet.BuildTools', '--add Microsoft.Net.Component.4.7.1.TargetingPack', '--add Microsoft.Net.Component.4.7.1.SDK','--add Microsoft.Net.Component.4.7.SDK','--add Microsoft.Net.Component.4.7.TargetingPack','--add Microsoft.Net.Component.4.6.2.SDK','--add Microsoft.Net.Component.4.6.2.TargetingPack', '--add Microsoft.Net.Component.4.6.TargetingPack', '--add Microsoft.Net.Component.4.5.2.TargetingPack', '--add Microsoft.Net.Component.4.5.1.TargetingPack', '--add Microsoft.Net.Component.4.5.TargetingPack', '--add Microsoft.Net.Component.4.TargetingPack', '--quiet', '--norestart')

Start-Process -FilePath build.exe -ArgumentList $args1 -Wait
