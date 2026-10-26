# Contributing to CocinaP

CocinaP is commercial software. Source code and contributions are restricted to
people or entities with prior written authorization.

## Reporting issues

Before opening an issue:

1. Search [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues).
2. Use a bug-report or feature-request template when one is available.
3. Include the CocinaP version, operating system, reproduction steps, relevant
   logs and screenshots when useful.

Do not publish API keys, passwords, personal data or other credentials.

## Development process

Authorized contributors should:

1. Fork or create a descriptive branch according to repository permissions.
2. Keep commits small and use imperative Conventional Commit prefixes such as
   `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `build:` or `ci:`.
3. Run static analysis and relevant tests before opening a pull request.
4. Describe the behavior changed, the validation performed and any limitations.

```bash
cd cocinap_mobile
flutter analyze
flutter test

cd ../yolo
ruff check .
ruff format --check .
pytest
```

## Code standards

### Python

- Follow Ruff and PEP 8 conventions.
- Keep public functions type annotated where practical.
- Use English identifiers and comments.
- Keep one focused pytest suite per module or behavior.

### Flutter and Dart

- Follow the configured `flutter_lints` rules.
- Use Provider for the existing state-management pattern unless a larger design
  decision changes it.
- Use English identifiers and comments; user-facing text belongs in bilingual
  `content.dart` strings.
- Format and analyze changed files before committing.

## Commit example

```text
feat: add smoke alert notification
fix: correct unattended-kitchen timer calculation
```

## License

Contributions are accepted only under the terms authorized by the repository
owner and are subject to the [commercial license](LICENSE).
