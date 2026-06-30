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
  Token, StatusStr, RequestURL, ServerURL: string;
begin
  // Получаем URL сервера — добавляем http:// если не указан протокол
  ServerURL := Trim(edLocalIP.Text);
  if (Pos('http://', LowerCase(ServerURL)) <> 1) and
     (Pos('https://', LowerCase(ServerURL)) <> 1) then
    ServerURL := 'http://' + ServerURL;

  // 🔑 Принудительно HTTP для локальных IP (самоподписанные сертификаты не работают на Android 10+)
  if Pos('https://', LowerCase(ServerURL)) = 1 then
  begin
    if (Pos('192.168.', ServerURL) > 0) or
       (Pos('10.', ServerURL) > 0) or
       (Pos('127.0.0.1', ServerURL) > 0) or
       (Pos('localhost', LowerCase(ServerURL)) > 0) then
      ServerURL := 'http://' + Copy(ServerURL, 9, MaxInt);
  end;

  AppSession.ServerURL := ServerURL;

  // 🔑 ОТЛАДКА: показываем сохранённый URL сервера
  ShowMessage('Сохранён адрес сервера:' + sLineBreak + AppSession.ServerURL);

  RequestURL := AppSession.ServerURL + '/datasnap/rest/TServerMethods1/Login/' +
                TNetEncoding.URL.Encode(edUsername.Text) + '/' +
                TNetEncoding.URL.Encode(edPassword.Text);

  HTTP := THTTPClient.Create;
  try
    HTTP.ConnectionTimeout := 30000;
    HTTP.ResponseTimeout := 30000;

    // 🔑 Убран OnValidateServerCertificate для HTTP — избегаем SSL-инициализации на Android
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
                end
                else
                begin
                  ShowMessage('Ошибка входа: ' + StatusStr);
                  Exit;
                end;
              end;
            end;
          end;
        finally
          JSONResp.Free;
        end;
      end;

      ShowMessage('Ошибка входа: неверный ответ сервера (код ' + IntToStr(Response.StatusCode) + ')');

    except
      on E: Exception do
        ShowMessage('Ошибка сети: ' + E.Message);
    end;
  finally
    HTTP.Free;
  end;
end;

end.
