# Windows Server 2022 Bootstrap Script
# Purpose: Initialize data disk and install DevOps tools via Chocolatey

$ErrorActionPreference = "Stop"
$LogFile = "C:\bootstrap.log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

Write-Log "=== Starting Windows Bootstrap ==="

# 1. Initialize Data Disk
Write-Log "[1/5] Initializing data disks..."
Get-Disk | Where-Object PartitionStyle -eq 'RAW' | ForEach-Object {
    $DiskNumber = $_.Number
    
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -PassThru |
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
    
    Write-Log "Initialized Disk $DiskNumber"
}

# 2. Install Chocolatey
Write-Log "[2/5] Installing Chocolatey..."
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
} else {
    Write-Log "Chocolatey already installed"
}

# 3. Install Git
Write-Log "[3/5] Installing Git..."
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    choco install git -y
    refreshenv
} else {
    Write-Log "Git already installed: $(git --version)"
}

# 4. Install Terraform
Write-Log "[4/5] Installing Terraform..."
if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
    choco install terraform -y
    refreshenv
} else {
    Write-Log "Terraform already installed: $(terraform version)"
}

# 5. Install Kubernetes Tools
Write-Log "[5/5] Installing Kubectl & Helm..."
if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    choco install kubernetes-cli -y
}
if (!(Get-Command helm -ErrorAction SilentlyContinue)) {
    choco install kubernetes-helm -y
}

Write-Log "=== Bootstrap Completed ==="
