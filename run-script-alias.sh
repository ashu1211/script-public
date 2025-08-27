#!/bin/bash
sudo. DEBIAN_FRONTEND=noninteractive apt install sshpass -y
# Script URL
SCRIPT_URL="https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh"

# Read all non-comment Host entries
HOSTS=$(grep -i "^Host " ~/.ssh/config | awk '{print $2}' | grep -v '\*' | grep -v '^#')

# Arrays to store results
SUCCESS=()
FAILED=()

for host in $HOSTS; do
    echo "========== Running script on $host =========="
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" "bash -s" < <(curl -fsSL $SCRIPT_URL); then
        echo "✅ Success on $host"
        SUCCESS+=("$host")
    else
        echo "❌ Failed on $host"
        FAILED+=("$host")
    fi
    echo "============================================="
    echo
done

# Final Summary
echo "============================================="
echo "📝 Installation Summary"
echo "============================================="

if [ ${#SUCCESS[@]} -gt 0 ]; then
    echo "✅ Success on servers:"
    for s in "${SUCCESS[@]}"; do
        echo "   - $s"
    done
    echo
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "❌ Failed on servers:"
    for f in "${FAILED[@]}"; do
        echo "   - $f"
    done
    echo
fi

