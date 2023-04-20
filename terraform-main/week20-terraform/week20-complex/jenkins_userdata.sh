#!/bin/bash

# Update the package index
sudo yum update -y

# Download the Jenkins repository configuration file and place it in the appropriate directory
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import the Jenkins repository GPG key 
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Upgrade all installed packages to their latest versions
sudo yum upgrade -y

# Install Java OpenJDK 11
sudo amazon-linux-extras install java-openjdk11 -y

# Echo the start of Jenkins installation
echo "Starting Jenkins installation..."

# Install Jenkins from the repository
sudo yum install jenkins -y

# Echo the successful completion of Jenkins installation
echo "Jenkins installation successful!"

# Enable Jenkins to start automatically at boot
sudo systemctl enable jenkins

# Reload the systemd manager configuration
sudo systemctl daemon-reload

# Start Jenkins 
sudo systemctl start jenkins
