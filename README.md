# CredHub Release

This is a BOSH Release for [CredHub](https://github.com/pivotal-cf/sec-eng-credential-manager).

## Updating this repo's submodule before a BOSH release

To manually update a local repo, use

```sh
    ./scripts/update
```

 to ensure that the latest code has been pulled into the submodule.

## Dev and lite deploys

See the `sec-eng-deployment-credential-manager` repo for instructions.

## Run unit tests to exercise the template logic used for application properties

```sh
     ./spec/run_tests.sh
```
## Creating a final BOSH release for distribution

See the `credhub-distribution` repo for instructions.
