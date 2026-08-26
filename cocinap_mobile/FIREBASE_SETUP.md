Guía de configuración Firebase para CocinaP Mobile
====================================================

1. Crear proyecto Firebase
--------------------------
- Ir a https://console.firebase.google.com
- Crear proyecto (ej: "CocinaP")
- Registrar app Android (package: com.cocinap.mobile)
- Descargar google-services.json → copiar a:
  cocinap_mobile/android/app/google-services.json

- Registrar app iOS (bundle ID: com.cocinap.mobile)
- Descargar GoogleService-Info.plist → copiar a:
  cocinap_mobile/ios/Runner/GoogleService-Info.plist

2. Activar Firebase Cloud Messaging
-----------------------------------
- En Firebase Console → Cloud Messaging
- Enviar mensaje de prueba para verificar

3. Configurar servidor FCM
--------------------------
- En Firebase Console → Configuración del proyecto → Cuentas de servicio
- Generar nueva clave privada (Firebase Admin SDK)
- Guardar como: %APPDATA%/CocinaP/firebase-key.json
- En cocinap/config.py: ENABLE_FCM = True

4. Android: build.gradle
------------------------
En cocinap_mobile/android/build.gradle, agregar:
  dependencies {
      classpath 'com.google.gms:google-services:4.4.2'
  }

En cocinap_mobile/android/app/build.gradle:
  apply plugin: 'com.google.gms.google-services'
  (al final del archivo, después de apply plugin: 'com.android.application')

5. Probar
---------
flutter pub get
flutter run
