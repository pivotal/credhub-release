#!/bin/bash

function set_bash_error_handling() {
    set -euo pipefail
}

function go_to_project_root_directory() {
    local -r script_dir=$( dirname "${BASH_SOURCE[0]}")

    cd "$script_dir/.."
}

function checkout_credhub() {
    local -r version=$1
    local release__sha
    release__sha="$(bosh interpolate --path /commit_hash \
    <(git show "origin/master:releases/credhub/credhub-$version.yml"))"

    git co "$release__sha"
    git su
}

function main() {
    set_bash_error_handling
    go_to_project_root_directory
    checkout_credhub "$1"
}

main "$@"
