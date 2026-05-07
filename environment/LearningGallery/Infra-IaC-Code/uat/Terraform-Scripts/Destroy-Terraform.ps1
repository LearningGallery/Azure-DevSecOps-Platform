[CmdletBinding()]
param (
    [string]$VarFile = "terraform.auto.tfvars",
    [string]$LogFile = "./Logs/tf-destroy-summary.log"
)

$PlanFile = "destroy.tfplan.tmp"

Write-Host "=====================================================================================" -ForegroundColor DarkRed
Write-Host "[!] Fetching Terraform Destroy Plan..." -ForegroundColor Red
Write-Host "=====================================================================================`n" -ForegroundColor DarkRed

# 1. Run destroy plan normally so you see the live status in the foreground
terraform plan -destroy -var-file="$VarFile" -out="$PlanFile"

# Safety check
if (-not (Test-Path $PlanFile)) {
    Write-Host "`n[!] Terraform plan failed. Exiting." -ForegroundColor Red
    exit 1
}

# 2. Silently read the generated plan file to build our custom table
$planOutput = terraform show -no-color $PlanFile

$separator = "====================================================================================="
# FIXED: Using PadRight() to avoid string-formatting parser errors
$header    = 'RESOURCE NAME'.PadRight(65) + ' | ACTION'

Write-Host "`n$separator" -ForegroundColor Cyan
Write-Host " [SUMMARY TABLE]" -ForegroundColor White
Write-Host $separator -ForegroundColor Cyan
Write-Host $header -ForegroundColor Cyan
Write-Host $separator -ForegroundColor Cyan

$logOutput = @()
if ($LogFile) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logOutput += "Terraform Destroy Review - $timestamp"
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

    # FIXED: Using PadRight() for the rows as well
    $rowText = $resource.PadRight(65) + " | "
    Write-Host $rowText -NoNewline
    Write-Host $displayAction -ForegroundColor $color

    if ($LogFile) { $logOutput += "$rowText$displayAction" }
}

Write-Host "$separator`n" -ForegroundColor Cyan

if ($LogFile) {
    $logOutput += $separator
    $logOutput += "" 
    $logOutput | Out-File -FilePath $LogFile -Encoding UTF8 -Append
}

if ($changeCount -eq 0) {
    Write-Host "[OK] Nothing to destroy. Infrastructure is already empty.`n" -ForegroundColor Green
    Remove-Item $PlanFile -ErrorAction SilentlyContinue
    exit
}

# 4. Prompt for execution
$title = "DANGER: Confirm Destroy"
$message = "Are you SURE you want to destroy these $changeCount resources? This cannot be undone."
# FIXED: Using single quotes to prevent ampersand errors
$yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Destroy the resources.'
$no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Cancel the destroy.'
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

$result = $host.ui.PromptForChoice($title, $message, $options, 1) # 1 is default No

if ($result -eq 0) {
    Write-Host "`n[!] Executing Terraform Destroy...`n" -ForegroundColor Red
    terraform apply "$PlanFile"
} else {
    Write-Host "`n[OK] Destroy cancelled by user. Your infrastructure is safe." -ForegroundColor Green
}

# Cleanup
Remove-Item $PlanFile -ErrorAction SilentlyContinue