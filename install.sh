#!/bin/bash

set -e

ERROR_COLOR="\033[31m"
WARNING_COLOR="\033[33m"
RESET_COLOR="\033[0m"

REPO_SIGNING_KEY="https://packages.mozilla.org/apt/repo-signing-key.gpg"
REPO_SIGNING_KEY_LOCATION="/etc/apt/keyrings/packages.mozilla.org.asc"

prompt_user() {
    echo "Root permission is required to create new APT repository"
    read -p "Do you want to continue? (y|N) " answer
    case ${answer:0:1} in
        [Yy]) return 0 ;;
        *) return 1 ;;
    esac
}

# Check is a given command exists
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Install the packages if command not exist.
# First argument is command and second argument is package.
install_package() {
    if ! command_exists "$1"; then
        echo "Command '$1' not found, but can be install with:"
        echo "apt-get install $2"
        exit 1
    fi
}

# Import the Mozilla APT repository signing key
import_signing_key() {
    # Create a directory to store APT repository keys
    [ ! -d /etc/apt/keyrings ] && sudo install -d -m 0755 /etc/apt/keyrings

    local downloader=""

    if command_exists curl; then
        downloader="curl -sL"
    elif command_exists wget; then
        downloader="wget -q -O-"
    else
        echo "${ERROR_COLOR}Error: Neither curl nor wget found. Please install one of them first.${RESET_COLOR}"
        exit 1
    fi
    $downloader "$REPO_SIGNING_KEY" | sudo tee "$REPO_SIGNING_KEY_LOCATION" > /dev/null
}

verify_fingerprint() {
    local EXPECTED_FINGERPRINT="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
    local LOCAL_FINGERPRINT=$(gpg -n -q --import --import-options import-show "$REPO_SIGNING_KEY_LOCATION" | awk '/pub/{getline; gsub(/^ +| +$/,""); print $1}')

    if [ "$LOCAL_FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]; then
        echo -e "${ERROR_COLOR}Error: Verification failed: the fingerprint mismatch.${RESET_COLOR}"
        exit 1
    fi
}

add_and_configure_apt_repo() {
    # Add the Mozilla APT repository to your sources list
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

    # Configure APT to prioritize packages from Mozilla APT repository
    echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 900" | sudo tee /etc/apt/preferences.d/mozilla > /dev/null
}

if ! prompt_user; then
    exit 0;
fi

install_package sudo sudo
install_package gpg gnupg
sudo true

import_signing_key
verify_fingerprint
add_and_configure_apt_repo

echo "Successfully created Mozilla APT repository."
echo "Run: apt-get update"
