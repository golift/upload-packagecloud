#!/usr/bin/env bats

write_package_cloud_spy() {
  cat > "$1" <<'EOF'
#!/usr/bin/env bash
{
  printf 'argc=%s\n' "$#"
  printf '%s\n' "$@"
  printf -- '---\n'
} >> "${PACKAGECLOUD_LOG}"
EOF
  chmod +x "$1"
}

push_record() {
  printf 'argc=%s\n' "$#"
  printf '%s\n' "$@"
  printf -- '---\n'
}

setup() {
  TEST_ROOT="${BATS_TEST_TMPDIR}"
  BIN="${TEST_ROOT}/bin"
  mkdir -p "${BIN}"
  export PACKAGECLOUD_LOG="${TEST_ROOT}/package_cloud.log"
  export GEM_LOG="${TEST_ROOT}/gem.log"
  export SUDO_LOG="${TEST_ROOT}/sudo.log"
  export GEM_USER_DIR="${TEST_ROOT}/gem-home"
  : > "${PACKAGECLOUD_LOG}"
  : > "${GEM_LOG}"
  : > "${SUDO_LOG}"

  write_package_cloud_spy "${BIN}/package_cloud"

  cat > "${BIN}/gem" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GEM_LOG}"
if [ "${1-}" = install ]; then
  mkdir -p "${GEM_USER_DIR}/bin"
  cat > "${GEM_USER_DIR}/bin/package_cloud" <<'SPY'
#!/usr/bin/env bash
{
  printf 'argc=%s\n' "$#"
  printf '%s\n' "$@"
  printf -- '---\n'
} >> "${PACKAGECLOUD_LOG}"
SPY
  chmod +x "${GEM_USER_DIR}/bin/package_cloud"
fi
exit 0
EOF
  cat > "${BIN}/ruby" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${GEM_USER_DIR}"
EOF
  cat > "${BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${SUDO_LOG}"
exec "$@"
EOF
  chmod +x "${BIN}/gem" "${BIN}/ruby" "${BIN}/sudo"

  export PATH="${BIN}:${PATH}"
  export REPO="golift/pkgs"
  export PACKAGECLOUD_TOKEN="test-token"
  export PACKAGECLOUD_RPM_DISTRIB=""
  export PACKAGECLOUD_DEB_DISTRIB=""
  SCRIPT="${BATS_TEST_DIRNAME}/../upload.sh"
}

@test "missing REPO fails" {
  export REPO=""
  export SOURCE="${TEST_ROOT}/pkg.deb"
  touch "${SOURCE}"
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"No REPO provided!"* ]]
}

@test "missing SOURCE fails" {
  export SOURCE=""
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"No SOURCE provided!"* ]]
}

@test "missing token fails" {
  export PACKAGECLOUD_TOKEN=""
  export SOURCE="${TEST_ROOT}/pkg.deb"
  touch "${SOURCE}"
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"No PACKAGECLOUD_TOKEN provided!"* ]]
}

@test "missing file fails" {
  export SOURCE="${TEST_ROOT}/no-such.deb"
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"SOURCE is not a file or directory:"* ]]
}

@test "empty folder fails" {
  mkdir -p "${TEST_ROOT}/empty"
  export SOURCE="${TEST_ROOT}/empty"
  run "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"No .deb or .rpm files in ${SOURCE}"* ]]
}

@test "folder with only debs uploads each deb dist and no rpms" {
  mkdir -p "${TEST_ROOT}/pkgs"
  touch "${TEST_ROOT}/pkgs/app.deb"
  export SOURCE="${TEST_ROOT}/pkgs"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal debian/buster"
  export PACKAGECLOUD_RPM_DISTRIB="el/6"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  expected="$(
    push_record push "golift/pkgs/ubuntu/focal" "${TEST_ROOT}/pkgs/app.deb"
    push_record push "golift/pkgs/debian/buster" "${TEST_ROOT}/pkgs/app.deb"
  )"
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "${expected}" ]
}

@test "folder with deb and rpm uploads both types" {
  mkdir -p "${TEST_ROOT}/pkgs"
  touch "${TEST_ROOT}/pkgs/app.deb" "${TEST_ROOT}/pkgs/app.rpm"
  export SOURCE="${TEST_ROOT}/pkgs"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  export PACKAGECLOUD_RPM_DISTRIB="el/6"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  expected="$(
    push_record push "golift/pkgs/ubuntu/focal" "${TEST_ROOT}/pkgs/app.deb"
    push_record push "golift/pkgs/el/6" "${TEST_ROOT}/pkgs/app.rpm"
  )"
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "${expected}" ]
}

@test "single rpm with two rpmdists uploads twice" {
  export SOURCE="${TEST_ROOT}/pkg.rpm"
  touch "${SOURCE}"
  export PACKAGECLOUD_RPM_DISTRIB="el/6 el/7"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  expected="$(
    push_record push "golift/pkgs/el/6" "${SOURCE}"
    push_record push "golift/pkgs/el/7" "${SOURCE}"
  )"
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "${expected}" ]
}

@test "non-rpm/deb file uploads to repo with no dist suffix" {
  export SOURCE="${TEST_ROOT}/mod.tgz"
  touch "${SOURCE}"
  export PACKAGECLOUD_RPM_DISTRIB="el/6"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  expected="$(push_record push "golift/pkgs" "${SOURCE}")"
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "${expected}" ]
}

@test "quoted paths with spaces stay a single argument" {
  mkdir -p "${TEST_ROOT}/my pkgs"
  touch "${TEST_ROOT}/my pkgs/app.deb"
  export SOURCE="${TEST_ROOT}/my pkgs"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  expected="$(push_record push "golift/pkgs/ubuntu/focal" "${TEST_ROOT}/my pkgs/app.deb")"
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "${expected}" ]
}

@test "skips gem install when package_cloud is on PATH" {
  export SOURCE="${TEST_ROOT}/pkg.deb"
  touch "${SOURCE}"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -s "${GEM_LOG}" ]
}

@test "installs package_cloud with gem --user-install when missing from PATH" {
  rm -f "${BIN}/package_cloud"
  export SOURCE="${TEST_ROOT}/pkg.deb"
  touch "${SOURCE}"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${GEM_LOG}")" = "install --no-document --user-install package_cloud" ]
  [ ! -s "${SUDO_LOG}" ]
  expected="$(push_record push "golift/pkgs/ubuntu/focal" "${SOURCE}")"
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "${expected}" ]
}
