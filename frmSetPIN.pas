unit frmSetPIN;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit;

type
  TfrSetPIN = class(TForm)
    edtPIN: TEdit;
    edtConfirmPIN: TEdit;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    btnSetPIN: TButton;
    procedure btnSetPINClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FOnPINSet: TProc<string>;
  public
    property OnPINSet: TProc<string> read FOnPINSet write FOnPINSet;
  end;

var
  frSetPIN: TfrSetPIN;

implementation

{$R *.fmx}

procedure TfrSetPIN.FormCreate(Sender: TObject);
begin
  lblTitle.Text := 'Установка PIN';
  lblSubtitle.Text := 'Введите 4-6 цифр для защиты базы данных';
  edtPIN.KeyboardType := TVirtualKeyboardType.NumberPad;
  edtPIN.Password := True;
  edtPIN.MaxLength := 6;
  edtConfirmPIN.KeyboardType := TVirtualKeyboardType.NumberPad;
  edtConfirmPIN.Password := True;
  edtConfirmPIN.MaxLength := 6;
  btnSetPIN.Text := 'Установить PIN';
end;

procedure TfrSetPIN.btnSetPINClick(Sender: TObject);
begin
  if edtPIN.Text = '' then
  begin
    ShowMessage('Введите PIN');
    Exit;
  end;

  if Length(edtPIN.Text) < 4 then
  begin
    ShowMessage('PIN должен содержать минимум 4 цифры');
    Exit;
  end;

  if edtPIN.Text <> edtConfirmPIN.Text then
  begin
    ShowMessage('PINы не совпадают');
    Exit;
  end;

  if Assigned(FOnPINSet) then
    FOnPINSet(edtPIN.Text);

  Self.Close;
end;

end.
