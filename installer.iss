[Setup]
AppName=Comic
AppVersion=1.0.2
AppPublisher=comic
DefaultDirName={autopf}\comic
DefaultGroupName=Comic
OutputDir=installer
OutputBaseFilename=comic-setup
Compression=lzma
SolidCompression=yes
CloseApplications=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Comic"; Filename: "{app}\comic.exe"
Name: "{userdesktop}\Comic"; Filename: "{app}\comic.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\comic.exe"; Description: "立即启动 Comic"; Flags: nowait postinstall skipifsilent
