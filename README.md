# CredHub Release

CredHub release provides a BOSH Release for [CredHub](https://github.com/cloudfoundry-incubator/credhub).

* [Documentation](docs/)
* [CredHub Tracker](https://www.pivotaltracker.com/n/projects/1977341)

See additional repos for more info:

* [credhub](https://github.com/cloudfoundry-incubator/credhub) :     CredHub server code
* [credhub-cli](https://github.com/cloudfoundry-incubator/credhub-cli) :     command line interface for credhub
* [credhub-acceptance-tests](https://github.com/cloudfoundry-incubator/credhub-acceptance-tests) : integration tests written in Go.

## Deploying CredHub

This repository includes code to create a BOSH release of [CredHub.][1] Releases based on this repository are created and posted automatically to [bosh.io][2] for deployment. 

Adding CredHub to an existing deployment manifest can be done by simply adding the release and its appropriate [job configurations.][3] Complete sample manifests can be [found here.](sample-manifests/)

```
releases:
- name: credhub
  url: https://bosh.io/d/github.com/pivotal-cf/credhub-release?v=0.6.1
  version: 0.6.1
  sha1: 5ab4c4ef3d67f8ea07d78b1a87707e7520a97ab7
```

[1]:https://github.com/cloudfoundry-incubator/credhub
[2]:https://bosh.io/releases/github.com/pivotal-cf/credhub-release?all=1
[3]:https://bosh.io/jobs/credhub?source=github.com/pivotal-cf/credhub-release&version=0.6.1

## Development 

### Updating this repo's submodule before a BOSH release

To manually update a local repo, use

```sh
$ ./scripts/update
```

 to ensure that the latest code has been pulled into the submodule.

### Run unit tests to exercise the template logic used for application properties

```sh
$ ./spec/run_tests.sh
```

### Create a packaged BOSH release 

```sh
$ bosh create-release --name credhub --version test --tarball ./credhub-test.tgz
```
