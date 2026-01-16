# Final Layer: Core - Flag Retrieval

## Objective
Access the restricted ConfigMap/Secret in the `ctf-system` namespace to retrieve the final flag.

## Challenge
You need `secrets/get` and `configmaps/get` permissions in the `ctf-system` namespace to read:
- `final-flag` ConfigMap
- `admin-credentials` Secret
- `exploit-notes` ConfigMap

## The Final Flag

Once you successfully navigate through all three layers:
1. **Layer 1 (Outer Ring):** Exploit LFI to read system files
2. **Layer 2 (Middle Ring):** Escape the container and escalate privileges
3. **Layer 3 (Inner Ring):** Exploit Kubernetes RBAC
4. **Core (Center):** Access the final flag

The final flag is:
```
CTF{CHAKRAVYUHA_FULLY_PENETRATED_YOU_ARE_ABHIMANYU}
```

## Verification Steps

```bash
# From within the compromised cluster
kubectl get configmap final-flag -n ctf-system -o yaml

# Expected output:
# data:
#   flag: CTF{CHAKRAVYUHA_FULLY_PENETRATED_YOU_ARE_ABHIMANYU}
```

## Lessons Learned

### Security Vulnerabilities Exploited:
1. **Improper Input Validation** - Path traversal in file operations
2. **Insufficient Container Hardening** - Exposed docker socket, unnecessary capabilities
3. **RBAC Misconfiguration** - Over-permissive service accounts
4. **Secret Management** - Plaintext credentials in configmaps

### Remediation:
- Use secure input validation libraries
- Implement defense in depth
- Follow principle of least privilege
- Use secrets management solutions (HashiCorp Vault, etc.)
- Enable audit logging and monitoring
