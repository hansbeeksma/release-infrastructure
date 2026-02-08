# Customization Guide

Per-project overrides voor reusable workflows.

## CI Workflow Parameters

| Parameter | Type | Default | Beschrijving |
|-----------|------|---------|-------------|
| `node-version` | string | `'20'` | Node.js versie |
| `run-lint` | boolean | `true` | ESLint uitvoeren |
| `run-tests` | boolean | `true` | Tests uitvoeren |
| `run-build` | boolean | `true` | Build uitvoeren |
| `run-secret-scan` | boolean | `true` | Gitleaks scan |
| `run-audit` | boolean | `true` | npm audit |
| `audit-level` | string | `'critical'` | Audit severity level |
| `working-directory` | string | `'.'` | Werkdirectory (monorepo) |
| `gitleaks-version` | string | `'8.30.0'` | Gitleaks versie |

### Voorbeeld: Minimale CI (alleen lint + build)

```yaml
jobs:
  ci:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-ci.yml@main
    with:
      run-tests: false
      run-secret-scan: false
      run-audit: false
```

## Security Workflow Parameters

| Parameter | Type | Default | Beschrijving |
|-----------|------|---------|-------------|
| `run-semgrep` | boolean | `true` | Semgrep SAST |
| `run-npm-audit` | boolean | `true` | npm audit SCA |
| `run-snyk` | boolean | `false` | Snyk scan (vereist `SNYK_TOKEN`) |
| `run-sbom` | boolean | `false` | SBOM generatie |
| `run-license-check` | boolean | `false` | License compliance |
| `semgrep-rules` | string | (zie default) | Semgrep rulesets |
| `working-directory` | string | `'.'` | Werkdirectory |

### Voorbeeld: Volledige security suite

```yaml
jobs:
  security:
    uses: hansbeeksma/release-infrastructure/.github/workflows/reusable-security.yml@main
    with:
      run-semgrep: true
      run-npm-audit: true
      run-snyk: true
      run-sbom: true
      run-license-check: true
    secrets: inherit
```

## Dependabot Auto-merge Parameters

| Parameter | Type | Default | Beschrijving |
|-----------|------|---------|-------------|
| `auto-merge-patch` | boolean | `true` | Patches auto-mergen |
| `auto-merge-minor-dev` | boolean | `true` | Minor dev deps auto-mergen |
| `auto-merge-minor-prod` | boolean | `false` | Minor prod deps auto-mergen |

### Auto-merge matrix

| Update Type | Dev Dep | Prod Dep | Default |
|-------------|---------|----------|---------|
| Patch | Auto-merge | Auto-merge | Enabled |
| Minor | Auto-merge | Review | Dev only |
| Major | Review | Review | Never |

## Release-Please Config

### Changelog secties aanpassen

Edit `release-please-config.json`:

```json
{
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "security", "section": "Security" }
  ]
}
```

### Monorepo met meerdere packages

```json
{
  "packages": {
    "packages/core": {
      "release-type": "node",
      "component": "core"
    },
    "packages/cli": {
      "release-type": "node",
      "component": "cli"
    }
  }
}
```

## Project-specifieke workflows toevoegen

Je kunt altijd extra jobs toevoegen naast de reusable workflows:

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
    secrets: inherit

  # Project-specifieke jobs
  lighthouse:
    needs: ci
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
      - run: npx lhci autorun
```
