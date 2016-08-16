# cm-release repo

cm-release is a kind of wrapper on the source repo "sec-eng-credential-manager". This
wrapper provides a way to dictate how Bosh uses credential manager (cm) as a release.

The source code from that repo is submoduled here.  

The pipeline "credential-manager.yml" has a phase "bump-credential-manager" that
has the responsibility to ensure that only green builds that also have
 changes to sec-eng-credential-manager are worthy of being used.
 It updates the SHA reference to this 'golden' build in order to specify the latest 
 snapshot to be wrapped into a bosh release. 
 
 
## Updating this repo's submodule before a BOSH release

To manually update a local repo, use
 
     ./scripts/update
 
 to ensure that the latest code has been pulled into the submodule.

## Creating a BOSH release

After that, to create a new release for bosh with

     bosh create release --with-tarball --name cm --force --timestamp-version

The full path of this newly created release is indicated at the bottom of its output, with an extension ".tgz". Use this full path as the value of the property with which you create the bosh release for credential manager, within the repo "cm-release"

## Rspec for testing .erb substitution logic

     cd spec
     bundle
     bundle install --binstubs
     ./bin/rspec
