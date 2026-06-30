program AndroidDelphi;

uses
  System.StartUpCopy,
  FMX.Forms,
  System.SysUtils,
  System.IOUtils,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  frmMain in 'frmMain.pas' {formMain},
  dmLocalDb in 'dmLocalDb.pas' {dmLocDB: TDataModule},
  frmPhotoView in 'frmPhotoView.pas' {formPhotoView},
  SessionManager in 'SessionManager.pas',
  uLogin in 'uLogin.pas' {frmLogin},
  DatabaseKeyManager in 'DatabaseKeyManager.pas',
  frmSetPIN in 'frmSetPIN.pas' {frSetPIN},
  frmEnterPIN in 'frmEnterPIN.pas' {frEnterPIN};

{$R *.res}

{$IFDEF MSWINDOWS}
// Initialize SQLite3 Multiple Ciphers driver for Windows desktop (testing)
procedure InitSQLiteDriver;
var
  DriverLink: TFDPhysSQLiteDriverLink;
  DLLPath: string;
begin
  DriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  try
    DLLPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'sqlite3mc.dll');
    if TFile.Exists(DLLPath) then
    begin
      DriverLink.VendorLib := DLLPath;
      Writeln('SQLite3MC loaded: ' + DLLPath);
    end
    else
    begin
      DLLPath := TPath.Combine(TPath.GetDocumentsPath, 'sqlite3mc.dll');
      if TFile.Exists(DLLPath) then
        DriverLink.VendorLib := DLLPath;
    end;
  finally
    // DriverLink intentionally not freed — it must stay alive for the app lifetime
  end;
end;
{$ENDIF}

begin
{$IFDEF MSWINDOWS}
  InitSQLiteDriver;
{$ENDIF}

  Application.Initialize;
  Application.CreateForm(TdmLocDB, dmLocDB);
  Application.CreateForm(TformMain, formMain);
  Application.Run;
end.
