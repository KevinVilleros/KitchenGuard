# CocinaP Documentation

Central documentation index for **CocinaP** (Flutter mobile application and
optional Python/YOLO backend). Documentation is available in **English**
(`docs/en/`) and **Spanish** (`docs/es/`). English is the repository-wide
default.

---

## Documentation by language

### English

| Document | Description |
|---|---|
| [Architecture](en/ARCHITECTURE.md) | Overview, components, data flow and diagrams |
| [Installation & build](en/INSTALLATION.md) | Requirements, environment, Android/iOS build and backend run |
| [User guide](en/USER_GUIDE.md) | Full guide for using the app and the system |
| [REST API reference](en/API.md) | Backend endpoints, authentication and examples |
| [Development guide](en/DEVELOPMENT.md) | Environment, conventions, structure and workflow |
| [Platform support](en/PLATFORM_SUPPORT.md) | Android, iPhone/iOS, QA matrix and release criteria |
| [Testing & CI/CD](en/TESTING.md) | Test strategy, workflows and releases |
| [Security](en/SECURITY.md) | Threat model, auth, rate limiting and best practices |
| [Troubleshooting](en/TROUBLESHOOTING.md) | Common errors and fixes (FAQ) |
| [Roadmap](en/ROADMAP.md) | Planned features and status |
| [Glossary](en/GLOSSARY.md) | Domain terms, acronyms and concepts |
| [Architecture decisions (ADR)](en/decisions/) | Technical decision records |

### Spanish

| Documento | Descripción |
|---|---|
| [Arquitectura](es/ARCHITECTURE.md) | Visión general, componentes, flujo de datos y diagramas |
| [Instalación y compilación](es/INSTALLATION.md) | Requisitos, entorno, build Android/iOS y ejecución del backend |
| [Manual de usuario](es/USER_GUIDE.md) | Guía completa de uso de la app y del sistema |
| [Referencia de API REST](es/API.md) | Endpoints, autenticación y ejemplos del backend |
| [Guía de desarrollo](es/DEVELOPMENT.md) | Entorno, convenciones, estructura y flujo de trabajo |
| [Soporte de plataformas](es/PLATFORM_SUPPORT.md) | Android, iPhone/iOS, matriz de QA y criterios de release |
| [Pruebas y CI/CD](es/TESTING.md) | Estrategia de pruebas, workflows y releases |
| [Seguridad](es/SECURITY.md) | Modelo de amenazas, auth, rate limiting y buenas prácticas |
| [Solución de problemas](es/TROUBLESHOOTING.md) | Errores frecuentes y cómo resolverlos (FAQ) |
| [Roadmap](es/ROADMAP.md) | Funcionalidades planificadas y estado |
| [Glosario](es/GLOSSARY.md) | Términos, siglas y conceptos del dominio |
| [Decisiones de arquitectura (ADR)](es/decisions/) | Registros de decisiones técnicas |

---

## Repository root documents

| Document | Language | Description |
|---|---|---|
| [README.md](../README.md) | EN | Project overview |
| [CHANGELOG.md](../CHANGELOG.md) | EN | Release history |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | EN | Contribution policy |
| [SECURITY.md](../SECURITY.md) | EN | Vulnerability reporting policy |
| [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) | EN | Community standards |
| [LICENSE](../LICENSE) | EN/ES | Commercial license |
| [Privacy policy](legal/PRIVACY_POLICY.en.md) | EN + ES | Local-processing privacy policy |
| [iOS from Windows](INSTALL_IOS_WINDOWS.es.md) | Spanish | Build and install with GitHub Actions |
| [Mobile app README](../cocinap_mobile/README.md) | EN + ES | Android and iPhone app |
| [Archived YOLO backend](../yolo/README.md) | EN + ES | Optional Python/Windows backend |

---

## Conventions

- **Languages:** English is the repository-wide primary language. Spanish is
  available under `docs/es/` and optional `.es.md` entry documents.
- **Format:** Markdown, with ASCII or Mermaid diagrams when needed.
- **Updates:** when behavior changes, update the matching English and Spanish
  documentation and [CHANGELOG.md](../CHANGELOG.md).
- **Style:** do not use emojis in project documentation.
