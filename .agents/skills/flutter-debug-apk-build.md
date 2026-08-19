---
name: flutter-debug-apk-build
description: Build and push Flutter debug APK to GitHub using GitHub Actions. Use when asked to "build debug APK", "create CI/CD", "setup GitHub Actions for Flutter", "push and build", or "deploy debug build". Triggers: Flutter, GitHub Actions, debug APK, CI/CD, build pipeline.
---

# Flutter Debug APK Build

Build Flutter debug APK on GitHub Actions and push code to trigger the build.

## Quick Reference

| Item | Value |
|------|-------|
| Repository | `hoangsoft90/OfflineLinkSaver` |
| Branch | `main` |
| Workflow | `.github/workflows/build-debug-apk.yml` |
| Build Command | `flutter build apk --debug` |
| Output | `build/app/outputs/flutter-apk/app-debug.apk` |

## Workflow File

Location: `.github/workflows/build-debug-apk.yml`

```yaml
name: Build Debug APK

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:  # Allow manual trigger

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'

      - name: Flutter version
        run: flutter --version

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze code
        run: flutter analyze --no-fatal-infos

      - name: Build debug APK
        run: flutter build apk --debug

      - name: Upload debug APK
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 7
```

## Push Commands

### First Time Setup
```bash
git init
git config user.email "hoangsoft90@users.noreply.github.com"
git config user.name "hoangsoft90"
git remote add origin https://hoangsoft90:<TOKEN>@github.com/hoangsoft90/OfflineLinkSaver.git
```

### Push Changes
```bash
git add -A
git commit -m "Your commit message"
git push origin main
```

### Using Token (for authentication)
```bash
git remote add origin https://hoangsoft90:<TOKEN>@github.com/hoangsoft90/OfflineLinkSaver.git
git push -u origin main
```

Replace `<TOKEN>` with the GitHub personal access token.

## Trigger Build

Build triggers automatically on:
1. Push to `main` or `master` branch
2. Pull request to `main` or `master`
3. Manual trigger via GitHub UI (Actions → Build Debug APK → Run workflow)

## Download APK

After build completes:
1. Go to GitHub repo → Actions → Latest workflow run
2. Scroll to "Artifacts" section
3. Download `debug-apk` zip file
4. Extract `app-debug.apk`

## Debugging Build Failures

### Common Issues

| Error | Solution |
|-------|----------|
| Flutter SDK not found | Check `flutter-version` in workflow |
| Java version mismatch | Ensure `java-version: '17'` |
| Dependency errors | Run `flutter pub get` locally first |
| Gradle errors | Check `android/build.gradle` compatibility |
| Analyze errors | Fix warnings or use `--no-fatal-infos` |

### Check Build Logs
1. Go to Actions tab
2. Click on failed workflow
3. Expand failed step
4. Read error message

### Local Build Test
```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

## Notes

- Debug APK is unsigned (no keystore needed)
- APK includes debug symbols
- Retention: 7 days on GitHub Actions
- No EAS token required (uses Gradle directly)
- Java 17 required for Android Gradle Plugin 8.x
- Workflow creates `local.properties` automatically
- Gradle files handle missing local.properties gracefully
