/// Contenido bilingüe (Español / Inglés) para la app: manual, guía y términos.

/// Define una cadena con variantes en español e inglés.
class _T {
  final String es;
  final String en;
  const _T(this.es, this.en);
}

/// Devuelve la cadena en el idioma indicado.
String _l(_T t, String lang) => lang == "en" ? t.en : t.es;

/// Manual de uso de la app (español e inglés).
class AppManual {
  static const List<_T> sections = [
    const _T(
      "Modo independiente (cámara del móvil o IP)",
      "Standalone mode (phone or IP camera)",
    ),
    const _T(
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
    const _T(
      "Conectar al ordenador",
      "Connecting to the computer",
    ),
    const _T(
      "La app también puede recibir el monitoreo desde tu ordenador CocinaP. "
      "Escanea el código QR que muestra el programa, o conéctate manualmente "
      "ingresando la dirección y la API key. Verás la cámara del PC, las alarmas "
      "y podrás controlar la configuración de forma remota.",
      "The app can also receive monitoring from your CocinaP computer. Scan the "
      "QR code shown by the program, or connect manually by entering the "
      "address and API key. You will see the PC camera, alarms, and can control "
      "the configuration remotely.",
    ),
    const _T(
      "Configuración",
      "Settings",
    ),
    const _T(
      "En 'Ajustes' puedes configurar la duración del monitoreo, el tiempo para "
      "considerar la cocina desatendida, el tiempo peligroso, la confianza de "
      "detección y la fuente de cámara. También puedes activar la "
      "auto-conexión al ordenador.",
      "In 'Settings' you can configure the monitoring duration, the time to "
      "consider the kitchen unattended, the danger time, the detection "
      "confidence and the camera source. You can also enable auto-connection "
      "to the computer.",
    ),
    const _T(
      "Alertas y notificaciones",
      "Alerts and notifications",
    ),
    const _T(
      "Cuando la cocina queda desatendida, la app muestra una alerta local con "
      "sonido y vibración. Si está conectada al ordenador con notificaciones "
      "push (FCM), también recibes una notificación en el móvil.",
      "When the kitchen is left unattended, the app shows a local alert with "
      "sound and vibration. If connected to the computer with push "
      "notifications (FCM), you will also receive a notification on your phone.",
    ),
  ];

  static List<String> texts(String lang) {
    return sections.map((s) => _l(s, lang)).toList();
  }
}

/// Guía para conectar cámaras del hogar o de seguridad (español e inglés).
class CameraGuide {
  static const List<_T> steps = [
    const _T(
      "Encuentra la URL HTTP/MJPEG de tu cámara",
      "Find your camera HTTP/MJPEG URL",
    ),
    const _T(
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
    const _T(
      "Añade credenciales si las necesita",
      "Add credentials if needed",
    ),
    const _T(
      "Muchas cámaras piden usuario y contraseña en la URL: "
      "http://usuario:contraseña@IP/stream. Cambia la contraseña por defecto "
      "antes de usar la cámara.",
      "Many cameras require a username and password in the URL: "
      "http://user:password@IP/stream. Change the default password before "
      "using the camera.",
    ),
    const _T(
      "Configura la cámara IP en Ajustes",
      "Configure the IP camera in Settings",
    ),
    const _T(
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
  static const List<_T> sections = [
    const _T(
      "Uso responsable",
      "Responsible use",
    ),
    const _T(
      "CocinaP es una herramienta de ayuda para la seguridad en la cocina. "
      "No sustituye la supervisión humana. No dejes ollas ni fuego encendido "
      "cerca de superficies inflamables y revisa tu cocina regularmente.",
      "CocinaP is an aid tool for kitchen safety. It does not replace human "
      "supervision. Do not leave pots or fire near flammable surfaces and "
      "check your kitchen regularly.",
    ),
    const _T(
      "Privacidad y datos",
      "Privacy and data",
    ),
    const _T(
      "Las imágenes de las cámaras se procesan en tu dispositivo y no se "
      "suben a servidores externos salvo que configures notificaciones push. "
      "El modelo de detección se ejecuta localmente. Los datos de "
      "configuración se guardan únicamente en tu dispositivo.",
      "Camera images are processed on your device and are not uploaded to "
      "external servers unless you configure push notifications. The detection "
      "model runs locally. Configuration data is stored only on your device.",
    ),
    const _T(
      "Responsabilidad del usuario",
      "User responsibility",
    ),
    const _T(
      "Eres responsable de la seguridad física de tu hogar. CocinaP ofrece "
      "avisos, pero no puede evitar un incendio ni actuar por ti. Mantén "
      "extintores, detectores de humo y medidas de prevención vigentes.",
      "You are responsible for the physical safety of your home. CocinaP "
      "provides alerts but cannot prevent a fire or act on your behalf. Keep "
      "fire extinguishers, smoke detectors and prevention measures in place.",
    ),
    const _T(
      "Cámaras de terceros",
      "Third-party cameras",
    ),
    const _T(
      "Al conectar cámaras de terceros, solo usas sus streams para analizar "
      "la presencia de personas. Asegúrate de tener permiso para usar las "
      "cámaras y cumple las leyes de privacidad locales.",
      "When connecting third-party cameras, you only use their streams to "
      "analyze people presence. Make sure you have permission to use the "
      "cameras and comply with local privacy laws.",
    ),
    const _T(
      "Aceptación",
      "Acceptance",
    ),
    const _T(
      "Al usar la app aceptas estos términos y condiciones.",
      "By using the app you accept these terms and conditions.",
    ),
  ];

  static List<String> texts(String lang) {
    return sections.map((s) => _l(s, lang)).toList();
  }
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

  static const List<_T> steps = [
    const _T(
      "Elige un buen lugar",
      "Choose a good spot",
    ),
    const _T(
      "Coloca la cámara en alto, en una esquina o contra un mueble, de modo que "
      "tenga una vista despejada de la cocina y, sobre todo, de la estufa y la "
      "encimera donde cocinas. Evita que quede muy cerca de ventanas o luces "
      "directas que cegarían al detector.",
      "Place the camera high up, in a corner or against a cabinet, so it has a "
      "clear view of the kitchen and, above all, of the stove and the counter "
      "where you cook. Avoid placing it too close to windows or direct lights "
      "that would blind the detector.",
    ),
    const _T(
      "Altura y ángulo",
      "Height and angle",
    ),
    const _T(
      "Una altura de 2 a 2.4 metros con el lente apuntando ligeramente hacia "
      "abajo suele dar el mejor resultado: ve de frente y de arriba todo lo que "
      "pasa en la estufa. Si la cámara queda a ras, la persona puede quedar "
      "cubierta u ocluida por muebles.",
      "A height of 2 to 2.4 meters with the lens pointing slightly downward "
      "usually gives the best result: it sees head-on and from above everything "
      "that happens at the stove. If the camera is at counter level, a person "
      "can be hidden or occluded by furniture.",
    ),
    const _T(
      "Campo de visión hacia la estufa",
      "Field of view toward the stove",
    ),
    const _T(
      "Asegúrate de que la estufa quede dentro del campo de visión en el centro "
      "de la imagen. Si la cocina es recta o de pasillo, apunta a lo largo del "
      "mueble. No apuntes hacia una puerta o pasillo vacío: la cámara debe vigilar "
      "la zona de riesgo y donde aparece la persona.",
      "Make sure the stove is within the field of view, centered in the image. "
      "If the kitchen is straight or a galley, aim along the cabinets. Do not "
      "point at an empty door or hallway: the camera must watch the risk zone "
      "and where the person appears.",
    ),
    const _T(
      "Iluminación",
      "Lighting",
    ),
    const _T(
      "Evita contraluz y sombras fuertes. El detector funciona mejor con luz "
      "uniforme. Si hay poca luz, usa el modo nocturno o infrarrojo de la cámara "
      "y evita focos que apunten directo al lente.",
      "Avoid backlighting and strong shadows. The detector works best with even "
      "light. If there is little light, use the camera's night mode or "
      "infrared and avoid lamps pointing directly at the lens.",
    ),
    const _T(
      "Sin obstrucciones",
      "No obstructions",
    ),
    const _T(
      "Retira ollas, paños, plantas o adornos que puedan tapar la vista parcial de "
      "la cámara. Limpia el lente periódicamente y fija bien el cable o el soporte "
      "para que no se mueva con el tiempo.",
      "Remove pots, cloths, plants or decorations that could partially block the "
      "camera view. Clean the lens periodically and secure the cable or mount so "
      "it does not move over time.",
    ),
    const _T(
      "Si usas el móvil como cámara",
      "If you use your phone as a camera",
    ),
    const _T(
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