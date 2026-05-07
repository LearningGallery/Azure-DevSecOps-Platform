[CmdletBinding()]
param (
    # --- Local Default Parameters ---
    [string]$VarFile = "terraform.auto.tfvars",
    [string]$LogFile = "Logs/tf-plan-summary.log",

    [Parameter(Mandatory=$true)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [string]$Path
)

# Tell PowerShell to stop immediately if it hits a fatal script error
$ErrorActionPreference = "Stop"

# Navigate to the correct directory based on the GitHub Matrix
Set-Location -Path $Path

Write-Host "[*] Initializing Terraform Backend..." -ForegroundColor DarkGray
terraform init -no-color

$PlanFile = "review.tfplan.tmp"

Write-Host "=====================================================================================" -ForegroundColor Cyan
Write-Host "[*] Fetching Terraform Plan Review for Environment: $Environment" -ForegroundColor Cyan
Write-Host "=====================================================================================`n" -ForegroundColor Cyan

# 1. Pre-Flight Check: Verify the Variable File Exists
if (-not (Test-Path $VarFile)) {
    Write-Host "`n[!] FATAL ERROR: Cannot find the variable file '$VarFile'." -ForegroundColor Red
    Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "Did you remember to push terraform.auto.tfvars to GitHub?" -ForegroundColor Yellow
    exit 1
}

# 2. Run plan and capture ALL output (Standard & Error Streams)
Write-Host "Executing: terraform plan -var-file=`"$VarFile`" -out=`"$PlanFile`"" -ForegroundColor DarkGray
$rawOutput = terraform plan -var-file="$VarFile" -out="$PlanFile" 2>&1

# 3. Safety check: Check Terraform's native exit code
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $PlanFile)) {
    Write-Host "`n[!] Terraform plan failed! Here is the raw error from Terraform:" -ForegroundColor Red
    Write-Host "-------------------------------------------------------------------" -ForegroundColor Red
    # Print the raw error stream so it shows up in the GitHub logs
    $rawOutput | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    Write-Host "-------------------------------------------------------------------" -ForegroundColor Red
    exit 1
}

# 4. Silently read the generated plan file to build our custom table
$planOutput = terraform show -no-color $PlanFile

$separator = "====================================================================================="
$header    = 'RESOURCE NAME'.PadRight(65) + ' | ACTION'

Write-Host "`n$separator" -ForegroundColor Cyan
Write-Host " [SUMMARY TABLE]" -ForegroundColor White
Write-Host $separator -ForegroundColor Cyan
Write-Host $header -ForegroundColor Cyan
Write-Host $separator -ForegroundColor Cyan

$logOutput = @()
if ($LogFile) {
    # Ensure Logs directory exists before trying to write to it
    $logDir = Split-Path $LogFile
    if ($logDir -and -not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logOutput += "Terraform Plan Review - $timestamp"
    $logOutput += $separator
    $logOutput += $header
    $logOutput += $separator
}

$changeCount = 0

# 5. Build the table
$planOutput | Select-String "# (.*?) (will be|must be) (created|destroyed|updated in-place|replaced)" | ForEach-Object {
    $changeCount++
    $resource = $_.Matches.Groups[1].Value
    $action   = $_.Matches.Groups[3].Value

    switch ($action) {
        "created"          { $color = "Green";  $displayAction = "+ Create" }
        "destroyed"        { $color = "Red";    $displayAction = "- Delete" }
        "updated in-place" { $color = "Yellow"; $displayAction = "~ Modify" }
        "replaced"         { $color = "Red";    $displayAction = "+/- Replace" }
    }

    $rowText = $resource.PadRight(65) + " | "
    Write-Host $rowText -NoNewline
    Write-Host $displayAction -ForegroundColor $color

    if ($LogFile) { $logOutput += "$rowText$displayAction" }
}

Write-Host "$separator`n" -ForegroundColor Cyan

# Write to the log file if requested
if ($LogFile) {
    $logOutput += $separator
    $logOutput += "" 
    $logOutput | Out-File -FilePath $LogFile -Encoding UTF8 -Append
    Write-Host "[+] Plan summary successfully appended to log: $LogFile`n" -ForegroundColor Green
}

if ($changeCount -eq 0) {
    Write-Host "[OK] No changes required. Infrastructure matches the configuration.`n" -ForegroundColor Green
} else {
    Write-Host "[i] Review complete. $changeCount resources will be affected.`n" -ForegroundColor Cyan
}

# Cleanup temporary plan file
Remove-Item $PlanFile -ErrorAction SilentlyContinue