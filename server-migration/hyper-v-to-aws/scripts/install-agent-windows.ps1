<#
=====================================================================
 BallotOnline — Install the AWS Replication Agent on a Windows Hyper-V guest
=====================================================================
 Run in an elevated PowerShell session on each Windows source server
 (for example the Intranet server).

 1. Checks outbound connectivity the agent needs (TCP 443).
 2. Downloads the installer for the target Region.
 3. Installs the agent using short-lived credentials read from the
    environment — never hard-code keys in this file.

 Usage:
   $env:AWS_REGION            = "us-east-1"
   $env:AWS_ACCESS_KEY_ID     = "..."   # IAM user/role with the
   $env:AWS_SECRET_ACCESS_KEY = "..."   # AWSApplicationMigrationAgentInstallationPolicy
   $env:AWS_SESSION_TOKEN     = "..."   # optional, for temporary credentials
   .\install-agent-windows.ps1
=====================================================================
#>
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

foreach ($name in "AWS_REGION", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY") {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        throw "Set the $name environment variable first."
    }
}

$region     = $env:AWS_REGION
$bucketHost = "aws-application-migration-service-$region.s3.$region.amazonaws.com"
$mgnHost    = "mgn.$region.amazonaws.com"

Write-Host "== Pre-flight: outbound TCP 443"
foreach ($target in $mgnHost, $bucketHost) {
    if (Test-NetConnection -ComputerName $target -Port 443 -InformationLevel Quiet) {
        Write-Host "  OK    ${target}:443"
    } else {
        throw "Cannot reach ${target}:443 - check firewall, proxy, and DNS before continuing."
    }
}

Write-Host "== Downloading installer"
$installer = Join-Path $env:TEMP "AwsReplicationWindowsInstaller.exe"
Invoke-WebRequest -UseBasicParsing `
    -Uri "https://$bucketHost/latest/windows/AwsReplicationWindowsInstaller.exe" `
    -OutFile $installer

Write-Host "== Installing AWS Replication Agent"
$arguments = @(
    "--region", $region,
    "--aws-access-key-id", $env:AWS_ACCESS_KEY_ID,
    "--aws-secret-access-key", $env:AWS_SECRET_ACCESS_KEY,
    "--no-prompt"
)
if ($env:AWS_SESSION_TOKEN) {
    $arguments += @("--aws-session-token", $env:AWS_SESSION_TOKEN)
}
& $installer @arguments
if ($LASTEXITCODE -ne 0) { throw "Installer exited with code $LASTEXITCODE." }

Remove-Item $installer -Force
Write-Host ""
Write-Host "Done. The server now appears in the MGN console under 'Source servers'."
Write-Host "Initial sync uses TCP 1500 to the replication servers in the staging subnet."
