#!/bin/bash
set -euo pipefail

# Idempotent Linux Bootstrap for Ubuntu 24.04 LTS
# Purpose: Install DevSecOps tooling (Jenkins, SonarQube, Terraform, etc.)

LOG_FILE="/var/log/bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting Bootstrap at $(date) ==="

# Function: Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Update system
echo "[1/10] Updating system packages..."
apt-get update -y && apt-get upgrade -y

# 2. Detect and mount data disk
echo "[2/10] Detecting data disk..."
DATA_DISK=$(lsblk -o NAME,TYPE,SIZE | grep disk | grep -v sda | awk '{print "/dev/"$1}' | head -n1)

if [ -n "$DATA_DISK" ]; then
    MOUNT_POINT="/mnt/data"
    
    # Check if already partitioned
    if ! blkid "$DATA_DISK" >/dev/null 2>&1; then
        echo "Partitioning $DATA_DISK..."
        parted -s "$DATA_DISK" mklabel gpt
        parted -s "$DATA_DISK" mkpart primary xfs 0% 100%
        
        PARTITION="${DATA_DISK}1"
        mkfs.xfs -f "$PARTITION"
        
        # Add to fstab
        UUID=$(blkid -s UUID -o value "$PARTITION")
        echo "UUID=$UUID $MOUNT_POINT xfs defaults,nofail 0 2" >> /etc/fstab
        
        mkdir -p "$MOUNT_POINT"
        mount -a
        echo "Data disk mounted at $MOUNT_POINT"
    else
        echo "Data disk already formatted, skipping..."
    fi
fi

# 3. Install Java 21 (for Jenkins/SonarQube)
if ! command_exists java; then
    echo "[3/10] Installing Java 21..."
    apt-get install -y openjdk-21-jdk
else
    echo "[3/10] Java already installed: $(java -version 2>&1 | head -n1)"
fi

# 4. Install Docker
if ! command_exists docker; then
    echo "[4/10] Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker azureuser
    systemctl enable docker
else
    echo "[4/10] Docker already installed: $(docker --version)"
fi

# 5. Install PostgreSQL 15
if ! command_exists psql; then
    echo "[5/10] Installing PostgreSQL 15..."
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt-get update
    apt-get install -y postgresql-15
    systemctl enable postgresql
else
    echo "[5/10] PostgreSQL already installed: $(psql --version)"
fi

# 6. Install Jenkins
if ! systemctl is-active --quiet jenkins; then
    echo "[6/10] Installing Jenkins..."
    wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | apt-key add -
    sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
    apt-get update
    apt-get install -y jenkins
    systemctl enable jenkins
else
    echo "[6/10] Jenkins already running"
fi

# 7. Install Terraform
if ! command_exists terraform; then
    echo "[7/10] Installing Terraform..."
    wget https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip
    unzip terraform_1.9.0_linux_amd64.zip -d /usr/local/bin/
    rm terraform_1.9.0_linux_amd64.zip
else
    echo "[7/10] Terraform already installed: $(terraform version | head -n1)"
fi

# 8. Install Ansible
if ! command_exists ansible; then
    echo "[8/10] Installing Ansible..."
    apt-get install -y software-properties-common
    add-apt-repository --yes --update ppa:ansible/ansible
    apt-get install -y ansible
else
    echo "[8/10] Ansible already installed: $(ansible --version | head -n1)"
fi

# 9. Install Trivy
if ! command_exists trivy; then
    echo "[9/10] Installing Trivy..."
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
    apt-get update
    apt-get install -y trivy
else
    echo "[9/10] Trivy already installed: $(trivy --version)"
fi

# 10. Install Kubectl & Helm
if ! command_exists kubectl; then
    echo "[10/10] Installing Kubectl & Helm..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl && mv kubectl /usr/local/bin/
    
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "[10/10] Kubectl & Helm already installed"
fi

echo "=== Bootstrap completed at $(date) ==="
