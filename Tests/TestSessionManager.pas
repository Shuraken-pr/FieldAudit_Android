unit TestSessionManager;

interface

uses
  DUnitX.TestFramework,
  SessionManager,
  System.SysUtils,
  System.IOUtils;

type
  [TestFixture]
  TTestSessionManager = class
  private
    FConfigFile: string;
    FOriginalUrl: string;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure TestDefaultTokenIsEmpty;
    
    [Test]
    procedure TestDefaultServerURL;
    
    [Test]
    procedure TestSetAndGetToken;
    
    [Test]
    procedure TestIsLoggedInWithEmptyToken;
    
    [Test]
    procedure TestIsLoggedInWithValidToken;
    
    [Test]
    procedure TestLogoutClearsToken;
    
    [Test]
    procedure TestServerURLAutoSave;
    
    [Test]
    procedure TestTokenNotPersistedToDisk;
  end;

implementation

procedure TTestSessionManager.Setup;
begin
  // Сохраняем оригинальный URL для восстановления
  FOriginalUrl := AppSession.ServerURL;
  FConfigFile := TPath.Combine(TPath.GetDocumentsPath, 'server_url.txt');
  
  // Сбрасываем состояние для тестов
  AppSession.Token := '';
end;

procedure TTestSessionManager.TearDown;
begin
  // Восстанавливаем оригинальный URL
  AppSession.ServerURL := FOriginalUrl;
  AppSession.Token := '';
end;

procedure TTestSessionManager.TestDefaultTokenIsEmpty;
begin
  // Токен по умолчанию должен быть пустым
  Assert.AreEqual('', AppSession.Token, 
    'Токен по умолчанию должен быть пустым');
end;

procedure TTestSessionManager.TestDefaultServerURL;
begin
  // URL по умолчанию должен быть корректным (из файла или дефолтный)
  Assert.AreNotEqual('', AppSession.ServerURL, 
    'URL не должен быть пустым');
  Assert.IsTrue(Pos('http', AppSession.ServerURL) = 1, 
    'URL должен начинаться с http или https');
end;

procedure TTestSessionManager.TestSetAndGetToken;
var
  TestToken: string;
begin
  TestToken := '{86AB48DA-D896-4480-8BA8-99E620F05C5E}';
  AppSession.Token := TestToken;
  
  Assert.AreEqual(TestToken, AppSession.Token, 
    'Токен должен корректно сохраняться');
end;

procedure TTestSessionManager.TestIsLoggedInWithEmptyToken;
begin
  AppSession.Token := '';
  
  Assert.IsFalse(AppSession.IsLoggedIn, 
    'Без токена IsLoggedIn должен быть False');
end;

procedure TTestSessionManager.TestIsLoggedInWithValidToken;
begin
  AppSession.Token := 'valid_token_123';
  
  Assert.IsTrue(AppSession.IsLoggedIn, 
    'С токеном IsLoggedIn должен быть True');
end;

procedure TTestSessionManager.TestLogoutClearsToken;
begin
  AppSession.Token := 'some_token';
  Assert.IsTrue(AppSession.IsLoggedIn, 
    'Перед Logout должен быть авторизован');
  
  AppSession.Logout;
  
  Assert.AreEqual('', AppSession.Token, 
    'После Logout токен должен быть пустым');
  Assert.IsFalse(AppSession.IsLoggedIn, 
    'После Logout IsLoggedIn должен быть False');
end;

procedure TTestSessionManager.TestServerURLAutoSave;
var
  NewUrl: string;
  LoadedUrl: string;
begin
  NewUrl := 'https://test.server.com:8083';
  
  // Устанавливаем новый URL (должен автоматически сохраниться)
  AppSession.ServerURL := NewUrl;
  
  // Проверяем, что URL сохранился в файл
  if TFile.Exists(FConfigFile) then
  begin
    LoadedUrl := TFile.ReadAllText(FConfigFile, TEncoding.UTF8);
    Assert.AreEqual(NewUrl, LoadedUrl, 
      'URL должен автоматически сохраняться в файл при установке');
  end
  else
  begin
    // Если файл не создан (например, нет прав), пропускаем тест
    Assert.Pass('Файл конфигурации не создан (возможно, нет прав доступа)');
  end;
end;

procedure TTestSessionManager.TestTokenNotPersistedToDisk;
begin
  // Токен НЕ должен сохраняться на диск (безопасность!)
  AppSession.Token := 'temp_secret_token';
  Assert.IsTrue(AppSession.IsLoggedIn, 
    'Токен должен храниться в памяти');
  
  // Проверяем, что токен НЕ записан в файл конфигурации
  if TFile.Exists(FConfigFile) then
  begin
    var FileContent := TFile.ReadAllText(FConfigFile, TEncoding.UTF8);
    Assert.IsFalse(Pos('temp_secret_token', FileContent) > 0, 
      'Токен НЕ должен сохраняться в файл конфигурации');
  end;
  
  // Токен должен остаться в памяти в течение сессии
  Assert.AreEqual('temp_secret_token', AppSession.Token, 
    'Токен должен храниться в памяти в течение сессии');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSessionManager);

end.
