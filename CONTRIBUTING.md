# Guia de Contribucion

Gracias por tu interes en contribuir a **CocinaP**. Este es un proyecto comercial
y el codigo fuente no esta abierto a contribuciones externas sin autorizacion previa.

---

## Reportar Issues

Si encontraste un bug o tenes una sugerencia:

1. Verifica que el issue no exista ya en [GitHub Issues](https://github.com/KevinVilleros/KitchenGuard/issues)
2. Usa la plantilla de bug report o feature request
3. Incluye:
   - Version de CocinaP (se ve en Acerca de)
   - Sistema operativo (Windows 10/11)
   - Pasos para reproducir el bug
   - Logs de error (en `%APPDATA%\CocinaP\logs\crash.log`)
   - Capturas de pantalla si aplica

---

## Proceso de Desarrollo

1. Fork del repositorio (solo para contributors autorizados)
2. Crear rama: `git checkout -b feature/nombre-corto`
3. Commits con mensajes descriptivos en espanol
4. Hacer lint del codigo antes de commit:

```bash
# Python
ruff check cocinap/
ruff format cocinap/

# Flutter
cd cocinap_mobile && flutter analyze
```

5. Ejecutar tests:

```bash
pytest
```

6. Crear Pull Request a la rama `develop`

---

## Estandares de Codigo

### Python

- **Style:** PEP 8, enforced by Ruff
- **Line length:** 120 characters max
- **Type hints:** required on all public functions
- **Naming:** English for code, Spanish for UI/user-facing strings
- **Tests:** pytest, one test file per module in `tests/`

### Flutter / Dart

- **Linting:** `flutter_lints` configurado
- **State management:** Provider (no BLoC)
- **Naming:** English for code, Spanish for UI

---

## Estructura de Commits

```
<tipo>: <descripcion corta en espanol>

Tipos:
  feat     Nueva funcionalidad
  fix      Correccion de bug
  docs     Documentacion
  style    Formato (sin cambio de logica)
  refactor Refactorizacion
  test     Tests
  build    Build o dependencias
  ci       Configuracion de CI
```

Ejemplo:
```
feat: agregar alarma sonora para humo
fix: corregir cobertura de fuego en baja resolucion
```

---

## Licencia

Al contribuir, aceptas que tu codigo pasa a ser propiedad de CocinaP y
estara sujeto a los terminos de la [licencia comercial](LICENSE).
