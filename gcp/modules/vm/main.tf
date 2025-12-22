# ============================================================================
# VM Module - main.tf (GCP Compute Engine)
# ============================================================================
# Bastion 및 Management 서버 생성
# ============================================================================

# ============================================================================
# SSH Key Metadata
# ============================================================================
locals {
  ssh_keys = "${var.ssh_user}:${var.ssh_public_key}"
}

# ============================================================================
# Bastion Host (Public Subnet)
# ============================================================================
resource "google_compute_instance" "bastion" {
  name         = "${var.project_name}-bastion"
  machine_type = var.bastion_machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["bastion", "ssh"]

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.public_subnet_id

    # Public IP
    access_config {
      network_tier = "STANDARD"
    }
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Install prerequisites
    apt-get update
    apt-get install -y apt-transport-https ca-certificates gnupg curl

    # Add Google Cloud SDK repo
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list

    # Add Kubernetes repo
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

    # Install packages
    apt-get update
    apt-get install -y kubectl google-cloud-cli-gke-gcloud-auth-plugin
  EOF

  labels = {
    environment = var.environment
    role        = "bastion"
    project     = var.project_name
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
}

# ============================================================================
# Management Server (Private Subnet)
# ============================================================================
resource "google_compute_instance" "mgmt" {
  name         = "${var.project_name}-mgmt"
  machine_type = var.mgmt_machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["mgmt", "internal"]

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.private_subnet_id

    # No public IP (private only)
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Variables
    SSH_USER="${var.ssh_user}"
    GKE_CLUSTER="${var.gke_cluster_name}"
    GKE_REGION="${var.gke_cluster_region}"
    PROJECT_ID="${var.project_id}"

    # Log file for debugging
    LOG_FILE="/var/log/startup-script.log"
    exec > >(tee -a $LOG_FILE) 2>&1
    echo "=== Startup script started at $(date) ==="

    # Install prerequisites
    apt-get update
    apt-get install -y apt-transport-https ca-certificates gnupg curl mysql-client jq

    # Add Google Cloud SDK repo
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list

    # Add Kubernetes repo
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

    # Add Docker repo
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

    # Install packages
    apt-get update
    apt-get install -y kubectl google-cloud-cli-gke-gcloud-auth-plugin docker-ce docker-ce-cli containerd.io

    # Add user to docker group
    usermod -aG docker $SSH_USER

    # Create .kube directory
    mkdir -p /home/$SSH_USER/.kube
    chown $SSH_USER:$SSH_USER /home/$SSH_USER/.kube

    # Add environment variables to bashrc for GKE auth plugin (avoid duplicates)
    grep -q 'USE_GKE_GCLOUD_AUTH_PLUGIN' /home/$SSH_USER/.bashrc || echo 'export USE_GKE_GCLOUD_AUTH_PLUGIN=True' >> /home/$SSH_USER/.bashrc
    grep -q 'KUBECONFIG=' /home/$SSH_USER/.bashrc || echo 'export KUBECONFIG=/home/$SSH_USER/.kube/config' >> /home/$SSH_USER/.bashrc

    # Add to /etc/environment for all sessions (non-interactive shells)
    grep -q 'USE_GKE_GCLOUD_AUTH_PLUGIN' /etc/environment || echo 'USE_GKE_GCLOUD_AUTH_PLUGIN=True' >> /etc/environment
    grep -q 'KUBECONFIG=' /etc/environment || echo 'KUBECONFIG=/home/$SSH_USER/.kube/config' >> /etc/environment

    # Wait for GKE cluster to be RUNNING (max 5 minutes)
    echo "Waiting for GKE cluster $GKE_CLUSTER to be ready..."
    MAX_RETRIES=30
    RETRY_COUNT=0
    CLUSTER_STATUS="NOT_FOUND"

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      CLUSTER_STATUS=$(gcloud container clusters describe $GKE_CLUSTER --region $GKE_REGION --project $PROJECT_ID --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
      if [ "$CLUSTER_STATUS" = "RUNNING" ]; then
        echo "GKE cluster is RUNNING!"
        break
      fi
      echo "Cluster status: $CLUSTER_STATUS. Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
      RETRY_COUNT=$((RETRY_COUNT + 1))
      sleep 10
    done

    if [ "$CLUSTER_STATUS" = "RUNNING" ]; then
      # Configure GKE cluster credentials
      echo "Configuring kubectl for user $SSH_USER..."
      su - $SSH_USER -c "export USE_GKE_GCLOUD_AUTH_PLUGIN=True && gcloud container clusters get-credentials $GKE_CLUSTER --region $GKE_REGION --project $PROJECT_ID" && echo "kubectl configured successfully!" || echo "WARNING: Failed to configure kubectl"
    else
      echo "WARNING: GKE cluster not ready after waiting. Run ~/configure-kubectl.sh manually."
    fi

    # Create a script for manual re-configuration if needed
    cat > /home/$SSH_USER/configure-kubectl.sh << 'SCRIPT'
#!/bin/bash
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials ${var.gke_cluster_name} --region ${var.gke_cluster_region} --project ${var.project_id}
echo "kubectl configured for GKE cluster: ${var.gke_cluster_name}"
kubectl get nodes
SCRIPT
    chmod +x /home/$SSH_USER/configure-kubectl.sh
    chown $SSH_USER:$SSH_USER /home/$SSH_USER/configure-kubectl.sh

    echo "=== Startup script completed at $(date) ==="
  EOF

  labels = {
    environment = var.environment
    role        = "management"
    project     = var.project_name
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
}

# ============================================================================
# Firewall Rules
# ============================================================================

# SSH to Bastion from anywhere
resource "google_compute_firewall" "bastion_ssh" {
  name    = "${var.project_name}-bastion-ssh"
  network = var.network_id
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bastion"]
}

# SSH from Bastion to internal servers
resource "google_compute_firewall" "internal_ssh" {
  name    = "${var.project_name}-internal-ssh"
  network = var.network_id
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  target_tags = ["mgmt", "internal"]
}
