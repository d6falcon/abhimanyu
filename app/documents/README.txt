Welcome to the Chakravyuha Challenge!

This is Layer 1 - The Outer Ring

Your mission: Exploit the Local File Inclusion vulnerability to escape the application
sandbox and read system files.

Hints:
1. Look at the /view endpoint
2. Try using path traversal sequences
3. The /documents directory is a red herring
4. Can you read files outside of it?

Example attack vector:
/view?file=../../../../etc/passwd

Good luck!
