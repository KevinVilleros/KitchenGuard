# Documentación de CocinaP

Índice central de la documentación del proyecto **CocinaP** (aplicación móvil
Flutter + backend Python/YOLO). Toda la documentación está disponible en
**español** (`docs/es/`) e **inglés** (`docs/en/`).

---

## Índice por idioma

### Español

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

---

## Documentos en la raíz del repositorio

| Documento | Idioma | Descripción |
|---|---|---|
| [README.md](../README.md) | ES | Presentación del proyecto |
| [CHANGELOG.md](../CHANGELOG.md) | ES | Historial de versiones |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | ES | Guía de contribución |
| [SECURITY.md](../SECURITY.md) | ES | Política de reporte de vulnerabilidades |
| [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) | ES | Código de conducta |
| [LICENSE](../LICENSE) | ES | Licencia comercial |
| [docs/legal/](legal/) | ES/EN | Política de privacidad |
| [INSTALL_IOS_WINDOWS.es.md](INSTALL_IOS_WINDOWS.es.md) | ES | Compilar iOS desde Windows con GitHub Actions |
| [yolo/README.md](../yolo/README.md) | ES | Backend Python/YOLO |

---

## Convenciones

- **Idiomas:** cada documento tiene su versión `es/` y `en/`. La versión en
  español es la de referencia.
- **Formato:** Markdown. Los diagramas usan bloques de código ASCII o Mermaid.
- **Actualización:** al cambiar el comportamiento del software, actualiza la
  documentación correspondiente y el [CHANGELOG](../CHANGELOG.md).
- **Sin emojis:** la documentación del proyecto no usa emojis.
