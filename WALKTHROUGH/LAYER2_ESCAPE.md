# Layer 2: Container Escape & Privilege Escalation

## Objective
Escape the container and gain root access on the host.

## Prerequisites
- Complete Layer 1 (LFI challenge)
- Read container configuration files
- Identify mount points and capabilities

## Exploitation Techniques

### 1. Discover Docker Socket (if mounted)
Using the LFI vulnerability, try reading:
```
/var/run/docker.sock
```

If accessible, you can:
- Create privileged containers
- Access the host filesystem
- Execute commands as root

### 2. Exploit Insecure Mounts
Check for mounted volumes that expose:
- Host filesystem (`/`)
- Privileged directories (`/root`, `/etc`)
- Source code with credentials

### 3. Privilege Escalation Inside Container
Techniques to try:
```bash
# Check for SUID binaries
find / -perm -4000 2>/dev/null

# Check capabilities
getcap -r / 2>/dev/null

# Look for cron jobs
cat /etc/crontab

# Check sudoers without password
sudo -l
```

## Flag 2
`CTF{CONTAINER_ESCAPE_SUCCESSFUL}`

