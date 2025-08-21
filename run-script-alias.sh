#!/bin/bash

# Script URL
SCRIPT_URL="https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh"

# Read all non-comment Host entries
HOSTS=$(grep -i "^Host " ~/.ssh/config | awk '{print $2}' | grep -v '\*' | grep -v '^#')

for host in $HOSTS; do
    echo "========== Running script on $host =========="
    ssh "$host" "bash -s" < <(curl -fsSL $SCRIPT_URL)
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        echo "✅ Success on $host"
    else
        echo "❌ Failed on $host (exit code $STATUS)"
    fi
    echo "============================================="
    echo
done

