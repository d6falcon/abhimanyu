# Multi-stage Dockerfile for Abhimanyu CTF Machine - Chakravyuha Challenge
# Layer-based CTF with LFI vulnerability in web application

FROM ubuntu:22.04 as builder

LABEL maintainer="abhimanyu-ctf"
LABEL description="Abhimanyu CTF Machine - Chakravyuha (Wheel Formation)"

ENV DEBIAN_FRONTEND=noninteractive

# Update and install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    git \
    openssh-server \
    openssh-client \
    python3 \
    python3-pip \
    netcat \
    socat \
    xinetd \
    && rm -rf /var/lib/apt/lists/*

# Chakravyuha Web App Stage
FROM ubuntu:22.04 as chakravyuha-app

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies including docker CLI for Layer 2 exploitation
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    curl \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy application code
COPY app/app.py .
COPY app/requirements.txt .
COPY app/templates/ templates/
COPY app/static/ static/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create directories for documents and uploads
RUN mkdir -p documents uploads challenges && \
    chmod 755 documents uploads challenges

# Expose Flask port
EXPOSE 5000 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Start Flask app
CMD ["python3", "app.py"]

# Final Combined Stage - Pull ubuntu image and setup all dependencies
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install all dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    openssh-client \
    python3 \
    python3-pip \
    netcat \
    socat \
    xinetd \
    curl \
    iputils-ping \
    net-tools \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd

# Create non-root user for CTF challenges
RUN useradd -m -s /bin/bash ctf && \
    echo "ctf:ctf123" | chpasswd && \
    usermod -aG sudo ctf

# Create directories for CTF challenges
RUN mkdir -p /home/ctf/challenges /opt/ctf /var/log/ctf /app

# Set permissions
RUN chown -R ctf:ctf /home/ctf /opt/ctf /var/log/ctf && \
    chmod 755 /home/ctf /opt/ctf /var/log/ctf

# Copy Flask app from app stage
COPY --from=chakravyuha-app /app /app
COPY --chown=ctf:ctf challenges/ /home/ctf/challenges/

WORKDIR /app

# Install Python dependencies for Flask
RUN pip install --no-cache-dir -r requirements.txt

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create startup script that runs both SSH and Flask
RUN echo '#!/bin/bash\n\
# Start Flask app in background\n\
python3 /app/app.py &\n\
# Start SSH server\n\
/usr/sbin/sshd -D\n\
' > /start.sh && chmod +x /start.sh

# Expose common CTF ports
EXPOSE 22 80 443 5000 8080 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Default command
CMD ["/start.sh"]
