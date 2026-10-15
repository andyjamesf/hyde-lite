# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Use GitHub's private reporting instead:
**Security → Report a vulnerability** on this repository's page. Include what you found, how to reproduce
it and which commit you tested.

You can expect an answer within a week. hyde-lite is maintained by one person in spare time, so fixes are
best effort, but a real vulnerability comes first.

## What is in scope

- The installer (`install.sh` and what it runs), including anything that runs with `sudo`.
- The two shells and their helper scripts (credentials for calendar or AI-usage widgets, the lock screen,
  the login theme).
- The colour pipeline scripts in `Configs/.local/bin/`.

Problems in upstream HyDE, Hyprland, Quickshell or matugen themselves belong to those projects.

## Supported versions

Only the latest commit on `main`.
