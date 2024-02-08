#!/bin/bash

REPO_SIGNING_KEY="https://packages.mozilla.org/apt/repo-signing-key.gpg"
REPO_SIGNING_KEY_LOCATION="/etc/apt/keyrings/packages.mozilla.org.asc"

echo "Root permission is required to create new APT repository"

while true; do
    read -p "Do you want to continue? (y|N)" answer
    case $answer in
        [Yy]*)
            break ;;
        [Nn]*)
	    exit ;;
	*)
            continue ;;
    esac
done

sudo true

# Create a directory to store APT repository keys if it doesn't exist
if [ ! -d /etc/apt/keyrings ]; then
    sudo install -d -m 0755 /etc/apt/keyrings
fi

# Import the Mozilla APT repository signing key
if which curl > /dev/null; then
    curl -L "$REPO_SIGNING_KEY" | sudo tee "$REPO_SIGNING_KEY_LOCATION" > /dev/null
elif which wget > /dev/null; then
    wget -q -O - "$REPO_SIGNING_KEY" | sudo tee "$REPO_SIGNING_KEY_LOCATION" > /dev/null
else
    echo "You need to install curl or wget first."
    echo "Run: apt-get install curl"
    exit 1
fi

# The fingerprint should be 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
LOCAL_FINGERPRINT=gpg -n -q --import --import-options import-show "$REPO_SIGNING_KEY_LOCATION" | awk '/pub/{getline; gsub(/^ +| +$/,""); print $1}'

if $LOCAL_FINGERPRINT == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"; then
    print "\nThe key finterprint match ("$0").\n"
else
    print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"
    exit 1
fi

# Add the Mozilla APT repository to your sources list
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

# Configure APT to prioritize packages from Mozilla repository
echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 900" | sudo tee /etc/apt/preferences.d/mozilla > /dev/null

echo "Successfully created Mozilla APT repository."
echo "Run: apt-get update"
