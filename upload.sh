#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

install_cli() {
  if command -v package_cloud >/dev/null 2>&1; then
    return
  fi

  echo "Installing package_cloud gem..."
  gem install --no-document --user-install package_cloud
  local gem_bin
  gem_bin="$(ruby -e 'puts Gem.user_dir')/bin"
  PATH="${gem_bin}:${PATH}"
  export PATH
}

require_env() {
  if [ -z "${REPO:-}" ]; then
    echo "No REPO provided!" >&2
    exit 1
  fi
  if [ -z "${SOURCE:-}" ]; then
    echo "No SOURCE provided!" >&2
    exit 1
  fi
  if [ -z "${PACKAGECLOUD_TOKEN:-}" ]; then
    echo "No PACKAGECLOUD_TOKEN provided!" >&2
    exit 1
  fi
}

upload() {
  local upload_path="$1"
  local package_name="$2"
  echo "Uploading ${package_name} to ${upload_path}."
  package_cloud push "${upload_path}" "${package_name}"
}

upload_file() {
  local repo="$1"
  local package_name="$2"
  local distributions="${3:-}"
  if [ -z "${distributions}" ]; then
    upload "${repo}" "${package_name}"
    return
  fi

  local distrib
  # Space-separated dist list is the documented Action input.
  # shellcheck disable=SC2086
  for distrib in $distributions; do
    upload "${repo}/${distrib}" "${package_name}"
  done
}

upload_folder() {
  local repo="$1"
  local source="$2"
  local deb_dists="${3:-}"
  local rpm_dists="${4:-}"
  local pkg found=0

  for pkg in "${source}"/*.deb; do
    found=1
    upload_file "${repo}" "${pkg}" "${deb_dists}"
  done
  for pkg in "${source}"/*.rpm; do
    found=1
    upload_file "${repo}" "${pkg}" "${rpm_dists}"
  done

  if [ "${found}" -eq 0 ]; then
    echo "No .deb or .rpm files in ${source}" >&2
    exit 1
  fi
}

file_extension() {
  local name="${1##*/}"
  local ext="${name##*.}"
  printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]'
}

upload_single() {
  local repo="$1"
  local source="$2"
  local rpm_dists="${3:-}"
  local deb_dists="${4:-}"
  if [ ! -f "${source}" ]; then
    echo "SOURCE is not a file or directory: ${source}" >&2
    exit 1
  fi

  local ext distributions=""
  ext="$(file_extension "${source}")"
  case "${ext}" in
    rpm) distributions="${rpm_dists}" ;;
    deb) distributions="${deb_dists}" ;;
  esac
  upload_file "${repo}" "${source}" "${distributions}"
}

main() {
  require_env
  echo "REPO=${REPO}"
  echo "SOURCE=${SOURCE}"
  echo "PACKAGECLOUD_RPM_DISTRIB=${PACKAGECLOUD_RPM_DISTRIB:-}"
  echo "PACKAGECLOUD_DEB_DISTRIB=${PACKAGECLOUD_DEB_DISTRIB:-}"
  install_cli
  if [ -d "${SOURCE}" ]; then
    upload_folder "${REPO}" "${SOURCE}" "${PACKAGECLOUD_DEB_DISTRIB:-}" "${PACKAGECLOUD_RPM_DISTRIB:-}"
  else
    upload_single "${REPO}" "${SOURCE}" "${PACKAGECLOUD_RPM_DISTRIB:-}" "${PACKAGECLOUD_DEB_DISTRIB:-}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
