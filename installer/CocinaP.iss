; CocinaP - Inno Setup Installer
; Requires Inno Setup 6+ (https://jrsoftware.org/isdl.php)

#define MyAppName "CocinaP"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "CocinaP"
#define MyAppURL "https://github.com/KevinVilleros/KitchenGuard"
#define MyAppExeName "CocinaP.exe"
#define MyAppAssocName "CocinaP"

[Setup]
AppId={{B8A3C0E1-5F2D-4A7B-9C8E-1D2F3A4B5C6D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; LicenseFile=..\LICENSE (opcional, crear si se requiere)
OutputDir=..\dist
OutputBaseFilename=CocinaP_Setup_v{#MyAppVersion}
SetupIconFile=..\cocinap\resources\app.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
DisableProgramGroupPage=yes

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"
Name: "autostart"; Description: "Iniciar con Windows"; GroupDescription: "Opciones:"

[Files]
Source: "..\dist\CocinaP\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: DirExists('..\dist\CocinaP')

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar {#MyAppName}"; Flags: postinstall nowait skipifsilent shellexec

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c REG DELETE HKCU\Software\Microsoft\Windows\CurrentVersion\Run /V CocinaP /F 2>nul"; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\CocinaP"

[Code]
function InitializeSetup: Boolean;
begin
  Result := True;
end;
