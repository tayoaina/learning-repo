#!/bin/bash

# Update the package index
sudo yum update -y

# Download the Jenkins repository configuration file and place it in the appropriate directory
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import the Jenkins repository GPG key to ensure package integrity
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Upgrade all installed packages to their latest versions
sudo yum upgrade

# Install Java OpenJDK 11
sudo amazon-linux-extras install java-openjdk11 -y

# Install Jenkins from the repository
sudo yum install jenkins -y

# Enable the Jenkins service to start automatically at boot
sudo systemctl enable jenkins

# Start the Jenkins service
sudo systemctl start jenkins
