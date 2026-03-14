# Contributing to Matcha

Thanks for helping improve Matcha.

## Before You Start

- Read `README.md` for product behavior, build steps, and safety notes.
- If you plan to work on battery mode or power-management behavior, test carefully on a real Mac. This project can modify `pmset` settings.
- Keep changes focused. Small pull requests are much easier to review and validate.

## Development Setup

Requirements:

- macOS 13.0+
- Xcode 15.0+
- XcodeGen
- appdmg

Install dependencies:

```bash
brew install xcodegen
npm install -g appdmg
```

Generate the project:

```bash
xcodegen generate
```

Run tests:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Matcha.xcodeproj \
  -scheme MatchaTests \
  -sdk macosx \
  test \
  -destination 'platform=macOS'
```

Build release artifacts:

```bash
./scripts/build-release-artifacts.sh
```

## Branches and Commits

- Branch from `main`.
- Use a short, descriptive branch name.
- Prefer one logical change per pull request.
- Use clear commit messages such as:
  - `fix: restore pmset snapshot on battery mode exit`
  - `docs: add release checklist`
  - `test: cover lid-close display sleep transition`

## Pull Request Expectations

Please include:

- What changed
- Why it changed
- How you tested it
- Screenshots or screen recordings if UI behavior changed
- Any `pmset` or power-management side effects reviewers should validate manually

## Testing Guidance

At minimum:

- Run the unit tests
- Verify the app still builds

If you change power-management behavior, also test the relevant manual flows:

- Start and stop each mode
- Switch between modes
- For battery mode:
  - Enable the mode
  - Close the lid and confirm display behavior
  - Re-open the lid and confirm recovery behavior
  - Quit and relaunch to confirm startup recovery

## Scope Guidance

Good first contributions:

- Documentation improvements
- UI copy clarity
- Additional unit tests
- Build and release workflow polish

Higher-risk areas:

- `pmset` handling
- `caffeinate` mode behavior
- launch-at-login behavior
- lid-close detection and display sleep behavior

For risky changes, please open an issue or draft pull request early so we can align on approach before a lot of code is written.
