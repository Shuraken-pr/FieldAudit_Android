program AndroidDelphi;

uses
  System.StartUpCopy,
  FMX.Forms,
  frmMain in 'frmMain.pas' {Form1},
  dmLocalDb in 'dmLocalDb.pas' {dmLocDB: TDataModule};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TdmLocDB, dmLocDB);
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
