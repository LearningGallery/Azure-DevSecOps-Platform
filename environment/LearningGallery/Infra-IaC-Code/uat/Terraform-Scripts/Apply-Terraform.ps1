[CmdletBinding()]
param (
    [string]$VarFile = "terraform.auto.tfvars",
    [string]$LogFile = "./Logs/tf-apply-summary.log"
)

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [string]$Path
)

$PlanFile = "apply.tfplan.tmp"

Write-Host "=====================================================================================" -ForegroundColor Cyan
Write-Host "[*] Fetching Terraform Apply Plan..." -ForegroundColor Cyan
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
    $logOutput += "Terraform Apply Review - $timestamp"
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

if ($LogFile) {
    $logOutput += $separator
    $logOutput += "" 
    $logOutput | Out-File -FilePath $LogFile -Encoding UTF8 -Append
}

if ($changeCount -eq 0) {
    Write-Host "[OK] No changes required. Infrastructure matches the configuration.`n" -ForegroundColor Green
    Remove-Item $PlanFile -ErrorAction SilentlyContinue
    exit
}

# 4. Prompt for execution
$title = "Confirm Apply"
$message = "Do you want to apply these $changeCount changes?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Apply the changes.'
$no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Cancel the apply.'
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

$result = $host.ui.PromptForChoice($title, $message, $options, 1) # 1 is default No

if ($result -eq 0) {
    Write-Host "`n[*] Executing Terraform Apply...`n" -ForegroundColor Green
    terraform apply "$PlanFile"
} else {
    Write-Host "`n[!] Apply cancelled by user." -ForegroundColor Yellow
}

# Cleanup
Remove-Item $PlanFile -ErrorAction SilentlyContinue