#!/bin/bash

# Detect OS and install fzf
if [[ -f /etc/debian_version ]]; then
    echo "Detected Debian/Ubuntu"
    sudo apt update && sudo apt install -y fzf
elif [[ -f /etc/redhat-release ]]; then
    echo "Detected RHEL/CentOS"
    sudo yum install -y fzf
elif [[ "$(uname)" == "Darwin" ]]; then
    echo "Detected macOS"
    brew install fzf
else
    echo "Unsupported OS"
    exit 1
fi

# Configure Ctrl+R to use fzf
echo 'export FZF_DEFAULT_COMMAND="history -r"' >> ~/.bashrc
echo 'bind -x "\"\C-r\": \"history | fzf | xargs -I {} echo {} && {}\""' >> ~/.bashrc

# Apply changes
source ~/.bashrc

echo "fzf installed and Ctrl+R configured for enhanced history search!"
