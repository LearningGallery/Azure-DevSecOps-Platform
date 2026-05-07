[CmdletBinding()]
param (
    # --- Local Default Parameters ---
    [string]$VarFile = "terraform.auto.tfvars",
    [string]$LogFile = "Logs/tf-destroy-summary.log",

    # --- CI/CD Matrix Parameters ---
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

# Initialize Terraform natively inside the target directory
Write-Host "[*] Initializing Terraform Backend..." -ForegroundColor DarkGray
terraform init -no-color

$PlanFile = "destroy.tfplan.tmp"

Write-Host "=====================================================================================" -ForegroundColor DarkRed
Write-Host "[!] Fetching Terraform Destroy Plan for Environment: $Environment" -ForegroundColor Red
Write-Host "=====================================================================================`n" -ForegroundColor DarkRed

# 1. Pre-Flight Check
if (-not (Test-Path $VarFile)) {
    Write-Host "`n[!] FATAL ERROR: Cannot find the variable file '$VarFile'." -ForegroundColor Red
    exit 1
}

# ==============================================================================
# [NEW FIX] 2. The Firewall Bypass (Targeted Apply)
# Force Terraform to update the firewalls with the new GitHub Runner IP 
# before attempting to read the state of the containers inside.
# ==============================================================================
Write-Host "`n[*] Bypassing firewalls: Whitelisting new GitHub Runner IP..." -ForegroundColor DarkGray

# We target ONLY the Key Vault and Storage Account to avoid the 403 container errors
terraform apply -target="module.storage.azurerm_storage_account.main" -target="module.security.azurerm_key_vault.main" -var-file="$VarFile" -auto-approve 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[*] Firewall rules successfully updated! Pausing for 45 seconds to allow Azure network propagation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 45
} else {
    Write-Host "[!] Warning: Targeted firewall update threw an error. Destroy may still hit 403 errors." -ForegroundColor Yellow
}
# ==============================================================================

# 3. Run plan to generate the execution file and capture output
Write-Host "`nExecuting: terraform plan -destroy -var-file=`"$VarFile`" -out=`"$PlanFile`"" -ForegroundColor DarkGray
$rawOutput = terraform plan -destroy -var-file="$VarFile" -out="$PlanFile" 2>&1

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $PlanFile)) {
    Write-Host "`n[!] Terraform destroy plan failed! Raw error:" -ForegroundColor Red
    $rawOutput | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    exit 1
}

# 4. Build the Summary Table
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
    $logDir = Split-Path $LogFile
    if ($logDir -and -not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logOutput += "Terraform Destroy Review - $timestamp`n$separator`n$header`n$separator"
}

$changeCount = 0

$planOutput | Select-String "# (.*?) (will be|must be) (created|destroyed|updated in-place|replaced)" | ForEach-Object {
    $changeCount++
    $resource   = $_.Matches.Groups[1].Value
    $changeType = $_.Matches.Groups[3].Value # Renamed to avoid collision with $Action

    switch ($changeType) {
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

if ($LogFile) {
    $logOutput += "$separator`n" 
    $logOutput | Out-File -FilePath $LogFile -Encoding UTF8 -Append
}

# 5. Pipeline Execution Gate
if ($changeCount -eq 0) {
    Write-Host "[OK] Nothing to destroy. Infrastructure is already empty.`n" -ForegroundColor Green
    Remove-Item $PlanFile -ErrorAction SilentlyContinue
    exit 0
}

# In CI/CD, getting to this point means the human already approved via the GitHub UI.
# We execute automatically.
Write-Host "`n[!] GitHub Environment Approval Confirmed. Executing Terraform Destroy...`n" -ForegroundColor Red

# 6. Apply the destroy plan
terraform apply -no-color "$PlanFile"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!] Terraform Destroy Failed during execution." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[+] Infrastructure Successfully Destroyed." -ForegroundColor Green
}

# Cleanup
Remove-Item $PlanFile -ErrorAction SilentlyContinue