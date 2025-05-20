#!/bin/bash

get_latest_release() {
  repo="$1"
  version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | \
    grep '"tag_name":' | \
    sed -E 's/.*"([^"]+)".*/\1/')
  echo "$version"
}

heimdall_repo="maticnetwork/heimdall"
bor_repo="maticnetwork/bor"

heimdall_version=$(get_latest_release "$heimdall_repo")
bor_version=$(get_latest_release "$bor_repo")

echo "Latest Heimdall version: $heimdall_version"
echo "Latest Bor version: $bor_version"
systemctl stop heimdalld.service
systemctl stop bor.service

curl -L https://raw.githubusercontent.com/maticnetwork/install/main/heimdall.sh | bash -s -- $heimdall_version mainnet sentry

curl -L https://raw.githubusercontent.com/maticnetwork/install/main/bor.sh | bash -s -- $bor_version mainnet sentry

systemctl start heimdalld.service

while true; do
catching_up=$(curl -s localhost:26657/status | jq -r '.result.sync_info.catching_up')
if [ "$catching_up" == "false" ]; then
break
fi
sleep 10
done


sudo systemctl start bor.service
