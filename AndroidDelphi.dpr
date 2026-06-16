program AndroidDelphi;

uses
  System.StartUpCopy,
  FMX.Forms,
  frmMain in 'frmMain.pas' {formMain},
  dmLocalDb in 'dmLocalDb.pas' {dmLocDB: TDataModule},
  frmPhotoView in 'frmPhotoView.pas' {formPhotoView},
  SessionManager in 'SessionManager.pas',
  uLogin in 'uLogin.pas' {frmLogin};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TdmLocDB, dmLocDB);
  Application.CreateForm(TformMain, formMain);
  Application.Run;
end.
