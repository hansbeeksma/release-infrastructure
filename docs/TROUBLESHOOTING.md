# Troubleshooting

## Veelvoorkomende problemen

### Release-Please maakt geen PR aan

**Symptoom:** Push naar main, maar geen Release-Please PR.

**Oorzaken:**
1. **Geen conventional commits** - Release-Please reageert alleen op `feat:`, `fix:`, `perf:`, `security:` commits
2. **Verkeerde branch** - Check `target-branch` parameter
3. **Permissions** - `GITHUB_TOKEN` heeft `contents: write` en `pull-requests: write` nodig

**Fix:**
```bash
# Controleer of je conventional commits gebruikt
git log --oneline -10

# Test met een feat commit
git commit --allow-empty -m "feat: test release-please"
git push
```

### Dependabot auto-merge werkt niet

**Symptoom:** Dependabot PR's worden niet automatisch gemerged.

**Oorzaken:**
1. **Branch protection** - "Require approvals" staat aan maar bot kan niet approven
2. **CI faalt** - Auto-merge wacht op succesvolle CI
3. **Major update** - Major updates worden nooit auto-gemerged

**Fix:**
- Zorg dat `GITHUB_TOKEN` write permissions heeft
- Check of CI workflow slaagt voor de Dependabot PR
- Voeg `actions: write` permission toe als branch protection "Require status checks" aan staat

### Semgrep faalt met "no rules matched"

**Symptoom:** Semgrep scan geeft error of vindt geen files.

**Fix:**
- Check `working-directory` parameter
- Zorg dat je project `.js`, `.ts`, `.jsx`, of `.tsx` bestanden bevat
- Test lokaal: `docker run --rm -v "${PWD}:/src" semgrep/semgrep scan --config p/javascript`

### Gitleaks false positives

**Symptoom:** Gitleaks blokkeert CI voor onschadelijke strings.

**Fix:**
Maak `.gitleaks.toml` in je project root:

```toml
[extend]
useDefault = true

[allowlist]
paths = [
  '''\.env\.example''',
  '''package-lock\.json''',
]

# Specifieke false positive uitsluiten
[[allowlist.commits]]
sha = "abc123..."
```

### npm audit failures door bekende issues

**Symptoom:** npm audit faalt voor vulnerabilities zonder fix.

**Opties:**
1. Set `audit-level` naar `critical` (default) om alleen kritieke issues te blokkeren
2. Voeg `continue-on-error: true` toe aan je CI workflow

### Reusable workflow niet gevonden

**Symptoom:** `Not found: hansbeeksma/release-infrastructure/.github/workflows/...`

**Oorzaken:**
1. **Repository is private** - Reusable workflows moeten in een public repo staan
2. **Verkeerd pad** - Check de exacte bestandsnaam
3. **Branch ref** - Gebruik `@main` of een specifieke tag `@v1`

### Te veel email notificaties

**Checklist:**
1. GitHub Settings → Notifications → Actions → "Only notify for failed workflows"
2. Dependabot interval naar `weekly` (niet `daily`)
3. PR limit verlagen naar 5
4. Auto-merge voor patches inschakelen
5. Security cron naar weekly (niet daily)

## Migratie van inline workflows

Bij migratie van bestaande inline workflows naar reusable:

1. **Backup** bestaande workflow
2. **Vergelijk** parameters met reusable workflow inputs
3. **Migreer** stapsgewijs (eerst CI, dan security, dan release)
4. **Test** op feature branch voor merge naar main
5. **Verwijder** oude inline workflow na succesvolle test
