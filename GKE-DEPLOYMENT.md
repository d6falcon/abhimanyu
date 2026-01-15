# Abhimanyu CTF - Docker & GKE Deployment Guide

## Overview
This guide provides the necessary Docker and Kubernetes configuration files to deploy the Abhimanyu CTF machine to Google Kubernetes Engine (GKE) in the **europe-west region**.

## Files Included

### 1. **Dockerfile**
Multi-stage Docker build that creates a containerized CTF machine with:
- Ubuntu 22.04 base image
- SSH server for CTF access
- Python 3 support
- Common CTF tools (netcat, socat, xinetd)
- Health checks
- Non-root user for security

### 2. **k8s-deployment.yaml**
Complete Kubernetes manifest including:
- **Namespace**: `ctf-namespace` for isolated deployment
- **Deployment**: Abhimanyu CTF with:
  - Multi-replica setup (2 replicas, autoscaling up to 10)
  - Node affinity to ensure deployment in europe-west regions
  - Security contexts (non-root user, read-only filesystems where possible)
  - Resource limits and requests
  - Liveness and readiness probes
  
- **Service**: LoadBalancer exposing:
  - Port 22 (SSH)
  - Port 80 (HTTP)
  - Port 443 (HTTPS)
  - Port 8080 (Custom)
  
- **HorizontalPodAutoscaler**: Auto-scaling based on CPU/memory usage
- **PodDisruptionBudget**: Ensures minimum availability during updates
- **ConfigMap**: For configuration and challenge data

### 3. **deploy-to-gke.sh**
Automated deployment script that:
- Checks prerequisites (gcloud, kubectl, docker)
- Authenticates with GCP
- Creates GKE cluster in europe-west region
- Builds Docker image locally
- Pushes to Google Container Registry (GCR)
- Deploys to GKE
- Monitors deployment status
- Provides access information

## Prerequisites

### Required Tools
```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Install kubectl
gcloud components install kubectl

# Install Docker
# macOS: brew install docker
# Linux: sudo apt-get install docker.io
# Windows: Download Docker Desktop
```

### GCP Setup
1. Create a GCP project
2. Enable the following APIs:
   - Kubernetes Engine API
   - Container Registry API
   - Compute Engine API

3. Set up authentication:
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

## Deployment Instructions

### Option 1: Using the Deployment Script (Recommended)

```bash
# Set environment variables
export GCP_PROJECT_ID="your-gcp-project-id"
export GKE_CLUSTER_NAME="abhimanyu-ctf-cluster"
export GKE_REGION="europe-west1"
export GKE_ZONE="europe-west1-b"

# Make script executable
chmod +x deploy-to-gke.sh

# Run deployment
./deploy-to-gke.sh latest
```

The script will:
1. Verify all prerequisites
2. Authenticate with GCP
3. Create a GKE cluster in europe-west1
4. Build and push Docker image
5. Deploy to Kubernetes
6. Display service endpoint

### Option 2: Manual Deployment

```bash
# Step 1: Authenticate with GCP
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth configure-docker gcr.io

# Step 2: Create GKE cluster in europe-west region
gcloud container clusters create abhimanyu-ctf-cluster \
  --region=europe-west1 \
  --zone=europe-west1-b \
  --num-nodes=2 \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=10

# Step 3: Get cluster credentials
gcloud container clusters get-credentials abhimanyu-ctf-cluster \
  --region=europe-west1 \
  --project=YOUR_PROJECT_ID

# Step 4: Build Docker image
docker build -t gcr.io/YOUR_PROJECT_ID/abhimanyu:latest .

# Step 5: Push to GCR
docker push gcr.io/YOUR_PROJECT_ID/abhimanyu:latest

# Step 6: Update manifest with your project ID
sed -i 's|gcr.io/PROJECT_ID/|gcr.io/YOUR_PROJECT_ID/|g' k8s-deployment.yaml

# Step 7: Deploy to Kubernetes
kubectl apply -f k8s-deployment.yaml

# Step 8: Monitor deployment
kubectl get deployments -n ctf-namespace
kubectl get pods -n ctf-namespace
```

## Accessing the CTF Machine

Once deployed, get the external IP:

```bash
kubectl get svc abhimanyu-service -n ctf-namespace

# SSH Access
ssh -p 22 ctf@EXTERNAL_IP

# Default credentials
# Username: ctf
# Password: ctf123
```

## Monitoring and Logs

```bash
# View deployment status
kubectl get all -n ctf-namespace

# View pod logs
kubectl logs -f -n ctf-namespace -l app=abhimanyu-ctf

# View specific pod logs
kubectl logs <pod-name> -n ctf-namespace

# Describe deployment
kubectl describe deployment abhimanyu-ctf -n ctf-namespace

# Monitor autoscaling
kubectl get hpa -n ctf-namespace
```

## Security Considerations

1. **Non-root User**: Pods run as non-root user (ctf, UID 1000)
2. **Network Policies**: Consider adding NetworkPolicies to restrict traffic
3. **RBAC**: Implement Role-Based Access Control for production
4. **SSL/TLS**: Consider adding SSL certificates for HTTPS
5. **Secrets**: Store sensitive data in Kubernetes Secrets, not ConfigMaps
6. **Image Registry**: Use private GCR registry with access controls

## Scaling and Performance

### Horizontal Scaling
The deployment includes HPA (HorizontalPodAutoscaler) that:
- Scales up when CPU > 70% or Memory > 80%
- Scales down gradually after 5 minutes of stability
- Min replicas: 2, Max replicas: 10

### Resource Allocation
- **CPU Request**: 250m (250 millicores)
- **Memory Request**: 256Mi
- **CPU Limit**: 500m
- **Memory Limit**: 512Mi

Adjust these values based on your CTF challenge requirements.

## Europe-West Region Constraint

This deployment is configured to run **only** in europe-west regions:
- **europe-west1** (Belgium)
- **europe-west4** (Netherlands)
- **europe-west6** (Switzerland)

The node affinity rules in the Kubernetes manifest enforce this constraint.

## Cleanup

To remove the deployment:

```bash
# Delete the namespace (removes all resources)
kubectl delete namespace ctf-namespace

# Delete the GKE cluster
gcloud container clusters delete abhimanyu-ctf-cluster --region=europe-west1

# Delete GCR images
gcloud container images delete gcr.io/YOUR_PROJECT_ID/abhimanyu:latest
```

## Troubleshooting

### Pod fails to start
```bash
kubectl describe pod <pod-name> -n ctf-namespace
kubectl logs <pod-name> -n ctf-namespace
```

### Service has no external IP
```bash
# Wait for LoadBalancer to assign IP
kubectl get svc abhimanyu-service -n ctf-namespace -w
```

### SSH connection refused
```bash
# Check pod status
kubectl get pods -n ctf-namespace

# Verify SSH port is open
kubectl port-forward svc/abhimanyu-service 2222:22 -n ctf-namespace
ssh -p 2222 ctf@localhost
```

### Region constraint not met
Verify nodes are in europe-west region:
```bash
kubectl get nodes --show-labels | grep topology.kubernetes.io/region
```

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Google Container Registry](https://cloud.google.com/container-registry)

## Support

For issues or improvements, refer to the Abhimanyu project documentation or Google Cloud support.
