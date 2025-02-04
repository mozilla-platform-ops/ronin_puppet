#!/bin/bash

set -euo pipefail

# Ensnsure Xcode license is accepted
sudo xcodebuild -license accept

# Determine the currently logged-in user (excluding root)
CURRENT_USER=$(stat -f%Su /dev/console)

if [[ "$CURRENT_USER" == "root" || -z "$CURRENT_USER" ]]; then
    echo "No non-root user is currently logged in. Exiting."
    exit 1
fi

echo "Detected logged-in user: $CURRENT_USER"

# Get the user's home directory
USER_HOME=$(eval echo "~$CURRENT_USER")
DOWNLOADS_DIR="$USER_HOME/Downloads"

# Ensure the Downloads directory exists
if [[ ! -d "$DOWNLOADS_DIR" ]]; then
    echo "Creating Downloads directory for $CURRENT_USER"
    mkdir -p "$DOWNLOADS_DIR"
    chown "$CURRENT_USER" "$DOWNLOADS_DIR"
fi

# Change to the user's Downloads directory
cd "$DOWNLOADS_DIR"

######
# Install OpenSSL 3.4.0
######

OPENSSL_URL="https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/14/openssl-3.4.0.tar.gz"

echo "Downloading OpenSSL 3.4.0..."
sudo -u "$CURRENT_USER" curl -O "$OPENSSL_URL"

echo "Extracting OpenSSL 3.4.0..."
sudo -u "$CURRENT_USER" tar -xzf openssl-3.4.0.tar.gz

cd openssl-3.4.0

# Set compiler environment variables for ARM64
export CC="clang"
export CFLAGS="-arch arm64"
export LDFLAGS="-arch arm64"

# Configure, make, and install OpenSSL
echo "Building OpenSSL..."
sudo -u "$CURRENT_USER" ./Configure darwin64-arm64-cc
sudo -u "$CURRENT_USER" make

echo "Installing OpenSSL..."
sudo make install

echo "OpenSSL installation complete."

# Verify OpenSSL Installation
if [[ ! -f "/usr/local/bin/openssl" ]]; then
    echo "Error: OpenSSL binary not found in /usr/local/bin!"
    exit 1
fi

OPENSSL_VERSION=$(/usr/local/bin/openssl version)
echo "Installed OpenSSL version: $OPENSSL_VERSION"

######
# Install Duo Unix 2.0.4
######

DUO_UNIX_URL="https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/14/duo_unix-2.0.4.tar.gz"

cd "$DOWNLOADS_DIR"

echo "Downloading Duo Unix 2.0.4..."
sudo -u "$CURRENT_USER" curl -O "$DUO_UNIX_URL"

echo "Extracting Duo Unix 2.0.4..."
sudo -u "$CURRENT_USER" tar -xzf duo_unix-2.0.4.tar.gz

cd duo_unix-2.0.4

echo "Configuring Duo Unix with OpenSSL and PAM..."
sudo -u "$CURRENT_USER" ./configure --with-openssl=/usr/local --with-pam=/usr/local/lib/pam

echo "Building Duo Unix..."
sudo -u "$CURRENT_USER" make

echo "Installing Duo Unix..."
sudo make install

echo "Duo Unix installation complete."
