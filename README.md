# <div align="center"><img src="docs/images/logo.png" alt="CredHub"></div>

# Long Term Support CredHub Releases

## Cutting a new lts release

### Push commit of open source credhub-release that we want to make a feature branch of

For example, if we want to create lts-credhub 2.4.x starting at `b0991a3` we run

Add the remote uri for the lts repo
```bash
$ pushd ~/workspace/credhub-release
$ git remote add lts git@github.com:pivotal/lts-credhub-release.git
```

Checkout to the commit that you want to be the starting point for the lts branch.
```bash
$ git checkout b0991a3
```

Push to a new branch on the lts remote
```bash
$ git checkout -b 2.4.x
$ git push -u lts 2.4.x
```

Do the same for the submodule
```bash
$ git submodule update
$ cd src/credhub
$ git remote add lts git@github.com:pivotal/lts-credhub.git
$ git checkout -b 2.4.x
$ git push -u lts 2.4.x
```


### Run the script to create an lts pipeline

```bash
$ cd ~/workspace/credhub-ci
$ ./script/create-lts-pipeline <credhub-version>
```
