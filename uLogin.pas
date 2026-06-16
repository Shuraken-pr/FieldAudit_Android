unit uLogin;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Edit,
  FMX.StdCtrls, FMX.Controls.Presentation, REST.Types, REST.Client,
  Data.Bind.Components, Data.Bind.ObjectScope, SessionManager, System.JSON,
  System.NetEncoding, System.Generics.Collections;

type
  TfrmLogin = class(TForm)
    pnlUserName: TPanel;
    lblUserName: TLabel;
    pnlPassword: TPanel;
    edPassword: TEdit;
    lbPassword: TLabel;
    pnlLogin: TPanel;
    btnLogin: TButton;
    RESTClientLogin: TRESTClient;
    RESTRequestLogin: TRESTRequest;
    RESTResponseLogin: TRESTResponse;
    edUserName: TEdit;
    pnlLocalIP: TPanel;
    lbLocalIP: TLabel;
    edLocalIP: TEdit;
    procedure btnLoginClick(Sender: TObject);
  private
    { Private declarations }
    FOnLoginSuccess: TProc; // <-- ДОБАВЛЕНО: Обратный вызов
  public
    { Public declarations }
    property OnLoginSuccess: TProc read FOnLoginSuccess write FOnLoginSuccess; // <-- ДОБАВЛЕНО
    procedure DoLogin;
  end;

var
  frmLogin: TfrmLogin;

implementation

{$R *.fmx}
{$R *.SmXhdpiPh.fmx ANDROID}

procedure TfrmLogin.btnLoginClick(Sender: TObject);
begin
  if (edUserName.Text = '') or (edPassword.Text = '') or (edLocalIP.Text = '') then
  begin
    ShowMessage('Введите логин, пароль, локальный IP');
    Exit;
  end;

  btnLogin.Enabled := False;
  btnLogin.Text := 'Вход...';
  try
    DoLogin;
  finally
    btnLogin.Enabled := True;
    btnLogin.Text := 'Войти';
  end;
end;

procedure TfrmLogin.DoLogin;
var
  JSONResp: TJSONObject;
  ResultArray: TJSONArray;
  InnerJsonObj: TJSONObject;
  Token: string;
begin
  AppSession.ServerURL := 'http://' + edLocalIP.Text;
  RESTClientLogin.BaseURL := AppSession.ServerURL;// 'http://192.168.1.113:8082';
  RESTRequestLogin.Resource := 'datasnap/rest/TServerMethods1/Login/' +
                               TNetEncoding.URL.Encode(edUsername.Text) + '/' +
                               TNetEncoding.URL.Encode(edPassword.Text);
  RESTRequestLogin.Method := TRESTRequestMethod.rmGET;

  try
    RESTRequestLogin.Execute;

    JSONResp := TJSONObject.ParseJSONValue(RESTResponseLogin.Content) as TJSONObject;
    try
      if Assigned(JSONResp) then
      begin
        ResultArray := JSONResp.GetValue('result') as TJSONArray;
        if Assigned(ResultArray) and (ResultArray.Count > 0) then
        begin
          // ИСПРАВЛЕНИЕ: InnerJsonObj принадлежит JSONResp.
          // НЕ освобождаем его вручную, иначе будет Double Free.
          InnerJsonObj := ResultArray.Items[0] as TJSONObject;

          if Assigned(InnerJsonObj) and (InnerJsonObj.GetValue('status') <> nil) and
             (InnerJsonObj.GetValue('status').Value = 'success') then
          begin
            Token := InnerJsonObj.GetValue('token').Value;
            AppSession.Token := Token;

            if Assigned(FOnLoginSuccess) then
            begin
              FOnLoginSuccess();
              FOnLoginSuccess := nil;
            end;
            Self.Close;
          end
          else
            ShowMessage('Неверный логин или пароль');
        end
        else
          ShowMessage('Неверный формат ответа сервера');
      end;
    finally
      JSONResp.Free; // Освобождает ВСЁ дерево, включая InnerJsonObj
    end;
  except
    on E: Exception do
      ShowMessage('Ошибка сети: ' + E.Message);
  end;
end;

end.
