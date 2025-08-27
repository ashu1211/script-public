#!/bin/bash

# Script URL
SCRIPT_URL="https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh"

# Read all non-comment Host entries
HOSTS=$(grep -i "^Host " ~/.ssh/config | awk '{print $2}' | grep -v '\*' | grep -v '^#')

# Arrays to track results
SUCCESS_HOSTS=()
FAILED_HOSTS=()

for host in $HOSTS; do
    echo "========== Running script on $host =========="
    ssh "$host" "bash -s" < <(curl -fsSL $SCRIPT_URL)
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        echo "✅ Success on $host"
        SUCCESS_HOSTS+=("$host")
    else
        echo "❌ Failed on $host (exit code $STATUS)"
        FAILED_HOSTS+=("$host")
    fi
    echo "============================================="
    echo
done

# Print summary
echo "==================== SUMMARY ===================="
if [ ${#SUCCESS_HOSTS[@]} -gt 0 ]; then
    echo "✅ Successfully executed on:"
    for h in "${SUCCESS_HOSTS[@]}"; do
        echo "   - $h"
    done
else
    echo "⚠️ No successful hosts."
fi

echo

if [ ${#FAILED_HOSTS[@]} -gt 0 ]; then
    echo "❌ Failed on:"
    for h in "${FAILED_HOSTS[@]}"; do
        echo "   - $h"
    done
else
    echo "🎉 No failures."
fi
echo "================================================="



# #!/bin/bash

# # Script URL
# SCRIPT_URL="https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh"

# # Read all non-comment Host entries
# HOSTS=$(grep -i "^Host " ~/.ssh/config | awk '{print $2}' | grep -v '\*' | grep -v '^#')

# for host in $HOSTS; do
#     echo "========== Running script on $host =========="
#     ssh "$host" "bash -s" < <(curl -fsSL $SCRIPT_URL)
#     STATUS=$?
#     if [ $STATUS -eq 0 ]; then
#         echo "✅ Success on $host"
#     else
#         echo "❌ Failed on $host (exit code $STATUS)"
#     fi
#     echo "============================================="
#     echo
# done
