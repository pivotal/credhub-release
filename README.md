# CredHub Release

This is a BOSH Release for [CredHub](https://github.com/pivotal-cf/sec-eng-credential-manager)

## Updating this repo's submodule before a BOSH release

To manually update a local repo, use
```sh
    ./scripts/update
```

 to ensure that the latest code has been pulled into the submodule.

## Creating a BOSH release

After that, create a new tarball release with bosh

```sh
     bosh create release --with-tarball --name credhub --force --timestamp-version
```

## Run unit tests to exercise the template logic used for application properties

```sh
     ./spec/run_tests.sh
```
