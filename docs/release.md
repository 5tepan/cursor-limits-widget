# Release & signing

## What CI produces today

GitHub Actions (`build.yml` / `release.yml`) builds an **ad-hoc** zip
(`codesign -`). Gatekeeper will show **Open Anyway** — that is expected until a
maintainer adds a Developer ID certificate.

Release configuration enables **Hardened Runtime** in Xcode
(`ENABLE_HARDENED_RUNTIME` for Release in `project.yml`). Ad-hoc CI builds still
sign without `--options runtime`; Developer ID builds add it in `package.sh`.

## Bundle identity (1.2.0+)

| Target | Bundle ID |
|---|---|
| App | `com.5tepan.cursorlimits` |
| Widget | `com.5tepan.cursorlimits.widget` |

Previously: `com.local.CursorLimits` / `.widget`.  
`~/Library/Application Support/CursorLimits/` is unchanged. On first launch the
app copies widget-container JSON from the legacy Containers path when needed.
**Copilot / Cursor Keychain tokens** may need a one-time reconnect after the ID
change (Keychain ACL is tied to the signing identity).

## Local package (Development)

```bash
./scripts/package.sh
# → dist/CursorLimits-*-macos.zip
```

Uses Apple Development if available, otherwise ad-hoc.

## Developer ID + notarization

Prerequisites: Apple Developer Program, “Developer ID Application” certificate,
App-specific password / API key stored as a `notarytool` keychain profile.

```bash
# One-time: store credentials
xcrun notarytool store-credentials CursorLimits-Notary \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

# Package, sign with Developer ID, notarize, staple
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=CursorLimits-Notary \
./scripts/package.sh
```

Then attach `dist/*.zip` (+ `.sha256`) to the GitHub Release, or push tag
`v$(grep MARKETING_VERSION project.yml)` after bumping the version.

## Version check

`release.yml` fails if the git tag (`v1.2.0`) does not match `MARKETING_VERSION`
in `project.yml`.
