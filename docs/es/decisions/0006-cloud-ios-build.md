# ADR 0006 — Compilar iOS en la nube con GitHub Actions

## Estado
Aceptada

## Contexto

Compilar un `.ipa` para iOS requiere macOS con Xcode, pero el desarrollo se
realiza en Windows.

## Decisión

Generar el `.ipa` **en la nube** con un workflow de **GitHub Actions**
(`.github/workflows/ios.yml`, runner `macos-latest`). El workflow produce un
`.ipa` **sin firmar** que se instala con **Sideloadly**. También existe un job
opcional de firma si se configuran los secretos de certificado.

## Consecuencias

**Positivas**
- No se necesita un Mac propio.
- La compilación es reproducible y automatizable.
- El `.ipa` sin firmar es suficiente para pruebas con Sideloadly.

**Negativas**
- El `.ipa` con cuenta gratuita de Sideloadly **expira a los 7 días**.
- Dependencia de los minutos de CI de GitHub.

**Neutrales**
- El workflow se dispara al hacer push a `main` con cambios en `cocinap_mobile/**`
  o manualmente.
