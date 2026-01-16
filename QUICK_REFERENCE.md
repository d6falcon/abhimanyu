# Chakravyuha CTF - Quick Reference Guide

## Start CTF

```bash
# Single container (simple)
./docker-run-local.sh

# Multi-container (recommended)
./docker-run-local.sh latest compose

# Validate setup
./validate-setup.sh
```

## Access Points

| Service | URL/Port | Credentials |
|---------|----------|-------------|
| Flask Web App | http://localhost:5000 | - |
| SSH | ssh -p 2222 ctf@localhost | ctf/ctf123 |
| Health Check | http://localhost:5000/health | - |
| Source Code | http://localhost:5000/source | - |
| Redis (compose) | localhost:6379 | ctf_redis_pass_123 |
| PostgreSQL (compose) | localhost:5432 | ctf_user/ctf_db_pass_456 |

## Documentation

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Overview & structure |
| [EXPLOITATION_GUIDE.md](EXPLOITATION_GUIDE.md) | Full exploitation walkthrough |
| [challenges/LAYER1_LFI.md](challenges/LAYER1_LFI.md) | Layer 1 details |
| [challenges/LAYER2_ESCAPE.md](challenges/LAYER2_ESCAPE.md) | Layer 2 details |
| [challenges/LAYER3_KUBERNETES.md](challenges/LAYER3_KUBERNETES.md) | Layer 3 details |
| [challenges/LAYER4_CORE.md](challenges/LAYER4_CORE.md) | Layer 4 details |
| [GKE-DEPLOYMENT.md](GKE-DEPLOYMENT.md) | Production deployment |


## Testing Checklist

- [ ] Docker image builds successfully
- [ ] Container starts and responds to HTTP
- [ ] Flask app serves home page
- [ ] LFI vulnerability is exploitable
- [ ] Source code viewer works
- [ ] Health check endpoint responds
- [ ] Docker Compose multi-container setup works

## Vulnerability Summary

| Layer | Type | CWE | Severity | Fixable |
|-------|------|-----|----------|---------|
| 1 | Path Traversal | CWE-22 | High | Yes |
| 2 | Insecure Container Config | CWE-250 | Critical | Yes |
| 3 | RBAC Misconfiguration | CWE-269 | Critical | Yes |
| 4 | Exposed Secrets | CWE-798 | High | Yes |

## Learning Outcomes

After completing this CTF, you'll understand:
- Path traversal attack techniques
- Container security best practices
- Kubernetes RBAC configuration
- Secret management in cloud environments
- Defense-in-depth strategies
- Security misconfiguration risks

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [HackTricks](https://book.hacktricks.xyz/)

---
