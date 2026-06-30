unit SessionManager;

interface

uses
  System.SysUtils, System.IOUtils;

type
  TSessionManager = class
  private
    FToken: string;
    FUserID: Int64;  // 🔑 Добавлен user_id из токена/логина
    FServerURL: string;
    FConfigFile: string;
    FDBPassword: string;  // 🔑 Пароль БД в памяти (не сохраняется на диск!)
    procedure SetServerURL(const Value: string);
    procedure LoadURL;
    procedure SaveURL;
  public
    constructor Create;
    property Token: string read FToken write FToken;
    property UserID: Int64 read FUserID write FUserID;  // 🔑 user_id сервера
    property ServerURL: string read FServerURL write SetServerURL;
    property DBPassword: string read FDBPassword write FDBPassword;  // 🔑 Пароль БД (в памяти)
    function IsLoggedIn: Boolean;
    procedure Logout;
  end;

var
  AppSession: TSessionManager;

implementation

{ TSessionManager }

constructor TSessionManager.Create;
begin
  FToken := '';
  FUserID := 0;  // 🔑 user_id по умолчанию 0 (не залогинен)
  FConfigFile := TPath.Combine(TPath.GetDocumentsPath, 'server_url.txt');
  LoadURL;
end;

procedure TSessionManager.LoadURL;
var
  LoadedURL: string;
  function IsLocalIP(const URL: string): Boolean;
  begin
    Result := (Pos('192.168.', URL) > 0) or
              (Pos('10.', URL) > 0) or
              (Pos('172.16.', URL) > 0) or
              (Pos('172.17.', URL) > 0) or
              (Pos('172.18.', URL) > 0) or
              (Pos('172.19.', URL) > 0) or
              (Pos('172.20.', URL) > 0) or
              (Pos('172.21.', URL) > 0) or
              (Pos('172.22.', URL) > 0) or
              (Pos('172.23.', URL) > 0) or
              (Pos('172.24.', URL) > 0) or
              (Pos('172.25.', URL) > 0) or
              (Pos('172.26.', URL) > 0) or
              (Pos('172.27.', URL) > 0) or
              (Pos('172.28.', URL) > 0) or
              (Pos('172.29.', URL) > 0) or
              (Pos('172.30.', URL) > 0) or
              (Pos('172.31.', URL) > 0) or
              (Pos('127.0.0.1', URL) > 0) or
              (Pos('localhost', LowerCase(URL)) > 0);
  end;
  function ForceHTTP(const URL: string): string;
  begin
    Result := URL;
    if Pos('https://', LowerCase(Result)) = 1 then
      Result := 'http://' + Copy(Result, 9, MaxInt);
  end;
begin
  if TFile.Exists(FConfigFile) then
  begin
    LoadedURL := Trim(TFile.ReadAllText(FConfigFile, TEncoding.UTF8));
    // 🔑 Принудительно HTTP для локальных IP (HTTPS на Android 10+ не работает с самоподписанными сертификатами)
    if IsLocalIP(LoadedURL) then
      LoadedURL := ForceHTTP(LoadedURL);
    FServerURL := LoadedURL;
  end
  else
    FServerURL := 'http://192.168.1.113';
end;

procedure TSessionManager.SaveURL;
begin
  TFile.WriteAllText(FConfigFile, FServerURL, TEncoding.UTF8);
end;

procedure TSessionManager.SetServerURL(const Value: string);
var
  Normalized: string;
begin
  Normalized := Trim(Value);
  // 🔑 Принудительно HTTP для локальных IP
  if (Pos('https://', LowerCase(Normalized)) = 1) and
     ((Pos('192.168.', Normalized) > 0) or
      (Pos('10.', Normalized) > 0) or
      (Pos('127.0.0.1', Normalized) > 0) or
      (Pos('localhost', LowerCase(Normalized)) > 0)) then
    Normalized := 'http://' + Copy(Normalized, 9, MaxInt);
  FServerURL := Normalized;
  SaveURL;
end;

function TSessionManager.IsLoggedIn: Boolean;
begin
  Result := FToken <> '';
end;

procedure TSessionManager.Logout;
begin
  FToken := '';
  FUserID := 0;  // 🔑 Сбрасываем user_id при выходе
  FDBPassword := '';  // 🔑 Сбрасываем пароль БД при выходе
end;

initialization
  AppSession := TSessionManager.Create;

finalization
  AppSession.Free;

end.
