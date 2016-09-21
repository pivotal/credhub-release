# CredHub Release

This is a BOSH Release for [CredHub](https://github.com/pivotal-cf/sec-eng-credential-manager)

## Updating this repo's submodule before a BOSH release

To manually update a local repo, use
```sh
    ./scripts/update
```

 to ensure that the latest code has been pulled into the submodule.

## Creating a BOSH release for development

After that, create a new tarball release with bosh

```sh
     bosh create release --with-tarball --name credhub --force --timestamp-version
```

## Run unit tests to exercise the template logic used for application properties

```sh
     ./spec/run_tests.sh
```
## Creating a final BOSH release for distribution

First, make sure you have on local disk a file `config/private.yml`, which is NOT checked in. This file specifies the access keys to push a final release to the blobstore. Copy the contents from lastpass note named "aws s3 credhub-release-blobs". Again, do NOT check in this file.

Second, make sure you have bumped the version number in the server build file, src/credhub/build.gradle

```sh
     bosh create release --final --name credhub --version <YOUR NEW VERSION>
     echo "Now check in the bosh release info created in the 'releases' directory"
```

Third, to distribute this final release, go to repo "credhub-distribution" and commit the submodule SHAs for both this final release and the corresponding CLI version.