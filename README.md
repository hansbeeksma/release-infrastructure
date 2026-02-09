# Release Infrastructure

Centraal repository met herbruikbare GitHub Actions workflows voor alle `hansbeeksma` repositories.

## Overzicht

| Workflow | Doel | Trigger |
|----------|------|---------|
| `reusable-ci.yml` | Lint, test, build, secret scan, dependency audit | Push/PR |
| `reusable-release-please.yml` | Automated releases met changelogs | Push op main |
| `reusable-security.yml` | SAST (Semgrep), SCA, SBOM, license check | Weekly cron + PR |
| `reusable-dependabot-auto.yml` | Auto-merge Dependabot PRs | Dependabot PRs |
| `reusable-notify.yml` | Geconsolideerde failure notifications | Workflow failures |

## Quick Start

### 1. CI Workflow

Maak `.github/workflows/ci.yml` in je repo:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-ci.yml@main
    with:
      node-version: '20'
    secrets: inherit
```

### 2. Release-Please

Maak `.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    branches: [main]

jobs:
  release:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-release-please.yml@main
    with:
      release-type: 'node'
    secrets: inherit
```

Plus `release-please-config.json` en `.release-please-manifest.json` in je repo root.

### 3. Security Scans

Maak `.github/workflows/security.yml`:

```yaml
name: Security
on:
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 3 * * 1'  # Weekly maandag 03:00 UTC

jobs:
  security:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-security.yml@main
    secrets: inherit
```

### 4. Dependabot Auto-merge

Maak `.github/workflows/dependabot-auto.yml`:

```yaml
name: Dependabot Auto-merge
on:
  pull_request:

jobs:
  auto-merge:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-dependabot-auto.yml@main
    secrets: inherit
```

## Scripts

De `scripts/` directory bevat standalone Bash-scripts voor release governance:

| Script | Gebruik | Doel |
|--------|---------|------|
| `dora-metrics.sh` | `./scripts/dora-metrics.sh --project-dir /path/to/project` | DORA metrics berekenen (Deployment Frequency, Lead Time, Change Failure Rate, MTTR) |
| `release-readiness.sh` | `./scripts/release-readiness.sh --project-dir /path/to/project` | Pre-flight release checks (9 gates: tests, build, lint, security, gitleaks, etc.) |

### DORA Metrics

```bash
# Draai op een project
./scripts/dora-metrics.sh --project-dir ~/Development/products/vino12

# Output: Deployment Frequency, Lead Time, Change Failure Rate, MTTR
# Ratings: ELITE / HIGH / MEDIUM / LOW
```

### Release Readiness

```bash
# Pre-flight check voor release
./scripts/release-readiness.sh --project-dir ~/Development/products/vino12

# Output: GO / NO-GO met 9 quality gates
# Gates: working tree, branch, remote sync, tests, build, security, gitleaks, lint, release info
```

## Documentatie

- [Setup Guide](docs/SETUP.md) - Volledige onboarding per project
- [Customization](docs/CUSTOMIZATION.md) - Per-project overrides
- [Troubleshooting](docs/TROUBLESHOOTING.md) - FAQ en bekende issues

## Template Configs

De `configs/` directory bevat templates die je naar je project kunt kopieren:

| Config | Gebruik |
|--------|---------|
| `release-please-node.json` | Release-Please config voor Node.js |
| `release-please-nextjs.json` | Release-Please config voor Next.js |
| `dependabot-standard.yml` | Dependabot voor enkele package.json |
| `dependabot-monorepo.yml` | Dependabot voor monorepos |
| `commitlint.config.js` | Shared conventional commits config |
