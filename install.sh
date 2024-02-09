#!/bin/bash

set -e

REPO_SIGNING_KEY="https://packages.mozilla.org/apt/repo-signing-key.gpg"
REPO_SIGNING_KEY_LOCATION="/etc/apt/keyrings/packages.mozilla.org.asc"

prompt_user() {
    while true; do
        echo "Root permission is required to create new APT repository"
        read -p "Do you want to continue? (y|N) " answer
        case $answer in
            [Yy]*) break ;;
            [Nn]*) exit ;;
            *) exit;;
        esac
    done
}

# Check is a given command exists
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Install the packages if command not exist.
# First argument is command and second argument is package.
install_package() {
    if ! command_exists "$1"; then
        echo "Command '$1' not found, but can be instal with:"
        echo "apt-get install $2"
        exit 1
    fi
}

# Import the Mozilla APT repository signing key
import_signing_key() {
    # Create a directory to store APT repository keys
    [ ! -d /etc/apt/keyrings ] && sudo install -d -m 0755 /etc/apt/keyrings

    if command_exists curl; then
        curl -sL "$REPO_SIGNING_KEY" | sudo tee "$REPO_SIGNING_KEY_LOCATION" > /dev/null
    elif command_exists wget; then
        wget -q -O - "$REPO_SIGNING_KEY" | sudo tee "$REPO_SIGNING_KEY_LOCATION" > /dev/null
    else
        echo "You need to install curl or wget first."
        echo "Run: apt-get install curl"
        exit 1
    fi
}

# The fingerprint should be 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
verify_fingerprint() {
    LOCAL_FINGERPRINT=$(gpg -n -q --import --import-options import-show "$REPO_SIGNING_KEY_LOCATION" | awk '/pub/{getline; gsub(/^ +| +$/,""); print $1}')

    if [ $LOCAL_FINGERPRINT == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3" ]; then
        echo -e "\nThe key finterprint match (\"$LOCAL_FINGERPRINT\").\n"
    else
        echo -e "\nVerification failed: the fingerprint (\"$LOCAL_FINGERPRINT\") does not match the expected one.\n"
        exit 1
    fi
}

add_and_configure_apt_repo() {
    # Add the Mozilla APT repository to your sources list
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

    # Configure APT to prioritize packages from Mozilla APT repository
    echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 900" | sudo tee /etc/apt/preferences.d/mozilla > /dev/null
}

prompt_user
install_package sudo sudo
install_package gpg gnupg
sudo true

import_signing_key
verify_fingerprint
add_and_configure_apt_repo

echo "Successfully created Mozilla APT repository."
echo "Run: apt-get update"
