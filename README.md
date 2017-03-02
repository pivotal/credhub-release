# CredHub Release

CredHub release provides a BOSH Release for [CredHub](https://github.com/cloudfoundry-incubator/credhub).
 
* [CredHub Tracker](https://www.pivotaltracker.com/n/projects/1977341)
 
See additional repos for more info:

* [credhub](https://github.com/cloudfoundry-incubator/credhub) :     CredHub server code 
* [credhub-cli](https://github.com/cloudfoundry-incubator/credhub-cli) :     command line interface for credhub
* [credhub-acceptance-tests](https://github.com/cloudfoundry-incubator/credhub-acceptance-tests) : integration tests written in Go.

## Deployment documentation

* [Sample Deployment Manifests] (sample-manifests/)
* [Integration with BOSH Director] (docs/bosh-install-with-credhub.md)
* [Configuring a Luna HSM] (docs/configure-luna-hsm.md)
* [Backup and Restore Recommendations] (docs/backup-restore-recommendations.md)
* [Deployment Troubleshooting Guide] (docs/deployment-troubleshooting-guide.md)

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

## Development

You can commit BOSH release related changes in this repo, but don't commit submodule updates. If you change the Java codebase, commit and push 
in the submodule and CI will update this repository's reference after a green build.
