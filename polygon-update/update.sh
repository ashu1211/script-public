get_latest_release() {
  repo="$1"
  version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | \
    grep '"tag_name":' | \
    sed -E 's/.*"([^"]+)".*/\1/')
  echo "$version"
}