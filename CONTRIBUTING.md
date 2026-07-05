# Guía de Contribución

Gracias por tu interés en contribuir a **CocinaP**. Este es un proyecto comercial
y el código fuente no está abierto a contribuciones externas sin autorización previa.

## Reportar Issues

Si encontraste un bug o tenés una sugerencia:

1. Verificá que el issue no exista ya en [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues)
2. Usá la plantilla de bug report o feature request
3. Incluí:
   - Versión de CocinaP (se ve en Acerca de)
   - Sistema operativo (Windows 10/11)
   - Pasos para reproducir el bug
   - Logs de error (en `%APPDATA%\CocinaP\logs\crash.log`)
   - Capturas de pantalla si aplica

## Proceso de Desarrollo

1. Fork del repositorio (solo para contributors autorizados)
2. Crear rama: `git checkout -b feature/nombre-corto`
3. Commits con mensajes descriptivos en español
4. Hacer lint del código antes de commit:
   ```bash
   ruff check cocinap/    # Python
   cd cocinap_mobile && flutter analyze  # Flutter
   ```
5. Crear Pull Request a la rama `develop`

## Estándares de Código

### Python
- PEP 8
- Ruff para linting
- Type hints en funciones públicas
- Nombres en inglés para código, español para UI/user-facing strings

### Flutter/Dart
- flutter_lints configurado
- Provider para estado (no BLoC)
- Nombres en inglés para código, español para UI

## Licencia

Al contribuir, aceptás que tu código pasa a ser propiedad de CocinaP y
estará sujeto a los términos de la [licencia comercial](LICENSE).
