#!/bin/bash

# Update and install docker if not already installed
echo "Installing Docker and docker.io..."
sudo apt update
sudo apt install -y docker docker.io

# Check if the user is part of the docker group
if groups | grep -q "\bdocker\b"; then
    echo "User is already part of the docker group. Skipping group modification."
else
    echo "Adding user to the docker group..."
    sudo usermod -aG docker $USER

    # Change to root and set password for the student user
    echo "Changing to root to set password..."
    sudo -i << 'INNER_EOF'
    passwd student <<PASSWD_END
alta3
alta3
PASSWD_END
    exit
INNER_EOF

    # Reload shell to apply group changes
    echo "Reloading shell to apply group changes..."
    su - $USER
fi

# Verify Docker installation
if docker run hello-world; then
    echo "Docker is running successfully without sudo."
else
    echo "Docker run failed. Re-run the setup script or check the Docker installation."
    exit 1
fi

# Create necessary directories for faucet configuration
echo "Creating /etc/faucet/ directory..."
sudo mkdir -p /etc/faucet/

# Pull and run the faucet container
echo "Pulling the faucet Docker container..."
sudo docker pull faucet/faucet:1.10.11

# Start the faucet container
echo "Starting the faucet container..."
sudo docker run -d --name faucet --restart=always \
    -v /etc/faucet/:/etc/faucet/ \
    -v /var/log/faucet/:/var/log/faucet/ \
    -p 6653:6653 -p 9302:9302 faucet/faucet || \
    echo "Faucet container might already be running."

echo "Setup complete. Exiting."
