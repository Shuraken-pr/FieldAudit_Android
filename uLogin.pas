unit uLogin;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, System.JSON, System.NetEncoding, System.Generics.Collections,
  System.Net.HttpClient, System.Net.URLClient,
  SessionManager, FMX.Controls.Presentation;

type
  TfrmLogin = class(TForm)
    edUsername: TEdit;
    edPassword: TEdit;
    edLocalIP: TEdit;
    btnLogin: TButton;
    procedure btnLoginClick(Sender: TObject);
  private
    FOnLoginSuccess: TProc;
    procedure ValidateCert(
      const Sender: TObject; const ARequest: TURLRequest;
      const Certificate: TCertificate; var Accepted: Boolean);
  public
    property OnLoginSuccess: TProc read FOnLoginSuccess write FOnLoginSuccess;
    procedure DoLogin;
  end;

var
  frmLogin: TfrmLogin;

implementation

{$R *.fmx}

procedure TfrmLogin.btnLoginClick(Sender: TObject);
begin
  if (edUsername.Text = '') or (edPassword.Text = '') then
  begin
    ShowMessage('Введите логин и пароль');
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
  HTTP: THTTPClient;
  Response: IHTTPResponse;
  JSONResp: TJSONObject;
  ResultArr: TJSONArray;
  InnerObj: TJSONObject;
  Token, StatusStr, RequestURL: string;
begin
  AppSession.ServerURL := 'https://' + edLocalIP.Text;
  RequestURL := AppSession.ServerURL + '/datasnap/rest/TServerMethods1/Login/' +
                TNetEncoding.URL.Encode(edUsername.Text) + '/' +
                TNetEncoding.URL.Encode(edPassword.Text);

  HTTP := THTTPClient.Create;
  try
    HTTP.ConnectionTimeout := 30000;
    HTTP.ResponseTimeout := 30000;

    HTTP.OnValidateServerCertificate := ValidateCert;
    try
      Response := HTTP.Get(RequestURL);

      if Response.StatusCode = 200 then
      begin
        JSONResp := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
        try
          if Assigned(JSONResp) then
          begin
            ResultArr := JSONResp.GetValue('result') as TJSONArray;
            if Assigned(ResultArr) and (ResultArr.Count > 0) then
            begin
              InnerObj := ResultArr.Items[0] as TJSONObject;

              if Assigned(InnerObj) then
              begin
                if InnerObj.GetValue('status') <> nil then
                  StatusStr := InnerObj.GetValue('status').Value
                else
                  StatusStr := '';

                if StatusStr = 'success' then
                begin
                  if InnerObj.GetValue('token') <> nil then
                    Token := InnerObj.GetValue('token').Value;

                  AppSession.Token := Token;

                  // 🔑 Сохраняем user_id из ответа сервера
                  if InnerObj.GetValue('user_id') <> nil then
                    AppSession.UserID := StrToInt64(InnerObj.GetValue('user_id').Value);

                  if Assigned(FOnLoginSuccess) then
                  begin
                    FOnLoginSuccess();
                    FOnLoginSuccess := nil;
                  end;

                  Self.Close;
                  Exit;
                end;
              end;
            end;
          end;
        finally
          JSONResp.Free;
        end;
      end;

      ShowMessage('Ошибка входа: неверный ответ сервера');

    except
      on E: Exception do
        ShowMessage('Ошибка сети: ' + E.Message);
    end;
  finally
    HTTP.Free;
  end;
end;

procedure TfrmLogin.ValidateCert(const Sender: TObject;
  const ARequest: TURLRequest; const Certificate: TCertificate;
  var Accepted: Boolean);
begin
  //не использовать для Production.
  Accepted := true;
end;

end.
