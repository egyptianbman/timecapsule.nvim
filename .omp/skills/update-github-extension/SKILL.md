---
name: update-github-extension
description: Use when updating GitHub extension (Neovim plugin, LSP server, language server) — evaluates security, checks changelog for breaking changes, runs tests before merging updates.
---

# Update GitHub Extension

Evaluate GitHub extensions before updating. Coordinate security analysis, changelog review, and compatibility testing.

## Use when

- Dependency has a new release
- User requests updating a plugin/extension
- Security advisories reference a dependency
- Before merging a version-bump PR

## SHA pinning

Always pin to commit SHA, never tags or branches. Tags move; SHAs don't. Add a version comment after the SHA for readability:

```yaml
uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
```

## Verify SHA

Before pinning, confirm the SHA actually exists:

```bash
curl -sI https://github.com/<owner>/<repo>/commit/<SHA> | head -1
# 200 OK = valid; 404 = invalid — do NOT pin
```

Never trust a SHA from a third party or old commit history without verifying. Always fetch the real SHA from the GitHub API or the repo's commit page.

## Before you start

Check if the current SHA is already the latest release. If it is, document the review rather than skipping — a review confirms nothing changed, which is still valuable.

## Evaluation workflow

Clone the target repo, then run these in parallel:

**Security** — scan for eval/exec patterns, hardcoded secrets, dependency CVEs, supply chain risks in build scripts.

**Changelog** — read CHANGELOG.md or release notes for breaking changes and migration notes.

**Compatibility** — check if the project has tests, type checking, linting. A project that tests itself is lower risk.

## Output

Produce a single summary with:
- Security verdict (SAFE / REQUIRES REVIEW / INCOMPATIBLE)
- Breaking changes (if any)
- Recommendation (update / hold / reject)
- Updated SHA pins for any workflow files

## Guardrails

- Never update a workflow file without completing the review
- Never skip the security scan, even for familiar extensions
- If the update is rejected, document why so future reviewers don't re-evaluate the same issue
