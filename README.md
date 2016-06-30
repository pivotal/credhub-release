cm-release is a kind of wrapper on the source repo "sec-eng-credential-manager". This
wrapper provides a way to dictate how Bosh uses credential manager (cm) as a release.

The source code from that repo is submoduled here. Use

    ./scripts/update

to ensure that the latest code has been pulled into the submodules.

After that, to create a new release for bosh with

     bosh create release --with-tarball --name cm --force --timestamp-version

The full path of this newly created release is indicated at the bottom of its output, with an extension ".tgz". Use this full path as the value of the property with which you create the bosh release for credential manager, within the repo "cm-release"