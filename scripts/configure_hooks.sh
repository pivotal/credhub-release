#!/bin/bash

set -eou pipefail


function configure_hooks() {
    git config core.hooksPath ./hooks
}

function configure_submodule_hooks() {
    local -r scripts_dir=$( dirname "${BASH_SOURCE[0]}")
    pushd "$scripts_dir/../src/credhub/scripts/" > /dev/null
      ./configure_hooks.sh
    popd > /dev/null
}

main() {
    configure_hooks
    configure_submodule_hooks
    echo "git hooks configured"
}

main
