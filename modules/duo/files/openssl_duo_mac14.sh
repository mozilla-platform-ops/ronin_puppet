#!/bin/bash

set -euo pipefail


sudo xcodebuild -license accept

echo "Installing Duo as root"

DOWNLOADS_DIR="/tmp/duo"

# Ensure the Downloads directory exists
if [[ ! -d "$DOWNLOADS_DIR" ]]; then
    echo "Creating Downloads directory"
    mkdir -p "$DOWNLOADS_DIR"
    sudo chown root:wheel "$DOWNLOADS_DIR"
fi

# Change to the Downloads directory
cd "$DOWNLOADS_DIR"

######
# Install OpenSSL 3.4.0
######

OPENSSL_URL="https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/14/openssl-3.4.0.tar.gz"

echo "Downloading OpenSSL 3.4.0..."
sudo curl -O "$OPENSSL_URL"

echo "Extracting OpenSSL 3.4.0..."
sudo tar -xzf openssl-3.4.0.tar.gz

cd openssl-3.4.0

# Configure, make, and install OpenSSL
echo "Building OpenSSL..."
sudo CC="clang" CFLAGS="-arch arm64" LDFLAGS="-arch arm64" ./Configure darwin64-arm64-cc
sudo make -j"$(sysctl -n hw.ncpu)"

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
# Install Duo Unix 2.2.3
######

DUO_UNIX_URL="https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/14/duo_unix-2.2.3.tar.gz"

cd "$DOWNLOADS_DIR"

echo "Downloading Duo Unix 2.2.3..."
sudo curl -O "$DUO_UNIX_URL"

echo "Extracting Duo Unix 2.2.3..."
sudo tar -xzf duo_unix-2.2.3.tar.gz

cd duo_unix-2.2.3

echo "Configuring Duo Unix with OpenSSL and PAM..."
sudo ./configure --with-openssl=/usr/local --with-pam=/usr/local/lib/pam

echo "Building Duo Unix..."
sudo make

echo "Installing Duo Unix..."
sudo make install

echo "Duo Unix installation complete."
