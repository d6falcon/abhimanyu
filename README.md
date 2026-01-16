# abhimanyu - Chakravyuha CTF 🎯 

This is a **container-based Capture the Flag (CTF)** challenge based on the Mahabharata's Chakravyuha formation.
![alt text](https://github.com/d6falcon/abhimanyu/blob/main/CHAKRAVYUHA_DIAGRAM.png?raw=true)

## Challenge Theme

**Abhimanyu** is a prominent character in the Hindu epic, Mahabharata. He is famously remembered for his bravery and skills, but unfortunately met an untimely death due to a treacherous attack - the **Chakravyuha**.

**The Chakravyuha** (Wheel or discus formation):
- "Chakra" means "spinning wheel"
- "Vyuha" means "formation"
- Hence, Chakravyuha means a puzzled arrangement of soldiers rotating in a spinning wheel formation
- The rotation is similar to the helix of a screw, commonly seen in watches

### Analogy to CTF
Just as Abhimanyu had to navigate through concentric rings of warriors to escape the Chakravyuha, players must break through **4 concentric layers of security** to reach the flag at the core.

##  Challenge Structure

```
        ┌──────────────────────────────┐
        │      CORE: Final Flag        │
        │  (Kubernetes Secrets/RBAC)   │
        ├──────────────────────────────┤
        │   LAYER 3: Inner Ring        │
        │  (Kubernetes RBAC Exploit)   │
        ├──────────────────────────────┤
        │  LAYER 2: Middle Ring        │
        │  (Container Escape & Privesc)│
        ├──────────────────────────────┤
        │   LAYER 1: Outer Ring        │
        │  (Web App - LFI Vuln)        │
        └──────────────────────────────┘
```

##  Layers Overview

### Layer 1 - Outer Ring: Web Application Vulnerability
**Vulnerability:** Local File Inclusion (LFI) via path traversal
- **Type:** CWE-22 (Improper Limitation of a Pathname)
- **Severity:** HIGH
- **Description:** The Flask web application has a file-serving endpoint vulnerable to directory traversal attacks
- **Exploitation:** Use `../` sequences to read arbitrary system files
- **Flag:** `CTF{LFI_PATH_TRAVERSAL_DISCOVERED}` (Discovered via /view endpoint exploitation)

### Layer 2 - Middle Ring: Container Escape & Privilege Escalation
**Vulnerability:** Insecure container configuration
- **Type:** Container security misconfiguration
- **Severity:** CRITICAL
- **Description:** Container has exposed docker socket, unnecessary capabilities, or mounted sensitive volumes
- **Exploitation:** Escape container and gain root access on host
- **Flag:** `CTF{ESCAPED_DOCKER_CONTAINER_LAYER2}`

### Layer 3 - Inner Ring: Database Breach & Kubernetes RBAC Exploitation
**Vulnerability:** Unprotected database + Overpermissive RBAC configuration
- **Type:** Database exposure + RBAC misconfiguration
- **Severity:** CRITICAL
- **Description:** Redis and PostgreSQL are exposed within the cluster without proper authentication. Service account has excessive permissions (pods/exec, secrets/get, etc.)
- **Exploitation:** Access Redis and PostgreSQL from within container, then use service account token to access cluster APIs and read secrets
- **Flag:** `CTF{BREACHED_REDIS_AND_DATABASE_LAYER3}`

### Layer 4 - Core: Secret Exfiltration
**Vulnerability:** Sensitive data in ConfigMaps and hardcoded secrets
- **Type:** Information disclosure + Secrets management
- **Severity:** CRITICAL
- **Description:** Final flag and sensitive credentials stored in Kubernetes ConfigMaps and Secrets
- **Exploitation:** Access via Kubernetes API and service account token after RBAC exploitation
- **Flag:** `CTF{COMPROMISED_KUBERNETES_CLUSTER_LAYER4}`

##  Quick Start

### Local Testing with Docker

**Single Container Mode:**
```bash
./docker-run-local.sh
```
Access at `http://localhost:5000`
SSH at `ssh -p 2222 ctf@localhost` (password: `ctf123`)

**Multi-Container Mode (Recommended):**
```bash
./docker-run-local.sh latest compose
```
Starts: Flask app (port 5000), Redis (port 6379), PostgreSQL (port 5432)

### GKE Deployment

```bash
export GCP_PROJECT_ID=your-gcp-project
export GKE_CLUSTER_NAME=abhimanyu-ctf-cluster
export GKE_REGION=europe-west2 #London

./deploy-to-gke.sh
```

##  Project Structure

```
abhimanyu/
├── app/                         # Flask web application
│   ├── app.py                   # Main vulnerable application
│   ├── requirements.txt         # Python dependencies
│   ├── templates/               # HTML templates
│   │   ├── index.html           # Home page
│   │   ├── documents.html       # Document listing
│   │   ├── error.html           # Error page
│   │   ├── source.html          # Source code viewer
│   │   └── upload.html          # File upload
│   ├── static/                  # Static files
│   ├── documents/               # Document storage (exploitable)
│   └── uploads/                 # Upload directory
│
├── walkthrough/                # SPOILERS! - CTF challenge walkthrough documentation
│   ├── WALKTHROUGH.md          # Complete exploitation walkthrough
│   ├── LAYER1_LFI.md           # Layer 1 challenge guide
│   ├── LAYER2_ESCAPE.md        # Layer 2 challenge guide
│   ├── LAYER3_KUBERNETES.md    # Layer 3 challenge guide
│   └── LAYER4_CORE.md          # Layer 4 challenge guide
│
├── Dockerfile                  # Multi-stage container build
├── docker-compose.yml          # Multi-service local testing
├── docker-run-local.sh         # Local deployment script
├── deploy-to-gke.sh           # GKE deployment script
├── k8s-deployment.yaml        # Kubernetes manifests
├── BLOCK_DIAGRAM.png          # Functional Diagram explaining the logic (may not be accurate on labels as the attack path dev evolves)
├── ATTACK_FLOW.png            # Explains Attack Chain
├── README.md                  # Originally an excalidraw file but converted to png
├── CHAKRAVYUHA_DIAGRAM.png    # Overview diagram
├── README.md                  # This file
└── .dockerignore              # Docker build exclusions
```

##  Vulnerability Details

### Layer 1: Local File Inclusion (LFI)
The `/view` endpoint is vulnerable because:
1. Insufficient input validation (only checks character set)
2. No blocking of path traversal sequences (`../`)
3. Path canonicalization check happens too late
4. String-based path comparison instead of real path resolution

**Exploit Example:**
```bash
# Read /etc/passwd
curl http://localhost:5000/view?file=../../../../etc/passwd

# Read environment variables
curl http://localhost:5000/view?file=../../../../proc/self/environ
```

### Layer 2: Container Misconfiguration
- Docker socket mounted (if applicable)
- Running with unnecessary capabilities
- Sensitive volumes mounted
- No read-only root filesystem

### Layer 3: Kubernetes RBAC
- Service account with `pods/exec` permission
- `secrets/get` and `secrets/list` allowed
- `configmaps/get` and `configmaps/list` allowed
- No namespace restrictions

##  Documentation

- **[WALKTHROUGH/](walkthrough/)** - Layer-by-layer challenge descriptions and a whole spoiler Walkthrough
- **[GKE-DEPLOYMENT.md](GKE-DEPLOYMENT.md)** - Production deployment guide
- **App Source:** [app/app.py](app/app.py)

##  Security Learning Objectives

Players will learn about:
- Local File Inclusion (LFI) exploitation
- Path traversal attacks
- Container escape techniques
- Privilege escalation methods
- Kubernetes RBAC exploitation
- Secret management best practices
- Defense-in-depth strategies

##  Remediation & Best Practices

See [WALKTHROUGH.md](WALKTHROUGH/WALKTHROUGH.md#defense--remediation) for security recommendations.

##  Completion Indicators

You've successfully completed Chakravyuha when you can demonstrate:
1. **Layer 1:** Read `/etc/passwd` via LFI
2. **Layer 2:** Gain root access on the host system
3. **Layer 3:** List Kubernetes secrets using service account token
4. **Layer 4:** Retrieve the final flag from restricted namespace

## ATTACK Flow
![alt text](https://github.com/d6falcon/abhimanyu/blob/main/ATTACK_FLOW.png?raw=true)
## Architecture Block Diagram
![alt text](https://github.com/d6falcon/abhimanyu/blob/main/BLOCK_DIAGRAM.png?raw=true)

##  License

This CTF challenge is created for educational and training purposes which is another reason why most passwords are plain text. Contributions via PR are most welcome

## Music that helped me put up with this all night

Waterfalls [James Hype feat. Sam Harper & Bobby Harris]
Sonder [Barry Can't Swim]
First Light [Lawrence Hart]
Electric Feel [MGMT]
Shotgun [George Ezra]
Do I Wanna Know? [Arctic Monkeys]
Pumped Up Kicks [Foster The People]
Sahiba [Aditya Rikhari]

##  References

- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Container Security Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Container_Security_Cheat_Sheet.html)

