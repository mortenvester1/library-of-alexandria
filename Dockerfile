FROM ubuntu:latest

# Update package list and install zsh
RUN apt-get update && \
    apt-get install -y sudo zsh curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create ubuntu user (use different UID if 1000 is taken, or skip if user exists)
RUN useradd -m -u 1001 -s /bin/bash ubuntu || \
    (id ubuntu && echo "User ubuntu already exists") || \
    useradd -m -s /bin/bash ubuntu

# Set password for ubuntu user (password is 'ubuntu')
RUN echo 'ubuntu:ubuntu' | chpasswd

# Add ubuntu user to sudo group and configure passwordless sudo
RUN usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set environment variables for the ubuntu user
ENV USER=ubuntu
ENV HOME=/home/ubuntu
