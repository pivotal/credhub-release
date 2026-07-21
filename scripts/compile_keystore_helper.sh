#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
helper_dir="${repo_root}/src/keystore-helper"

javac --release 17 -d "${helper_dir}" "${helper_dir}/PemToKeyStore.java"
