---
name: generate-release-notes
description: Generate release notes for the latest credhub-release.
---

# Instructions

## Rules & Restrictions
* Do not git push anything, or modify any git tags. Do not push any changes to remote.
* Unless specified otherwise, read from the `main` branch of this repo (`credhub-release`) and the `main` branch of the submodule (`./src/credhub`) repository (`https://github.com/cloudfoundry/credhub`).

## Core Writing Principles
* Be concise, but after reading these release notes, users should know what changes they should make when using this software & how/whether to adjust their expectations on how this software behaves.

## Prerequisites
* Ensure the current repository (`credhub-release`) is up to date and contains the latest git history.

## Step 1: Identify the Target Tag
* Find the most recent git tag in this repository. For example: `2.15.7`.

## Step 2: Identify the Baseline Tag
* Find the git tag associated with the latest public, already-published release (excluding release drafts) by examining the GitHub releases page: `https://github.com/pivotal/credhub-release/releases`.
  * For example, this baseline tag could be `2.15.6`.
* Validate the version increment: The target tag (from Step 1) should be a natural [semver](https://semver.org/) increment from the baseline tag (from Step 2). Identify the type of bump:
  * `2.15.6` -> `2.15.7` (patch bump)
  * `2.15.6` -> `2.16.0` (minor bump)
  * `2.15.6` -> `3.0.0` (major bump)
* **Anomaly Detection:** If there is any anomaly in the increment pattern (e.g., it violates semver), stop skill execution immediately and notify the user. Do not investigate the cause.
  * *Example:* If the two tags are identical (`2.15.7` -> `2.15.7`), this means a new unpublished release has not been tagged yet. There is no need to generate release notes.

## Step 3: Gather Commits
* Gather all full commit messages between the baseline tag and the target tag.
* If a commit contains a bump in the `credhub` source code git submodule (`./src/credhub`), also include the full commit messages from the submodule repository (`https://github.com/cloudfoundry/credhub`) that are part of that bump.
* Output the combined commit messages to the user, ordered chronologically from oldest to latest.

## Step 4: Generate Release Notes
Generate release notes in markdown based on the gathered commit messages using the following format:

```markdown
## What's Changed
* Fix: issue where MySQL DB migration fails due to xxx
* Fix TLS connection error issue with credhub server docker image https://github.com/pivotal/credhub-release/issues/429
* Migrate from Spring Boot 3 to Spring Boot 4
* Various other dependency bumps

### Features
* Add new API endpoint /xxxx/yyy

### Misc
* refactor: Replaced deprecated GenericGenerator UUID id
* bump: minor dependency updates (e.g., json library)

**Full Changelog**: https://github.com/pivotal/credhub-release/compare/2.15.6...2.15.7
```

**Formatting Guidelines:**
* **Bug Fixes:** Bug fixes should go under `## What's Changed`.
  * If the commit message or the PR associated with the commit mentions that the change fixes certain GitHub issues(s) in either this repo (`credhub-release`) or the credhub src code repo (https://github.com/cloudfoundry/credhub) and the links to those GitHub issues are provided, then provide the said links in the release note line too (see example markdown above).
* **Important Dependencies:** If there is a major/minor (not patch) dependency bump for a critical framework (e.g., Java, Spring Boot, Spring Security, BouncyCastle FIPS, Passay, Flyway) that may impact users, highlight it on its own line under `## What's Changed`.
* **Other Dependencies:** If there are other dependency bumps. Add a single `* Various other dependency bumps` bullet under `## What's Changed` as a catch-all. List the specific minor dependency updates individually under the `### Misc` section.
* **Misc Section:** Any minor commits (e.g., code refactoring, chores, test adjustments, migrate away from deprecated third-party libraries or methods, other internal changes or tech debts reduction) should go under `### Misc`. Users generally do not need to know about these items. But we still include them just for bookkeeping. The release person can decide to remove (or promote to other sections) these items as they see fit.
* **Features Section:** List any new features, config options, endpoints, or performance enhancements here. This is common during major/minor version bumps.
* **Ignored Commits:** Ignore commits that only contain versioning metadata bumps (e.g., "bump to 2.15.8" or "Create final release 2.15.7").
* **Empty Sections:** If a section contains zero items (e.g., no new features), omit the section entirely.
* **Full Changelog:** Construct the URL using the baseline and target tags.
