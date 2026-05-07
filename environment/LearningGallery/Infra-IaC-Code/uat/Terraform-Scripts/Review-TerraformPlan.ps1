[CmdletBinding()]
param (
    [string]$VarFile = "terraform.tfvars",
    [string]$LogFile = "Logs/tf-plan-summary.log"
)

$PlanFile = "review.tfplan.tmp"

Write-Host "=====================================================================================" -ForegroundColor Cyan
Write-Host "[*] Fetching Terraform Plan Review..." -ForegroundColor Cyan
Write-Host "=====================================================================================`n" -ForegroundColor Cyan

# 1. Run plan normally so you see the live status in the foreground
terraform plan -var-file="$VarFile" -out="$PlanFile"

# Safety check: If the plan failed (e.g., syntax error), stop the script
if (-not (Test-Path $PlanFile)) {
    Write-Host "`n[!] Terraform plan failed. Exiting." -ForegroundColor Red
    exit
}

# 2. Silently read the generated plan file to build our custom table
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
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logOutput += "Terraform Plan Review - $timestamp"
    $logOutput += $separator
    $logOutput += $header
    $logOutput += $separator
}

$changeCount = 0

# 3. Build the table
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