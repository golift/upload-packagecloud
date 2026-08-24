#!/usr/bin/env bats

setup() {
  TEST_ROOT="${BATS_TEST_TMPDIR}"
  BIN="${TEST_ROOT}/bin"
  mkdir -p "${BIN}"
  export PACKAGECLOUD_LOG="${TEST_ROOT}/package_cloud.log"
  export GEM_LOG="${TEST_ROOT}/gem.log"
  : > "${PACKAGECLOUD_LOG}"
  : > "${GEM_LOG}"

  cat > "${BIN}/package_cloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${PACKAGECLOUD_LOG}"
EOF
  cat > "${BIN}/gem" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GEM_LOG}"
exit 0
EOF
  cat > "${BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
  chmod +x "${BIN}/package_cloud" "${BIN}/gem" "${BIN}/sudo"

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
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "push golift/pkgs/ubuntu/focal ${TEST_ROOT}/pkgs/app.deb
push golift/pkgs/debian/buster ${TEST_ROOT}/pkgs/app.deb" ]
}

@test "folder with deb and rpm uploads both types" {
  mkdir -p "${TEST_ROOT}/pkgs"
  touch "${TEST_ROOT}/pkgs/app.deb" "${TEST_ROOT}/pkgs/app.rpm"
  export SOURCE="${TEST_ROOT}/pkgs"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  export PACKAGECLOUD_RPM_DISTRIB="el/6"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "push golift/pkgs/ubuntu/focal ${TEST_ROOT}/pkgs/app.deb
push golift/pkgs/el/6 ${TEST_ROOT}/pkgs/app.rpm" ]
}

@test "single rpm with two rpmdists uploads twice" {
  export SOURCE="${TEST_ROOT}/pkg.rpm"
  touch "${SOURCE}"
  export PACKAGECLOUD_RPM_DISTRIB="el/6 el/7"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "push golift/pkgs/el/6 ${SOURCE}
push golift/pkgs/el/7 ${SOURCE}" ]
}

@test "non-rpm/deb file uploads to repo with no dist suffix" {
  export SOURCE="${TEST_ROOT}/mod.tgz"
  touch "${SOURCE}"
  export PACKAGECLOUD_RPM_DISTRIB="el/6"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${PACKAGECLOUD_LOG}")" = "push golift/pkgs ${SOURCE}" ]
}

@test "skips gem install when package_cloud is on PATH" {
  export SOURCE="${TEST_ROOT}/pkg.deb"
  touch "${SOURCE}"
  export PACKAGECLOUD_DEB_DISTRIB="ubuntu/focal"
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ ! -s "${GEM_LOG}" ]
}
