# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x | Yes |

## Report a vulnerability

Use GitHub private vulnerability reporting when enabled. Do not publish secrets,
proofs of concept, personal data or exploit details in public issues.

Otherwise, contact the repository owner privately by email:
**kevinvilleros77@gmail.com**.

Include:

- Affected version and platform.
- Reproduction steps.
- Impact and expected severity.
- Proof of concept only if necessary and safe to share privately.

Target response:

| Phase | Target |
|---|---|
| Initial acknowledgement | 48 hours |
| Impact assessment | 7 days |
| Fix development | 1-2 weeks |
| Coordinated release | Agreed with reporter |

## Security design

### Network

- The web server is intended for a trusted home LAN.
- Do not expose port `8080` to the Internet.
- Use a VPN or equivalent controlled connection for remote access.
- mDNS discovery works only on the local subnet.

### Data and credentials

- Configuration is stored under `%APPDATA%\CocinaP/config.json` on the PC.
- Event logs are stored under `%APPDATA%\CocinaP\logs\`.
- Non-sensitive mobile preferences use SharedPreferences.
- The API key is stored in Android Keystore/EncryptedSharedPreferences and iOS
  Keychain through secure storage.
- Legacy API keys are migrated once and removed from ordinary preferences.
- There is no configured cloud telemetry or image upload.

### Dependencies

- Flutter dependencies use `pubspec.yaml`; Python dependencies use
  `requirements.txt` and `pyproject.toml`.
- Update dependencies through reviewed Dependabot pull requests.
- Firebase Cloud Messaging is not part of the current mobile app.

## Operational practices

- Keep Windows, Android, iOS and Flutter/Android toolchains updated.
- Do not run the server as an administrator without a specific reason.
- Restrict port `8080` with the Windows firewall.
- Review security logs if unusual activity is observed.
- Keep backups outside the application directory where appropriate.
