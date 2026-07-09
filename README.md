# Brave Debloat Kit

Opinionated Brave cleanup for Linux desktops.

It disables Brave Ads, Rewards, Wallet UI, Brave News/Today, Leo/AI Chat, Talk
entrypoints, background mode, sync clutter, telemetry/P3A leftovers, and several
background-heavy Chromium/Brave features. It also removes generated caches such
as `ads_service`, `AIChat`, `BraveWallet`, and Rewards files.

Web3 is **not** disabled by default because some people intentionally use wallet
APIs. Use `--disable-web3` when you want the native Web3 provider and local
wallet cache gone too.

## Requirements

- Linux
- Brave installed
- `jq`
- Bash

## Usage

Dry run:

```bash
./bin/brave-debloat.sh --dry-run
```

Default debloat:

```bash
./bin/brave-debloat.sh
```

Debloat and also disable Web3:

```bash
./bin/brave-debloat.sh --disable-web3
```

Install system policy too. This is the part that removes hardcoded Brave UI
items such as Wallet from the app menu and settings sidebar:

```bash
./bin/brave-debloat.sh --install-policy
```

Target Brave Nightly explicitly:

```bash
./bin/brave-debloat.sh \
  --profile-dir "$HOME/.config/BraveSoftware/Brave-Browser-Nightly" \
  --disable-web3 \
  --install-policy
```

## What Gets Changed

- Brave Ads disabled
- Brave Rewards disabled
- Brave Wallet icon and wallet defaults disabled
- Brave News/Today disabled
- Leo/AI Chat disabled, including toolbar/sidebar/omnibox entrypoints
- Brave Talk entrypoint prefs disabled
- P3A/local metrics leftovers removed
- Background mode disabled
- Sync suppressed
- Search suggestions disabled
- Notifications/background sync/geolocation blocked by default
- Generated bloat caches removed
- Optional Web3 disable via `--disable-web3`
- Optional system policy via `--install-policy` to remove hardcoded UI entries

The script creates backups before editing:

```text
~/.config/BraveSoftware/<profile-root>/debloat-backups/<timestamp>/
```

## Enterprise Policy

Some Brave UI entries do not disappear from preferences alone. Wallet is the
main example: Brave exposes `BraveWalletDisabled`, but it must be installed as a
managed policy.

`--install-policy` writes:

```text
/etc/brave/policies/managed/brave-debloat.json
```

It uses `pkexec` or `sudo` when the script is not running as root.

## Launcher

By default the script creates:

```text
~/.local/bin/brave-debloated
```

and local `.desktop` overrides so launching Brave from the app menu uses a
lighter set of flags.

When `--disable-web3` is used, the launcher also adds Brave Wallet/Web3 feature
flags to the disabled feature list. Without that option, Web3 is left alone.

Use `--no-launcher` if you only want profile preference changes.

## Publishing To GitHub

```bash
git init
git add README.md bin/brave-debloat.sh
git commit -m "Add Brave debloat script"
gh repo create brave-debloat-kit --public --source=. --remote=origin --push
```

If you do not use GitHub CLI:

```bash
git remote add origin git@github.com:YOUR_USER/brave-debloat-kit.git
git branch -M main
git push -u origin main
```
