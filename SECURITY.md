# Security Policy

## Supported Versions

Matcha is currently maintained on the latest `main` branch.

## Reporting a Vulnerability

Please do not open a public GitHub issue for security-sensitive reports.

Please report vulnerabilities through GitHub Private Vulnerability Reporting:

- https://github.com/chocoHunter/matcha/security/advisories/new

If that page is unavailable for any reason, open an issue titled `SECURITY: private contact request` without technical details, and we will move to a private channel.

When reporting, please include:

- A clear description of the issue
- Impact and affected behavior
- Reproduction steps
- macOS version
- Whether the issue changes system power settings or creates persistent side effects
- Suggested recovery steps, if known

## Response Expectations

- Initial acknowledgement target: within 7 days
- Status update target: within 14 days when the report is confirmed actionable

## Scope

Security-sensitive issues include:

- Unexpected persistent `pmset` changes
- Privilege escalation concerns
- Unsafe AppleScript or shell execution paths
- Release artifact tampering concerns
- Malicious or unintended launch-at-login behavior

Non-security product bugs should go through the normal GitHub issue tracker.
