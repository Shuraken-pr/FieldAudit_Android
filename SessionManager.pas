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
    procedure SetServerURL(const Value: string);
    procedure LoadURL;
    procedure SaveURL;
  public
    constructor Create;
    property Token: string read FToken write FToken;
    property UserID: Int64 read FUserID write FUserID;  // 🔑 user_id сервера
    property ServerURL: string read FServerURL write SetServerURL;
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
begin
  if TFile.Exists(FConfigFile) then
    FServerURL := TFile.ReadAllText(FConfigFile, TEncoding.UTF8)
  else
    FServerURL := 'https://192.168.1.113';
end;

procedure TSessionManager.SaveURL;
begin
  TFile.WriteAllText(FConfigFile, FServerURL, TEncoding.UTF8);
end;

procedure TSessionManager.SetServerURL(const Value: string);
begin
  FServerURL := Value;
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
end;

initialization
  AppSession := TSessionManager.Create;

finalization
  AppSession.Free;

end.
