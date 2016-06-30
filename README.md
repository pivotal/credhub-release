cm-release is a kind of wrapper on the source repo "sec-eng-credential-manager". This
wrapper provides a way to dictate how Bosh uses credential manager (cm) as a release.

The source code from that repo is submoduled here. To manually update a local repo, use

    ./scripts/update

to ensure that the latest code has been pulled into the submodules. 

The pipeline "credential-manager.yml" has a phase "bump-credential-manager" that
updates the SHA reference in the submodules in order to specify the latest snapshot to be wrapped into a bosh release. 

After that, to create a new release for bosh with

     bosh create release --with-tarball --name cm --force --timestamp-version

The full path of this newly created release is indicated at the bottom of its output, with an extension ".tgz". Use this full path as the value of the property with which you create the bosh release for credential manager, within the repo "cm-release"