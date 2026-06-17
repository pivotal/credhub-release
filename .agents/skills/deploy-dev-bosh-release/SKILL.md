---
name: deploy-dev-bosh-release
description: Build a local dev BOSH release for CredHub and deploy it to a TAS environment. Use when the user wants to create a dev release, test local changes, or run bosh create-release / bosh deploy.
disable-model-invocation: true
---

# Deploy Dev BOSH Release

Builds a local dev CredHub BOSH release and deploys it to a TAS environment, following the same steps used by CI.

## Prerequisites (manually configured by user)

- `om` CLI installed locally
- `bosh` CLI installed locally
- SSH access to the Ops Manager VM (host and SSH key)
- Working directory is the root of the `credhub-release` repo with the submodule in the expected state

## Parameters to gather

Ask the user for one of the two options below:

**Option A — Individual parameters:**

| Parameter | Example | Description |
|---|---|---|
| `DEV_VERSION` | `2.9.4-dev.1` | Dev release version string to use |
| `OPSMAN_HOST` | `10.0.0.1` | Hostname or IP of the Ops Manager VM |
| `OPSMAN_SSH_KEY` | `./tmp/opsman_key` | Path to the SSH private key for opsman (must be `chmod 600`) |
| `OPSMAN_URL` | `https://opsman.my-env.example.com` | Ops Manager URL (used to fetch BOSH credentials) |
| `OPSMAN_USER` | `admin` | Ops Manager admin username |
| `OPSMAN_PASSWORD` | `secret` | Ops Manager admin password |

**Option B — Using Smith lockfile:**
Ask for `DEV_VERSION` and `LOCKFILE_PATH`. Read the lockfile to identify and populate the opsman host, URL, credentials, and SSH private key. Write the SSH private key to `./tmp/opsman_key` with `chmod 600` and set `OPSMAN_SSH_KEY` to that path.

Once all variables are resolved, proceed with the workflow below.

## Workflow

### Step 1 — Create the dev release tarball

Run from the root of the `credhub-release` repo:

```bash
mkdir -p tmp
bosh create-release --tarball ./tmp/credhub-dev.tgz --name "credhub" --force --version="$DEV_VERSION"
```

### Step 2 — Upload the release to the BOSH director

Configure the local BOSH CLI, then upload:

```bash
eval "$(om -t "$OPSMAN_URL" -u "$OPSMAN_USER" -p "$OPSMAN_PASSWORD" -k bosh-env)"
bosh upload-release ./tmp/credhub-dev.tgz
```

### Helper: run a command on the Ops Manager VM

The opsman VM shell does not export BOSH environment variables for non-interactive sessions. The helper below fixes this by piping a script via SSH stdin — avoiding SSH argument-splitting issues — and bootstrapping the BOSH env on the remote side via `om bosh-env` before each command.

```bash
opsman_run() {
  local CMD="$1"
  ssh -i "$OPSMAN_SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$OPSMAN_HOST" bash << REMOTE_SCRIPT
eval "\$(om -t $OPSMAN_URL -u $OPSMAN_USER -p $OPSMAN_PASSWORD -k bosh-env)"
$CMD
REMOTE_SCRIPT
}
```

Define this helper once, then use it for all remote steps below. Step 5 (writing a file via stdin) is handled separately because it already uses SSH stdin.

### Step 3 — Identify the CF deployment name

```bash
opsman_run "bosh deployments"
```

Capture or note the deployment name from the output (typically prefixed with `cf-`). This is `DEPLOYMENT_NAME`.

### Step 4 — Download the deployment manifest on opsman

```bash
opsman_run "bosh manifest -d $DEPLOYMENT_NAME > /tmp/cf.yml"
```

### Step 5 — Create the ops file on opsman

Pipe a local heredoc (with `$DEV_VERSION` expanded) into opsman via stdin:

```bash
OPS_FILE_CONTENT="---
- type: replace
  path: /releases/name=credhub
  value:
    name: credhub
    version: $DEV_VERSION"

echo "$OPS_FILE_CONTENT" | ssh -i "$OPSMAN_SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$OPSMAN_HOST" 'cat > /tmp/use-latest-credhub.yml'
```

### Step 6 — Interpolate the ops file on opsman

```bash
opsman_run "bosh int -o /tmp/use-latest-credhub.yml /tmp/cf.yml > /tmp/cf-with-latest-credhub.yml"
```

### Step 7 — Redeploy from opsman

```bash
opsman_run "bosh deploy -n -d $DEPLOYMENT_NAME /tmp/cf-with-latest-credhub.yml"
```

## Notes

- `--force` in `bosh create-release` allows creating a release with uncommitted local changes.
- The `DEV_VERSION` string can be arbitrary; use a consistent pattern like `<base-version>-dev.<n>`.
- The `-k` flag in `om bosh-env` skips TLS verification of the Ops Manager certificate; safe for dev environments.
- Steps 3–7 run on the opsman VM so that all BOSH traffic stays on the internal network between opsman and the BOSH director.
- The `opsman_run` helper pipes the script body via SSH stdin rather than passing it as a command-line argument. This avoids the SSH multi-argument splitting bug where `bash -lc "cmd arg"` becomes `bash -l -c cmd [arg as $0]` on the remote, causing `arg` to be dropped.
- `bosh ds` is not a reliable alias across environments; use the full `bosh deployments` command.
