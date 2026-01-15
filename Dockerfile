# Multi-stage Dockerfile for Abhimanyu CTF Machine
# Base image with Linux and necessary tools
FROM ubuntu:22.04 as builder

LABEL maintainer="abhimanyu-ctf"
LABEL description="Abhimanyu CTF Machine Container"

# Set non-interactive mode for apt
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

# Final stage
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
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
RUN mkdir -p /home/ctf/challenges /opt/ctf /var/log/ctf

# Copy challenge files (if any)
# COPY challenges/ /home/ctf/challenges/
# COPY config/ /opt/ctf/

# Set permissions
RUN chown -R ctf:ctf /home/ctf /opt/ctf /var/log/ctf && \
    chmod 755 /home/ctf /opt/ctf /var/log/ctf

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Expose common CTF ports
EXPOSE 22 80 443 8080 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost 22 || exit 1

# Default command
CMD ["/usr/sbin/sshd", "-D"]
