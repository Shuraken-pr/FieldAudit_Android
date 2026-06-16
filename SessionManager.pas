unit SessionManager;

interface

uses
  System.SysUtils;

type
  TSessionManager = class
  private
    FToken: string;
    FServerURL: string;
  public
    constructor Create;
    property Token: string read FToken write FToken;
    property ServerURL: string read FServerURL write FServerURL;
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
  FServerURL := '192.168.1.1:8080';
end;

function TSessionManager.IsLoggedIn: Boolean;
begin
  Result := FToken <> '';
end;

procedure TSessionManager.Logout;
begin
  FToken := '';
end;

initialization
  AppSession := TSessionManager.Create;

finalization
  AppSession.Free;

end.
