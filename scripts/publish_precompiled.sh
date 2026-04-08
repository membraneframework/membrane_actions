mkdir -p /tmp/artifacts
directory=${WORKSPACE_DIR:-$GITHUB_WORKSPACE/workspace}
for subdir in "$directory"/*; do
  if [ -d "$subdir" ]; then
    subdir_name="$(basename "$subdir")"
    tar -czvf "$subdir_name.tar.gz" -C "$directory" "$subdir_name"
    mv "$subdir_name.tar.gz" /tmp/artifacts
  fi
done
apt update
cd /tmp/ || exit
apt install -y wget
wget https://github.com/tcnksm/ghr/releases/download/v0.16.0/ghr_v0.16.0_linux_amd64.tar.gz
tar -xf ghr_v0.16.0_linux_amd64.tar.gz
./ghr_v0.16.0_linux_amd64/ghr -t ${GITHUB_TOKEN} -u ${GITHUB_REPOSITORY_OWNER} -r ${GITHUB_REPOSITORY#*/} -c ${GITHUB_SHA} -delete ${VERSION} /tmp/artifacts/
