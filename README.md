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
  url: https://bosh.io/d/github.com/pivotal-cf/credhub-release?v=1.2.0
  version: 1.2.0
  sha1: b28b53dc55c1f1c8ef37edddc9ecad76e16f7d77
```

[1]:https://github.com/cloudfoundry-incubator/credhub
[2]:https://bosh.io/releases/github.com/pivotal-cf/credhub-release?all=1
[3]:https://bosh.io/jobs/credhub?source=github.com/pivotal-cf/credhub-release

## Release Lifecycle

CredHub issues frequent minor releases containing new features. If you wish to receive the latest new features, the most recent release should be used. If you choose to use the latest release line, you must update to a subsequent patch or minor release - which may contain new features - to receive security patches and bug fixes. 

If you wish to use a stable version with a less frequent feature release cycle, you may use a long term support version. LTS versions are patched for security vulnerabilities and bugs, but do not contain new features. New LTS versions are released quarterly. Patches are issued for LTS versions for 9 months following release (current–2 structure). 

Current long term support versions

| Version | Released    | End of Patch Releases |
|---------|-------------|------------------------|
| 1.0.x   | Jun-15-2017 | Mar-15-2018            |
 

## Reporting a Vulnerability

We strongly encourage people to report security vulnerabilities privately to our security team before disclosing them in a public forum.

Please note that the e-mail address below should only be used for reporting undisclosed security vulnerabilities in Pivotal products and managing the process of fixing such vulnerabilities. We cannot accept regular bug reports or other security-related queries at this address.

The e-mail address to use to contact the Pivotal Application Security Team is security@pivotal.io.

Our public PGP key can be obtained from a public key server such as [pgp.mit.edu](https://pgp.mit.edu). Its fingerprint is: 16F6 51BF 4637 F486 C5E2 4635 19BB 5184 0191 92ED. More information can be found at [pivotal.io/security](https://pivotal.io/security/).

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
