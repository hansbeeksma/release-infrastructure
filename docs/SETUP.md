# Setup Guide

Stap-voor-stap onboarding voor het toevoegen van release-infrastructure aan een project.

## Prerequisites

- Repository onder `hansbeeksma` op GitHub
- Node.js project met `package.json`
- Conventional commits (`feat:`, `fix:`, `chore:`, etc.)

## Stap 1: CI Workflow

Maak `.github/workflows/ci.yml`:

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
      # Optioneel: disable specifieke checks
      # run-lint: false
      # run-tests: false
    secrets: inherit
```

### Monorepo variant

```yaml
jobs:
  ci-frontend:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-ci.yml@main
    with:
      working-directory: 'frontend'
    secrets: inherit

  ci-server:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-ci.yml@main
    with:
      working-directory: 'server'
    secrets: inherit
```

## Stap 2: Release-Please

### 2a. Config bestanden

Kopieer vanuit `configs/`:

```bash
# Standaard Node.js
cp configs/release-please-node.json release-please-config.json

# Of Next.js variant
cp configs/release-please-nextjs.json release-please-config.json
```

Maak `.release-please-manifest.json`:

```json
{
  ".": "0.1.0"
}
```

### 2b. Workflow

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

## Stap 3: Security Scans

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
    with:
      run-semgrep: true
      run-npm-audit: true
      # Optioneel (vereist secrets):
      # run-snyk: true
      # run-sbom: true
      # run-license-check: true
    secrets: inherit
```

## Stap 4: Dependabot

Kopieer de juiste template:

```bash
# Standaard project
cp configs/dependabot-standard.yml .github/dependabot.yml

# Monorepo
cp configs/dependabot-monorepo.yml .github/dependabot.yml
```

### Auto-merge workflow

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

## Stap 5: Verifieer

1. Push naar een feature branch
2. Open PR naar main
3. Controleer dat CI workflow draait
4. Merge PR met conventional commit message
5. Controleer dat Release-Please PR wordt aangemaakt

## Vereiste Secrets

| Secret | Vereist voor | Hoe instellen |
|--------|-------------|---------------|
| `GITHUB_TOKEN` | Release-Please, Dependabot auto-merge | Automatisch beschikbaar |
| `SNYK_TOKEN` | Snyk scan | [snyk.io](https://snyk.io) → Settings → API Token |
| `SLACK_WEBHOOK_URL` | Slack notificaties | Slack App → Incoming Webhooks |
| `SEMGREP_APP_TOKEN` | Semgrep Cloud | [semgrep.dev](https://semgrep.dev) → Settings |
