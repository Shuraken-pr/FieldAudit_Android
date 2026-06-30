unit frmEnterPIN;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit;

type
  TfrEnterPIN = class(TForm)
    edtPIN: TEdit;
    lblTitle: TLabel;
    btnEnter: TButton;
    procedure btnEnterClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FOnPINEntered: TProc<string>;
  public
    property OnPINEntered: TProc<string> read FOnPINEntered write FOnPINEntered;
  end;

var
  frEnterPIN: TfrEnterPIN;

implementation

{$R *.fmx}

procedure TfrEnterPIN.FormCreate(Sender: TObject);
begin
  lblTitle.Text := 'Введите PIN';
  edtPIN.KeyboardType := TVirtualKeyboardType.NumberPad;
  edtPIN.Password := True;
  edtPIN.MaxLength := 6;
  btnEnter.Text := 'Войти';
end;

procedure TfrEnterPIN.btnEnterClick(Sender: TObject);
begin
  if edtPIN.Text = '' then
  begin
    ShowMessage('Введите PIN');
    Exit;
  end;

  if Assigned(FOnPINEntered) then
    FOnPINEntered(edtPIN.Text);

  Self.Close;
end;

end.
