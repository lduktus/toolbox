#!/usr/bin/env bash

set -euxo pipefail

_folder_permissions() {
  mkdir -pv "$1" # ensure folder is present, just for safety
  chown -R 1000:1000 "$1"
  chmod -R g+rwx "$1"
}

bin_dir="/opt/bin"
pipx_root="/opt/pipx"
cache_dir="/var/cache"

export PIPX_HOME="${pipx_root}/venvs"
export PIPX_BIN_DIR="$bin_dir"
export USE_EMOJI="false"
export NPM_CONFIG_PREFIX="/opt"
export NPM_CONFIG_CACHE="${cache_dir}/npm"

# give access to host installed packages
chmod +x /build/host-runner
mv /build/host-runner /usr/bin
ln -sv /usr/bin/host-runner /usr/local/bin/podman
ln -sv /usr/bin/host-runner /usr/local/bin/podman-compose

# set fastest mirrors & add non-free repos
dnf config-manager --setopt fastestmirror=1 --set-enabled --save
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# add vscode repo
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" >/etc/yum.repos.d/vscode.repo

# finally update everything
dnf -y update

# install basic packages
dnf -y install \
  code \
  file \
  flatpak-xdg-utils \
  glibc-all-langpacks \
  make \
  nodejs \
  nodejs-npm \
  pipx \
  python3 \
  python3-pip \
  shfmt \
  wl-clipboard \
  zoxide

dnf clean all

# add pipx support
{
  echo "export PIPX_HOME=${PIPX_HOME}"
  echo "export PIPX_BIN_DIR=${PIPX_BIN_DIR}"
  echo "export USE_EMOJI=false"
} >>/etc/profile.d/~00-pipx.sh

npm config set cache "$NPM_CONFIG_CACHE" --global
npm install -g @devcontainers/cli
{
  echo "export NPM_CONFIG_PREFIX=${NPM_CONFIG_PREFIX}"
  echo "alias npm='npm -g'"
  echo "alias npmi='npm -g install'"
  echo "alias npmu='npm -g uninstall'"
} >>/etc/profile.d/~00-npm.sh

# folder permissions
_folder_permissions "/opt"
_folder_permissions "$bin_dir"
_folder_permissions "$NPM_CONFIG_CACHE"

# use flatpak-xdg-open as alias for xdg-open
ln -sv /usr/bin/flatpak-xdg-open ${bin_dir}/xdg-open

# set path
echo "export PATH=${bin_dir}:\${PATH}" >/etc/profile.d/~00-path.sh
