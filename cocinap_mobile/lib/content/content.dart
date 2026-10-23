/// Contenido bilingüe (Español / Inglés) para la app: manual, guía y términos.
library;

/// Define una cadena con variantes en español e inglés.
class TextPair {
  final String es;
  final String en;
  const TextPair(this.es, this.en);
}

/// Devuelve la cadena en el idioma indicado.
String _l(TextPair t, String lang) => lang == "en" ? t.en : t.es;

/// Manual de uso de la app (español e inglés).
class AppManual {
  static const List<TextPair> sections = [
    TextPair(
      "Modo independiente (cámara del móvil o IP)",
      "Standalone mode (phone or IP camera)",
    ),
    TextPair(
      "En el modo independiente la app monitorea tu cocina usando la cámara del "
      "móvil o una cámara de seguridad. Configura un temporizador: mientras esté "
      "activo, la app detecta si hay una persona presente. Si nadie está en la "
      "cocina durante el tiempo configurado, se avisa de inmediato.\n\n"
      "Pasos:\n"
      "1. Abre la pestaña 'Monitoreo'.\n"
      "2. Si usas una cámara IP, conéctala primero (ver 'Guía de cámaras').\n"
      "3. Toca 'Iniciar monitoreo' y elige los minutos.\n"
      "4. La app avisará si la cocina queda desatendida.\n"
      "5. Toca 'Parar' para detener el monitoreo.",
      "In standalone mode the app monitors your kitchen using the phone camera "
      "or a security camera. Set a timer: while it is active, the app detects "
      "whether a person is present. If no one is in the kitchen for the "
      "configured time, you will be alerted immediately.\n\n"
      "Steps:\n"
      "1. Open the 'Monitoring' tab.\n"
      "2. If using an IP camera, connect it first (see 'Camera guide').\n"
      "3. Tap 'Start monitoring' and choose the minutes.\n"
      "4. The app will alert you if the kitchen is left unattended.\n"
      "5. Tap 'Stop' to end monitoring.",
    ),
    TextPair(
      "Conectar al ordenador",
      "Connecting to the computer",
    ),
    TextPair(
      "La app también puede recibir el monitoreo desde tu ordenador CocinaP. "
      "Escanea el código QR que muestra el programa, o conéctate manualmente "
      "ingresando la dirección y la API key. Verás la cámara del PC, las alarmas "
      "y podrás controlar la configuración de forma remota.",
      "The app can also receive monitoring from your CocinaP computer. Scan the "
      "QR code shown by the program, or connect manually by entering the "
      "address and API key. You will see the PC camera, alarms, and can control "
      "the configuration remotely.",
    ),
    TextPair(
      "Configuración",
      "Settings",
    ),
    TextPair(
      "En 'Ajustes' puedes configurar la duración del monitoreo, el tiempo para "
      "considerar la cocina desatendida, el tiempo peligroso, la confianza de "
      "detección y la fuente de cámara. También puedes activar la "
      "auto-conexión al ordenador.",
      "In 'Settings' you can configure the monitoring duration, the time to "
      "consider the kitchen unattended, the danger time, the detection "
      "confidence and the camera source. You can also enable auto-connection "
      "to the computer.",
    ),
    TextPair(
      "Alertas y notificaciones",
      "Alerts and notifications",
    ),
    TextPair(
      "Cuando la cocina queda desatendida, la app avisa con una notificación "
      "local con sonido y vibración, y la repite cada cierto tiempo mientras "
      "sigas fuera. En Android funciona con la app en segundo plano; en iOS, "
      "con la app abierta.",
      "When the kitchen is left unattended, the app alerts you with a local "
      "notification with sound and vibration, and repeats it every so often "
      "while you are away. On Android it works with the app in the background; "
      "on iOS, with the app open.",
    ),
  ];

  static List<String> texts(String lang) {
    return sections.map((s) => _l(s, lang)).toList();
  }
}

/// Guía para conectar cámaras del hogar o de seguridad (español e inglés).
class CameraGuide {
  static const List<TextPair> steps = [
    TextPair(
      "Encuentra la URL HTTP/MJPEG de tu cámara",
      "Find your camera HTTP/MJPEG URL",
    ),
    TextPair(
      "La mayoría de cámaras de seguridad tienen un stream MJPEG por HTTP. "
      "Busca en el manual o con la herramienta ONVIF Device Manager. Suelen ser: "
      "http://IP/video.cgi?resolution=640x360, http://IP/stream, "
      "http://IP:port/video/mjpg.cgi, http://IP/snapshot.cgi. Puedes probar en "
      "el navegador o con VLC (Medio → Abrir URL de red).",
      "Most security cameras have an MJPEG stream over HTTP. Look in the manual "
      "or use the ONVIF Device Manager tool. They are usually: "
      "http://IP/video.cgi?resolution=640x360, http://IP/stream, "
      "http://IP:port/video/mjpg.cgi, http://IP/snapshot.cgi. You can test in "
      "the browser or with VLC (Media → Open Network Stream).",
    ),
    TextPair(
      "Añade credenciales si las necesita",
      "Add credentials if needed",
    ),
    TextPair(
      "Muchas cámaras piden usuario y contraseña en la URL: "
      "http://usuario:contraseña@IP/stream. Cambia la contraseña por defecto "
      "antes de usar la cámara.",
      "Many cameras require a username and password in the URL: "
      "http://user:password@IP/stream. Change the default password before "
      "using the camera.",
    ),
    TextPair(
      "Configura la cámara IP en Ajustes",
      "Configure the IP camera in Settings",
    ),
    TextPair(
      "En 'Ajustes', en 'Fuente de cámara', elige 'Cámara IP (hogar/seguridad)' "
      "y pega la URL HTTP/MJPEG. Vuelve a 'Monitoreo' y deberías ver la imagen.",
      "In 'Settings', under 'Camera source', choose 'IP camera (home/security)' "
      "and paste the HTTP/MJPEG URL. Go back to 'Monitoring' and you should see "
      "the image.",
    ),
  ];

  static List<String> texts(String lang) {
    return steps.map((s) => _l(s, lang)).toList();
  }
}

/// Términos y condiciones de la app (español e inglés).
class AppTerms {
  static const List<TextPair> sections = [
    TextPair(
      "Uso responsable",
      "Responsible use",
    ),
    TextPair(
      "CocinaP es una herramienta de ayuda para la seguridad en la cocina. "
      "No sustituye la supervisión humana. No dejes ollas ni fuego encendido "
      "cerca de superficies inflamables y revisa tu cocina regularmente.",
      "CocinaP is an aid tool for kitchen safety. It does not replace human "
      "supervision. Do not leave pots or fire near flammable surfaces and "
      "check your kitchen regularly.",
    ),
    TextPair(
      "Privacidad y datos",
      "Privacy and data",
    ),
    TextPair(
      "Las imágenes de las cámaras se procesan en tu dispositivo y no se "
      "suben a servidores externos salvo que configures notificaciones push. "
      "El modelo de detección se ejecuta localmente. Los datos de "
      "configuración se guardan únicamente en tu dispositivo.",
      "Camera images are processed on your device and are not uploaded to "
      "external servers unless you configure push notifications. The detection "
      "model runs locally. Configuration data is stored only on your device.",
    ),
    TextPair(
      "Responsabilidad del usuario",
      "User responsibility",
    ),
    TextPair(
      "Eres responsable de la seguridad física de tu hogar. CocinaP ofrece "
      "avisos, pero no puede evitar un incendio ni actuar por ti. Mantén "
      "extintores, detectores de humo y medidas de prevención vigentes.",
      "You are responsible for the physical safety of your home. CocinaP "
      "provides alerts but cannot prevent a fire or act on your behalf. Keep "
      "fire extinguishers, smoke detectors and prevention measures in place.",
    ),
    TextPair(
      "Cámaras de terceros",
      "Third-party cameras",
    ),
    TextPair(
      "Al conectar cámaras de terceros, solo usas sus streams para analizar "
      "la presencia de personas. Asegúrate de tener permiso para usar las "
      "cámaras y cumple las leyes de privacidad locales.",
      "When connecting third-party cameras, you only use their streams to "
      "analyze people presence. Make sure you have permission to use the "
      "cameras and comply with local privacy laws.",
    ),
    TextPair(
      "Aceptación",
      "Acceptance",
    ),
    TextPair(
      "Al usar la app aceptas estos términos y condiciones.",
      "By using the app you accept these terms and conditions.",
    ),
  ];

  static List<String> texts(String lang) {
    return sections.map((s) => _l(s, lang)).toList();
  }
}

/// Información general de la app para la pantalla de bienvenida (ES/EN).
class GeneralInfo {
  static const String titleEs = "Bienvenido a CocinaP";
  static const String titleEn = "Welcome to CocinaP";
  static const String subtitleEs = "Tu vigilante de cocina inteligente";
  static const String subtitleEn = "Your smart kitchen watchdog";
  static const String introEs =
      "CocinaP vigila tu cocina y te avisa si queda desatendida. Funciona solo "
      "con la cámara de tu móvil o con una cámara IP, y detecta personas en el "
      "propio dispositivo, sin enviar imágenes a internet.";
  static const String introEn =
      "CocinaP watches your kitchen and alerts you if it is left unattended. It "
      "works with just your phone camera or an IP camera, and detects people on "
      "the device itself, without sending images to the internet.";

  /// Puntos destacados que se muestran como tarjetas en la bienvenida.
  static const List<TextPair> points = [
    TextPair(
      "Modo independiente",
      "Standalone mode",
    ),
    TextPair(
      "Monitorea con la cámara del móvil o una cámara de seguridad. No "
      "necesitas ningún equipo extra.",
      "Monitor with your phone camera or a security camera. No extra equipment "
      "needed.",
    ),
    TextPair(
      "Detección en el dispositivo",
      "On-device detection",
    ),
    TextPair(
      "El modelo de personas se ejecuta en tu teléfono. Las imágenes no salen "
      "de tu dispositivo.",
      "The people model runs on your phone. Images never leave your device.",
    ),
    TextPair(
      "Alertas claras",
      "Clear alerts",
    ),
    TextPair(
      "Si nadie está en la cocina durante el tiempo configurado, recibes un "
      "aviso con sonido y vibración.",
      "If no one is in the kitchen for the configured time, you get an alert "
      "with sound and vibration.",
    ),
    TextPair(
      "Conecta tu PC (opcional)",
      "Connect your PC (optional)",
    ),
    TextPair(
      "Si tienes la versión de ordenador, escanea su código QR para ver la "
      "cámara del PC y las alarmas de fuego y humo.",
      "If you have the computer version, scan its QR code to see the PC camera "
      "and fire/smoke alarms.",
    ),
  ];

  static List<String> pointTexts(String lang) =>
      points.map((p) => _l(p, lang)).toList();

  static String title(String lang) => lang == "en" ? titleEn : titleEs;
  static String subtitle(String lang) => lang == "en" ? subtitleEn : subtitleEs;
  static String intro(String lang) => lang == "en" ? introEn : introEs;
}

/// Pasos para usar el móvil como cámara de vigilancia (ES/EN).
class PhoneCameraGuide {
  static const List<TextPair> steps = [
    TextPair(
      "Abre la pestaña 'Monitoreo'",
      "Open the 'Monitoring' tab",
    ),
    TextPair(
      "En 'Ajustes → Fuente de cámara' deja seleccionada la opción 'Cámara del "
      "móvil'. La app usará la cámara trasera del teléfono.",
      "In 'Settings → Camera source' keep 'Phone camera' selected. The app will "
      "use the phone's rear camera.",
    ),
    TextPair(
      "Apunta el móvil a la cocina y la estufa",
      "Aim the phone at the kitchen and stove",
    ),
    TextPair(
      "Apóyalo en un estante, trípode o soporte mirando a la zona de cocción. "
      "Puedes seguir la guía de colocación de la cámara.",
      "Prop it on a shelf, tripod or mount facing the cooking area. You can "
      "follow the camera placement guide.",
    ),
    TextPair(
      "Concede el permiso de cámara",
      "Grant the camera permission",
    ),
    TextPair(
      "La primera vez el sistema pedirá permiso para usar la cámara. Acéptalo "
      "para que la vista en vivo funcione.",
      "The first time, the system will ask for camera permission. Accept it so "
      "the live view works.",
    ),
    TextPair(
      "Inicia el monitoreo",
      "Start monitoring",
    ),
    TextPair(
      "Toca 'Iniciar monitoreo' y elige los minutos. Deja la app abierta en la "
      "pestaña 'Monitoreo' y conecta el móvil a la corriente.",
      "Tap 'Start monitoring' and choose the minutes. Keep the app open on the "
      "'Monitoring' tab and plug the phone into power.",
    ),
  ];

  static List<String> texts(String lang) =>
      steps.map((s) => _l(s, lang)).toList();
}

/// Privacidad y permisos explicados al usuario (ES/EN).
class PrivacyInfo {
  static const List<TextPair> sections = [
    TextPair(
      "Procesamiento local",
      "Local processing",
    ),
    TextPair(
      "Todas las imágenes se analizan en tu dispositivo. CocinaP no las sube a "
      "servidores externos y no necesita conexión a internet para el modo "
      "independiente.",
      "All images are analyzed on your device. CocinaP does not upload them to "
      "external servers and does not need an internet connection for standalone "
      "mode.",
    ),
    TextPair(
      "Permisos que se solicitan",
      "Permissions requested",
    ),
    TextPair(
      "· Cámara: para ver la cocina en vivo.\n"
      "· Notificaciones: para avisarte cuando la cocina quede desatendida.\n"
      "· Red local: solo si conectas una cámara IP o tu PC.",
      "· Camera: to see the kitchen live.\n"
      "· Notifications: to alert you when the kitchen is left unattended.\n"
      "· Local network: only if you connect an IP camera or your PC.",
    ),
    TextPair(
      "Tus datos",
      "Your data",
    ),
    TextPair(
      "La configuración (duración, cámara, etc.) se guarda únicamente en tu "
      "teléfono. Puedes borrarla desinstalando la app.",
      "Settings (duration, camera, etc.) are stored only on your phone. You can "
      "clear them by uninstalling the app.",
    ),
  ];

  static List<String> texts(String lang) =>
      sections.map((s) => _l(s, lang)).toList();
}

/// Gestor simple del idioma de la app (español por defecto).
class AppLocal {
  static String language = "es";

  static void setLanguage(String lang) {
    language = lang == "en" ? "en" : "es";
  }
}

/// Instrucciones para colocar físicamente la cámara de seguridad y lograr un
/// buen monitoreo de la cocina (español e inglés).
class CameraInstallGuide {
  static const String titleEs = "Coloca tu cámara de seguridad";
  static const String titleEn = "Place your security camera";
  static const String introEs =
      "Para que el monitoreo funcione bien, la cámara debe ver la cocina y la "
      "zona de la estufa. Sigue estos pasos la primera vez que configures el "
      "sistema:";
  static const String introEn =
      "For monitoring to work well, the camera must see the kitchen and the "
      "stove area. Follow these steps the first time you set up the system:";

  static const List<TextPair> steps = [
    TextPair(
      "Elige un buen lugar",
      "Choose a good spot",
    ),
    TextPair(
      "Coloca la cámara en alto, en una esquina o contra un mueble, de modo que "
      "tenga una vista despejada de la cocina y, sobre todo, de la estufa y la "
      "encimera donde cocinas. Evita que quede muy cerca de ventanas o luces "
      "directas que cegarían al detector.",
      "Place the camera high up, in a corner or against a cabinet, so it has a "
      "clear view of the kitchen and, above all, of the stove and the counter "
      "where you cook. Avoid placing it too close to windows or direct lights "
      "that would blind the detector.",
    ),
    TextPair(
      "Altura y ángulo",
      "Height and angle",
    ),
    TextPair(
      "Una altura de 2 a 2.4 metros con el lente apuntando ligeramente hacia "
      "abajo suele dar el mejor resultado: ve de frente y de arriba todo lo que "
      "pasa en la estufa. Si la cámara queda a ras, la persona puede quedar "
      "cubierta u ocluida por muebles.",
      "A height of 2 to 2.4 meters with the lens pointing slightly downward "
      "usually gives the best result: it sees head-on and from above everything "
      "that happens at the stove. If the camera is at counter level, a person "
      "can be hidden or occluded by furniture.",
    ),
    TextPair(
      "Campo de visión hacia la estufa",
      "Field of view toward the stove",
    ),
    TextPair(
      "Asegúrate de que la estufa quede dentro del campo de visión en el centro "
      "de la imagen. Si la cocina es recta o de pasillo, apunta a lo largo del "
      "mueble. No apuntes hacia una puerta o pasillo vacío: la cámara debe vigilar "
      "la zona de riesgo y donde aparece la persona.",
      "Make sure the stove is within the field of view, centered in the image. "
      "If the kitchen is straight or a galley, aim along the cabinets. Do not "
      "point at an empty door or hallway: the camera must watch the risk zone "
      "and where the person appears.",
    ),
    TextPair(
      "Iluminación",
      "Lighting",
    ),
    TextPair(
      "Evita contraluz y sombras fuertes. El detector funciona mejor con luz "
      "uniforme. Si hay poca luz, usa el modo nocturno o infrarrojo de la cámara "
      "y evita focos que apunten directo al lente.",
      "Avoid backlighting and strong shadows. The detector works best with even "
      "light. If there is little light, use the camera's night mode or "
      "infrared and avoid lamps pointing directly at the lens.",
    ),
    TextPair(
      "Sin obstrucciones",
      "No obstructions",
    ),
    TextPair(
      "Retira ollas, paños, plantas o adornos que puedan tapar la vista parcial de "
      "la cámara. Limpia el lente periódicamente y fija bien el cable o el soporte "
      "para que no se mueva con el tiempo.",
      "Remove pots, cloths, plants or decorations that could partially block the "
      "camera view. Clean the lens periodically and secure the cable or mount so "
      "it does not move over time.",
    ),
    TextPair(
      "Si usas el móvil como cámara",
      "If you use your phone as a camera",
    ),
    TextPair(
      "Puedes apoyar el móvil en un estante, o colocarlo en un trípode o soporte "
      "de repisa apuntando a la estufa. Conéctalo a la corriente para que la "
      "batería no se agote durante el monitoreo y deja la app abierta en la "
      "pestaña 'Monitoreo'.",
      "You can prop your phone on a shelf, or place it on a tripod or shelf "
      "mount pointing at the stove. Plug it in so the battery does not drain "
      "during monitoring and keep the app open on the 'Monitoring' tab.",
    ),
  ];

  static List<String> texts(String lang) {
    return steps.map((s) => _l(s, lang)).toList();
  }

  static String title(String lang) =>
      lang == "en" ? titleEn : titleEs;

  static String intro(String lang) =>
      lang == "en" ? introEn : introEs;
}

/// Etiquetas de las pestañas de navegación (ES/EN).
class NavLabels {
  static String home(String l) => l == "en" ? "Home" : "Inicio";
  static String monitoring(String l) => l == "en" ? "Monitoring" : "Monitoreo";
  static String connect(String l) => l == "en" ? "Connect" : "Conectar";
  static String alarms(String l) => l == "en" ? "Alarms" : "Alarmas";
  static String settings(String l) => l == "en" ? "Settings" : "Ajustes";
}

/// Textos de la pantalla de inicio (dashboard gráfico) (ES/EN).
class HomeTexts {
  static const _taglineEs = "Tu vigilante de cocina inteligente";
  static const _taglineEn = "Your smart kitchen watchdog";

  static String taglineOf(String l) => l == "en" ? _taglineEn : _taglineEs;

  static String greeting(String l) => l == "en" ? "Overview" : "Resumen";
  static String statusTitle(String l) =>
      l == "en" ? "Monitoring status" : "Estado del monitoreo";
  static String objectivesTitle(String l) =>
      l == "en" ? "CocinaP objectives" : "Objetivos de CocinaP";
  static String howTitle(String l) => l == "en" ? "How it works" : "Cómo funciona";
  static String privacyTitle(String l) =>
      l == "en" ? "Privacy" : "Privacidad";
  static String aboutTitle(String l) => l == "en" ? "About the app" : "Acerca de la app";
  static String setupTitle(String l) =>
      l == "en" ? "Your setup" : "Tu configuración";

  static String statTimer(String l) => l == "en" ? "Timer" : "Temporizador";
  static String statRemaining(String l) => l == "en" ? "Remaining" : "Restante";
  static String statPerson(String l) => l == "en" ? "Person" : "Persona";
  static String statCamera(String l) => l == "en" ? "Camera" : "Cámara";
  static String statPc(String l) => l == "en" ? "PC" : "PC";

  static String yes(String l) => l == "en" ? "Yes" : "Sí";
  static String no(String l) => l == "en" ? "No" : "No";
  static String active(String l) => l == "en" ? "Active" : "Activo";
  static String inactive(String l) => l == "en" ? "Inactive" : "Inactivo";
  static String connected(String l) => l == "en" ? "Connected" : "Conectado";
  static String disconnected(String l) => l == "en" ? "Not connected" : "Sin conexión";

  static String ready(String l) =>
      l == "en" ? "Ready to protect your kitchen" : "Listo para proteger tu cocina";
  static String monitoring(String l) =>
      l == "en" ? "Monitoring active" : "Monitoreo activo";
  static String personAway(String l) =>
      l == "en" ? "No person detected" : "Sin persona detectada";

  static String btnStart(String l) =>
      l == "en" ? "Start monitoring" : "Iniciar monitoreo";
  static String btnOpenMonitoring(String l) =>
      l == "en" ? "Open monitoring" : "Abrir monitoreo";
  static String btnOpenPc(String l) =>
      l == "en" ? "View PC camera" : "Ver cámara del PC";
  static String btnConnectPc(String l) =>
      l == "en" ? "Connect to PC" : "Conectar al PC";
  static String replayTour(String l) =>
      l == "en" ? "Replay interface tour" : "Repetir tour de la interfaz";

  static String setupCameraDone(String l) =>
      l == "en" ? "Camera configured" : "Cámara configurada";
  static String setupCameraPending(String l) =>
      l == "en" ? "Choose a camera source" : "Elige una fuente de cámara";
  static String setupHints(String l) =>
      l == "en" ? "Notifications on" : "Notificaciones activas";
  static String setupLanguage(String l) =>
      l == "en" ? "Language selected" : "Idioma seleccionado";
}

/// Objetivos de la app, mostrados como tarjetas gráficas (ES/EN).
class AppObjectives {
  static const List<TextPair> items = [
    TextPair(
      "Prevenir descuidos en la cocina",
      "Prevent kitchen mishaps",
    ),
    TextPair(
      "Vigila si dejas la cocina desatendida con ollas o fuego encendido y te "
      "avisa antes de que sea un riesgo.",
      "Watches over your kitchen if you leave it unattended with pots or open "
      "fire, and alerts you before it becomes a risk.",
    ),
    TextPair(
      "Avisar a tiempo",
      "Alert on time",
    ),
    TextPair(
      "Detecta la ausencia de personas durante el tiempo que configures y lanza "
      "una notificación clara con sonido y vibración.",
      "Detects the absence of people for the time you set and fires a clear "
      "notification with sound and vibration.",
    ),
    TextPair(
      "Privacidad por diseño",
      "Privacy by design",
    ),
    TextPair(
      "Todo el análisis se hace en tu dispositivo. Tus imágenes no se suben a "
      "internet ni pasan por servidores externos.",
      "All analysis runs on your device. Your images are never uploaded to the "
      "internet or sent to external servers.",
    ),
    TextPair(
      "Fácil de usar",
      "Easy to use",
    ),
    TextPair(
      "Funciona solo con la cámara de tu móvil, sin equipos extra, con una "
      "interfaz clara y guías paso a paso.",
      "Works with just your phone camera, no extra gear, with a clear interface "
      "and step-by-step guides.",
    ),
  ];

  static List<String> texts(String lang) =>
      items.map((t) => _l(t, lang)).toList();
}

/// Pasos de "cómo funciona" mostrados como línea de tiempo (ES/EN).
class AppHowItWorks {
  static const List<TextPair> steps = [
    TextPair(
      "Detecta personas",
      "Detects people",
    ),
    TextPair(
      "La cámara del móvil o tu cámara IP observa la cocina y el modelo de "
      "inteligencia artificial reconoce si hay una persona, todo en el "
      "dispositivo.",
      "Your phone camera or IP camera watches the kitchen and the AI model "
      "recognizes whether a person is present, all on the device.",
    ),
    TextPair(
      "Cuenta el tiempo",
      "Counts the time",
    ),
    TextPair(
      "Al iniciar el monitoreo, la app cuenta cuánto tiempo pasa sin ver a "
      "nadie en la cocina.",
      "When monitoring starts, the app counts how long it has been since anyone "
      "was seen in the kitchen.",
    ),
    TextPair(
      "Te avisa",
      "Alerts you",
    ),
    TextPair(
      "Si nadie aparece durante el tiempo configurado, recibes una notificación "
      "con sonido y vibración, y se repite mientras sigas fuera.",
      "If no one shows up for the configured time, you get a notification with "
      "sound and vibration, repeated while you are still away.",
    ),
  ];

  static List<String> texts(String lang) =>
      steps.map((t) => _l(t, lang)).toList();
}

/// Datos técnicos "acerca de la app" (ES/EN). Los valores los aporta la UI.
class AppInfo {
  static String versionLabel(String l) => l == "en" ? "Version" : "Versión";
  static String techLabel(String l) => l == "en" ? "Built with" : "Tecnología";
  static String modelLabel(String l) => l == "en" ? "AI model" : "Modelo de IA";
  static String privacyLabel(String l) =>
      l == "en" ? "Data processing" : "Procesamiento";
  static String privacyValue(String l) => l == "en" ? "100% on-device" : "100% en el dispositivo";
  static String platformLabel(String l) => l == "en" ? "Platform" : "Plataforma";
}

/// Un paso del tour guiado de la interfaz.
class TourStep {
  /// Índice de la pestaña a resaltar, o null para una tarjeta central.
  final int? tabIndex;
  final String title;
  final String body;
  const TourStep(this.title, this.body, [this.tabIndex]);
}

/// Tour guiado de la interfaz que explica las opciones principales (ES/EN).
class AppTour {
  static const List<TextPair> _titles = [
    TextPair("Bienvenido al tour", "Welcome to the tour"),
    TextPair("Inicio", "Home"),
    TextPair("Monitoreo", "Monitoring"),
    TextPair("Conectar", "Connect"),
    TextPair("Alarmas", "Alarms"),
    TextPair("Ajustes", "Settings"),
  ];

  static const List<TextPair> _bodies = [
    TextPair(
      "Vamos a repasar la interfaz en unos segundos. Usa 'Siguiente' y 'Atrás' "
      "para moverte; toca 'Saltar' si ya la conoces.",
      "We'll walk through the interface in a few seconds. Use 'Next' and 'Back' "
      "to move; tap 'Skip' if you already know it.",
    ),
    TextPair(
      "Aquí ves el resumen: el estado del monitoreo, estadísticas, los objetivos "
      "de CocinaP y cómo funciona. Es tu punto de partida.",
      "Here you see the overview: monitoring status, statistics, CocinaP's "
      "objectives and how it works. This is your starting point.",
    ),
    TextPair(
      "Vigila tu cocina con la cámara del móvil o una cámara IP. Inicia el "
      "temporizador y la app te avisa si nadie está en la cocina.",
      "Watch your kitchen with the phone camera or an IP camera. Start the timer "
      "and the app alerts you if no one is in the kitchen.",
    ),
    TextPair(
      "Conecta la versión de ordenador escaneando su código QR o de forma "
      "manual. También configuras aquí la cámara IP.",
      "Connect the computer version by scanning its QR code or manually. You "
      "also set up the IP camera here.",
    ),
    TextPair(
      "Consulta el historial de alarmas: fuego, humo y cocina desatendida, con "
      "la hora de cada aviso.",
      "Review the alarm history: fire, smoke and unattended kitchen, with the "
      "time of each alert.",
    ),
    TextPair(
      "Ajusta duración, tiempos de aviso, sensibilidad, idioma y más. También "
      "puedes repetir este tour cuando quieras.",
      "Adjust duration, alert times, sensitivity, language and more. You can "
      "also replay this tour anytime.",
    ),
  ];

  static int get totalSteps => _titles.length;

  static int? tabIndexAt(int step) {
    switch (step) {
      case 1:
        return 0; // Inicio
      case 2:
        return 1; // Monitoreo
      case 3:
      case 4:
        return 0; // Inicio: conexión e historial están dentro de Inicio
      case 5:
        return 2; // Ajustes
      default:
        return null;
    }
  }

  static List<TourStep> steps(String lang) {
    return List<TourStep>.generate(_titles.length, (i) {
      final tab = tabIndexAt(i);
      return TourStep(_l(_titles[i], lang), _l(_bodies[i], lang), tab);
    });
  }
}