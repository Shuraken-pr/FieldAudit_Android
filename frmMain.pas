unit frmMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ListView.Types, FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base, FMX.ListView, FMX.MediaLibrary, System.Actions,
  FMX.ActnList, FMX.StdActns, FMX.Platform, System.IOUtils, System.StrUtils,
  System.Sensors, FMX.Maps, System.Sensors.Components, FMX.WebBrowser,
  FMX.Objects, System.JSON, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, Data.DB,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client, System.ImageList, FMX.ImgList,
  System.Net.HttpClient, System.Net.URLClient, System.Net.Mime, System.Hash,
  System.DateUtils, JpegUtils, System.NetEncoding, System.NetConsts;

type
  TformMain = class(TForm)
    ToolBar1: TToolBar;
    lblTitle: TLabel;
    lvTasks: TListView;
    alMain: TActionList;
    btnTakePhoto: TButton;
    lsMain: TLocationSensor;
    lblCoords: TLabel;
    wbMaps: TWebBrowser;
    btnPhoto: TButton;
    btnSync: TButton;
    FDQuery1: TFDQuery;
    ilButtons: TImageList;
    acSynchronize: TAction;
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure btnTakePhotoClick(Sender: TObject);
    procedure lsMainLocationChanged(Sender: TObject; const OldLocation,
      NewLocation: TLocationCoord2D);
    procedure btnPhotoClick(Sender: TObject);
    procedure lvTasksItemClick(const Sender: TObject;
      const AItem: TListViewItem);
    procedure acSynchronizeExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FLoadedOnce: Boolean;
    FPinVerified: Boolean;
    FCurrentLat, FCurrentLon: Double;
    procedure LoadTasks;
    procedure DoDidFinish(Image: TBitmap);
    procedure DoDidCancel;
    procedure DoLogin;
    procedure CheckAndRequestPIN;
    procedure OnPINSet(const PIN: string);
    procedure OnPINEntered(const PIN: string);
  public
    { Public declarations }
  end;

var
  formMain: TformMain;

implementation

uses
  {$IFDEF ANDROID}
  Androidapi.JNI.JavaTypes, Androidapi.Helpers, Androidapi.JNI.Os,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF}
  dmLocalDb, frmPhotoView, SessionManager, uLogin, DatabaseKeyManager,
  frmSetPIN, frmEnterPIN;

{$R *.fmx}

procedure TformMain.acSynchronizeExecute(Sender: TObject);
const
  MAX_RETRY = 2;
var
  Query, QUpdate: TFDQuery;
  HTTP: THTTPClient;
  Response: IHTTPResponse;
  PayloadStream: TStringStream;
  PhotoBytes: TBytes;
  Metadata: TJSONObject;
  PhotoPath, CompressedPath, FileName, UploadURL, JsonMeta: string;
  RetryCount: Integer;
  SyncSuccess: Boolean;
  TaskId: Int64;
  BatchUUID: string;
  Base64Encoder: TBase64Encoding;
begin
  if not AppSession.IsLoggedIn then
  begin
    ShowMessage('Сессия истекла. Пожалуйста, войдите в систему заново.');
    DoLogin;
    Exit;
  end;

  if Trim(AppSession.ServerURL) = '' then
  begin
    ShowMessage('Адрес сервера не задан.' + sLineBreak +
      'Войдите в систему и укажите адрес сервера (например: 192.168.1.113:8082)');
    DoLogin;
    Exit;
  end;

  // 🔑 ОТЛАДКА: показываем URL сервера перед синхронизацией
  ShowMessage('Синхронизация с сервером:' + sLineBreak + AppSession.ServerURL);

  Query := TFDQuery.Create(nil);
  Query.Connection := dmLocDB.FDConnection1;
  try
    Query.SQL.Text :=
      'SELECT id, title, description, latitude, longitude, upload_attempts ' +
      'FROM tasks WHERE is_synced = 0 AND upload_attempts < 3 ' +
      'ORDER BY id';
    Query.Open;

    if Query.IsEmpty then
    begin
      ShowMessage('Все данные уже синхронизированы.');
      Exit;
    end;

    while not Query.Eof do
    begin
      TaskId := Query.FieldByName('id').AsLargeInt;
      PhotoPath := TDatabaseKeyManager.DecryptField(Query.FieldByName('description').AsString);
      RetryCount := 0;
      SyncSuccess := False;
      BatchUUID := TGUID.NewGuid.ToString;

      while (RetryCount <= MAX_RETRY) and not SyncSuccess do
      begin
        HTTP := THTTPClient.Create;
        try
          try
            HTTP.ConnectionTimeout := 30000;
            HTTP.ResponseTimeout := 120000;

            // 🔑 Убран OnValidateServerCertificate для HTTP — избегаем SSL-инициализации на Android

            // JSON payload с metadata и фото в Base64 (избегает проблем multipart/кодировок)
            if TFile.Exists(PhotoPath) then
            begin
              FileName := System.IOUtils.TPath.GetFileName(PhotoPath);
              CompressedPath := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetTempPath, 'cmp_' + FileName);

              if CompressPhoto(PhotoPath, CompressedPath, 1920, 85) then
                PhotoBytes := TFile.ReadAllBytes(CompressedPath)
              else
                PhotoBytes := TFile.ReadAllBytes(PhotoPath);
            end
            else
            begin
              SetLength(PhotoBytes, 0);
            end;

            Metadata := TJSONObject.Create;
            try
              Metadata.AddPair('event_type', 'mobile_audit');
              Metadata.AddPair('occurred_at', DateToISO8601(Now));
              Metadata.AddPair('lat', TJSONNumber.Create(Query.FieldByName('latitude').AsFloat));
              Metadata.AddPair('lon', TJSONNumber.Create(Query.FieldByName('longitude').AsFloat));
              Metadata.AddPair('title', TDatabaseKeyManager.DecryptField(Query.FieldByName('title').AsString));
              Metadata.AddPair('device_id', 'android');
              Metadata.AddPair('batch_id', BatchUUID);
              if Length(PhotoBytes) > 0 then
              begin
                // 🔑 Base64 без переносов строк (иначе сервер не сможет декодировать после JSON)
                Base64Encoder := TBase64Encoding.Create(0);
                try
                  Metadata.AddPair('photo_base64', Base64Encoder.EncodeBytesToString(PhotoBytes));
                finally
                  Base64Encoder.Free;
                end;
                Metadata.AddPair('photo_filename', FileName);
              end;
              JsonMeta := Metadata.ToString;
            finally
              Metadata.Free;
            end;

            HTTP.CustomHeaders['Content-Type'] := 'application/json';
            HTTP.CustomHeaders['X-Session-Token'] := AppSession.Token;
            UploadURL := AppSession.ServerURL + '/upload';

            PayloadStream := TStringStream.Create(JsonMeta, TEncoding.UTF8);
            try
              Response := HTTP.Post(UploadURL, PayloadStream);
            finally
              PayloadStream.Free;
            end;

            if Response.StatusCode = 200 then
            begin
              QUpdate := TFDQuery.Create(nil);
              try
                QUpdate.Connection := dmLocDB.FDConnection1;
                QUpdate.SQL.Text :=
                  'UPDATE tasks SET is_synced = 1, upload_attempts = upload_attempts + 1, ' +
                  'last_error = NULL, can_delete_local = 0 WHERE id = :id';
                QUpdate.ParamByName('id').AsInteger := TaskId;
                QUpdate.ExecSQL;
              finally
                QUpdate.Free;
              end;
              SyncSuccess := True;
            end
            else if Response.StatusCode = 401 then
            begin
              AppSession.Logout;
              ShowMessage('Сессия истекла. Войдите заново.');
              DoLogin;
              Exit;
            end
            else if Response.StatusCode = 429 then
            begin
              ShowMessage('Ошибка 429: Слишком много запросов.' + sLineBreak +
                'Возможные причины:' + sLineBreak +
                '1. На порту 80 работает не Nginx, а другой сервис (IIS Windows)' + sLineBreak +
                '2. Nginx не перезапущен со старым конфигом' + sLineBreak +
                '3. Rate limiting на сервере' + sLineBreak + sLineBreak +
                'Решение: проверьте, что Nginx слушает порт 80' + sLineBreak +
                'Или используйте подключение напрямую: 192.168.1.113:8082');
              Exit;
            end
            else
            begin
              Inc(RetryCount);
              if RetryCount > MAX_RETRY then
              begin
                QUpdate := TFDQuery.Create(nil);
                try
                  QUpdate.Connection := dmLocDB.FDConnection1;
                  QUpdate.SQL.Text :=
                    'UPDATE tasks SET upload_attempts = upload_attempts + 1, ' +
                    'last_error = :err WHERE id = :id';
                  QUpdate.ParamByName('err').AsString := 'HTTP ' + IntToStr(Response.StatusCode);
                  QUpdate.ParamByName('id').AsInteger := TaskId;
                  QUpdate.ExecSQL;
                finally
                  QUpdate.Free;
                end;
              end;
              Sleep(1000 * RetryCount);
            end;
          except
            on E: Exception do
            begin
              Inc(RetryCount);
              if RetryCount > MAX_RETRY then
              begin
                QUpdate := TFDQuery.Create(nil);
                try
                  QUpdate.Connection := dmLocDB.FDConnection1;
                  QUpdate.SQL.Text :=
                    'UPDATE tasks SET upload_attempts = upload_attempts + 1, ' +
                    'last_error = :err WHERE id = :id';
                  if (Pos('SSL', E.Message) > 0) or (Pos('Certificate', E.Message) > 0) or
                     (Pos('Trust anchor', E.Message) > 0) or (Pos('Hostname', E.Message) > 0) or
                     (Pos('Peer', E.Message) > 0) or (Pos('cert', E.Message) > 0) then
                  begin
                    QUpdate.ParamByName('err').AsString := 'SSL_ERROR: ' + E.Message;
                    ShowMessage('Ошибка SSL-соединения.' + sLineBreak +
                      'Возможные причины:' + sLineBreak +
                      '1. Самоподписанный сертификат не установлен на устройстве' + sLineBreak +
                      '2. Сертификат не содержит IP-адрес в SAN (Subject Alternative Name)' + sLineBreak +
                      '3. Неверная дата/время на устройстве' + sLineBreak + sLineBreak +
                      'Текст ошибки: ' + E.Message);
                  end
                  else if (Pos('SocketTimeout', E.Message) > 0) or
                          (Pos('timeout', LowerCase(E.Message)) > 0) or
                          (Pos('failed to connect', LowerCase(E.Message)) > 0) or
                          (Pos('connection refused', LowerCase(E.Message)) > 0) then
                  begin
                    QUpdate.ParamByName('err').AsString := 'NETWORK_TIMEOUT: ' + E.Message;
                    ShowMessage('Не удалось подключиться к серверу.' + sLineBreak +
                      'Адрес: ' + AppSession.ServerURL + sLineBreak + sLineBreak +
                      'Проверьте:' + sLineBreak +
                      '1. Сервер запущен на ПК' + sLineBreak +
                      '2. Телефон и ПК в одной Wi-Fi сети' + sLineBreak +
                      '3. Файрвол Windows не блокирует порт (cmd: netsh advfirewall firewall add rule name="DataSnap" dir=in action=allow protocol=tcp localport=8082)' + sLineBreak +
                      '4. IP-адрес сервера верный (ipconfig на ПК)' + sLineBreak + sLineBreak +
                      'Текст ошибки: ' + E.Message);
                  end
                  else
                    QUpdate.ParamByName('err').AsString := E.Message;
                  QUpdate.ParamByName('id').AsInteger := TaskId;
                  QUpdate.ExecSQL;
                finally
                  QUpdate.Free;
                end;
              end;
              Sleep(1000 * RetryCount);
            end;
          end;

        finally
          HTTP.Free;
        end;
      end;

      Query.Next;
    end;

    LoadTasks;
    ShowMessage('Синхронизация завершена.');

  finally
    Query.Free;
  end;
end;

procedure TformMain.btnPhotoClick(Sender: TObject);
var
  FilePath: string;
begin
  if not Assigned(lvTasks.Selected) then Exit;

  FilePath := TListViewItem(lvTasks.Selected).Detail;

  if (FilePath <> '') and TFile.Exists(FilePath) then
  begin
    try
      if not Assigned(formPhotoView) then
        formPhotoView := TformPhotoView.Create(nil);
      formPhotoView.imgPhoto.Bitmap.LoadFromFile(FilePath);
      formPhotoView.Show;
    except
      on E: Exception do
        ShowMessage('Ошибка открытия фото: ' + E.Message);
    end;
  end
  else
    ShowMessage('Для этой записи нет фотографии.');
end;

procedure TformMain.btnTakePhotoClick(Sender: TObject);
var
  Service: IFMXCameraService;
  Params: TParamsPhotoQuery;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXCameraService, Service) then
  begin
    Params.Editable := False;
    Params.NeedSaveToAlbum := False;
    Params.RequiredResolution := TSize.Create(1024, 1024);

    Params.OnDidFinishTaking := DoDidFinish;
    Params.OnDidCancelTaking := DoDidCancel;

    Service.TakePhoto(Sender as TControl, Params);
  end
  else
    ShowMessage('Камера недоступна на этом устройстве');
end;

procedure TformMain.DoDidCancel;
begin
  ShowMessage('Съемка отменена');
end;

function GetFreeSpaceBytes(const Path: string): Int64;
{$IFDEF ANDROID}
var
  FileObj: JFile;
begin
  FileObj := TJFile.JavaClass.init(StringToJString(Path));
  Result := FileObj.getFreeSpace;
end;
{$ENDIF}
{$IFDEF MSWINDOWS}
var
  FreeAvailable: Int64;
  TotalSpace: Int64;
  TotalFree: Int64;
  PathStr: string;
begin
  PathStr := IncludeTrailingPathDelimiter(Path);
  if GetDiskFreeSpaceEx(PChar(PathStr), FreeAvailable, TotalSpace, @TotalFree) then
    Result := FreeAvailable
  else
    Result := 0;
end;
{$ENDIF}
{$IFNDEF ANDROID}{$IFNDEF MSWINDOWS}
begin
  Result := High(Int64); // Fallback for other platforms
end;
{$ENDIF}{$ENDIF}

procedure TformMain.DoDidFinish(Image: TBitmap);
const
  MIN_FREE_SPACE = 50 * 1024 * 1024; // 50 MB
var
  Dir, FileName: string;
  FreeSpace: Int64;
begin
  try
    // Проверка свободного места перед сохранением
    FreeSpace := GetFreeSpaceBytes(System.IOUtils.TPath.GetDocumentsPath);
    if FreeSpace < MIN_FREE_SPACE then
    begin
      ShowMessage(Format('Недостаточно места для сохранения фото. Свободно: %d МБ, требуется: %d МБ',
        [FreeSpace div (1024 * 1024), MIN_FREE_SPACE div (1024 * 1024)]));
      Exit;
    end;

    Dir := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'photos');
    if not TDirectory.Exists(Dir) then
      TDirectory.CreateDirectory(Dir);

    FileName := System.IOUtils.TPath.Combine(Dir, FormatDateTime('yyyymmdd_hhnnss', Now) + '.jpg');

    Image.SaveToFile(FileName);

    dmLocDB.FDConnection1.ExecSQL(
      'INSERT INTO tasks (title, description, status, latitude, longitude) VALUES (?, ?, ?, ?, ?)',
     [TDatabaseKeyManager.EncryptField('Фото-отчет ' + FormatDateTime('hh_mm_ss', Now)),
      TDatabaseKeyManager.EncryptField(FileName), 'new', FCurrentLat, FCurrentLon]);

    LoadTasks;
    ShowMessage('Фото успешно сохранено!');
  except
    on E: Exception do
      ShowMessage('Ошибка: ' + E.Message);
  end;
end;

procedure TformMain.DoLogin;
begin
  if not Assigned(frmLogin) then
    frmLogin := TfrmLogin.Create(nil);
  frmLogin.OnLoginSuccess := procedure
  begin
    acSynchronize.Execute;
  end;
  frmLogin.Show;
end;

procedure TformMain.FormActivate(Sender: TObject);
begin
  if not FPinVerified then
    CheckAndRequestPIN;
  if not FLoadedOnce and FPinVerified then
  begin
    LoadTasks;
    FLoadedOnce := True;
  end;
end;

procedure TformMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(formPhotoView) then
    FreeAndNil(formPhotoView);
  if Assigned(frmLogin) then
    FreeAndNil(frmLogin);
  if Assigned(frEnterPIN) then
    FreeAndNil(frEnterPIN);
  if Assigned(frSetPIN) then
    FreeAndNil(frSetPIN);
end;

procedure TformMain.FormCreate(Sender: TObject);
var
  FilePath: string;
begin
  lsMain.Active := True;

  FilePath := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'map.html');
  if TFile.Exists(FilePath) then
    wbMaps.Navigate('file://' + FilePath)
  else
    wbMaps.Navigate('about:blank');

  FLoadedOnce := false;
  FPinVerified := false;
end;

procedure TformMain.CheckAndRequestPIN;
const
  PIN_HASH_KEY = 'pin_hash';
  PIN_SALT_KEY = 'pin_salt';

  function HasPINStored: Boolean;
  var
    PINHash, PINSalt: string;
  begin
    PINHash := TDatabaseKeyManager.GetSharedPrefString(PIN_HASH_KEY, '');
    PINSalt := TDatabaseKeyManager.GetSharedPrefString(PIN_SALT_KEY, '');
    Result := (PINHash <> '') and (PINSalt <> '');
  end;

  procedure ShowPINSetup;
  begin
    if not Assigned(frSetPIN) then
      frSetPIN := TfrSetPIN.Create(nil);
    frSetPIN.OnPINSet := procedure(PIN: string)
    begin
      OnPINSet(PIN);
    end;
    frSetPIN.Show;
  end;

  procedure ShowPINEnter;
  begin
    if not Assigned(frEnterPIN) then
      frEnterPIN := TfrEnterPIN.Create(nil);
    frEnterPIN.OnPINEntered := procedure(PIN: string)
    begin
      OnPINEntered(PIN);
    end;
    frEnterPIN.Show;
  end;

begin
  if HasPINStored then
    ShowPINEnter
  else
    ShowPINSetup;
end;

procedure TformMain.OnPINSet(const PIN: string);
const
  PIN_HASH_KEY = 'pin_hash';
  PIN_SALT_KEY = 'pin_salt';
var
  Salt, PINHash: string;
  Hash: THashSHA2;
  HashBytes: TBytes;
  I: Integer;
  Combined: string;
  DeviceID: string;
begin
  if Length(PIN) < 4 then
  begin
    ShowMessage('PIN должен содержать минимум 4 цифры');
    CheckAndRequestPIN;
    Exit;
  end;

  Salt := TGUID.NewGuid.ToString;
  DeviceID := TDatabaseKeyManager.GetAndroidDeviceID;
  Combined := PIN + DeviceID + Salt;
  Hash := THashSHA2.Create;
  Hash.Update(TEncoding.UTF8.GetBytes(Combined));
  HashBytes := Hash.HashAsBytes;

  PINHash := '';
  for I := 0 to Length(HashBytes) - 1 do
    PINHash := PINHash + IntToHex(HashBytes[I], 2);

  TDatabaseKeyManager.SetSharedPrefString(PIN_SALT_KEY, Salt);
  TDatabaseKeyManager.SetSharedPrefString(PIN_HASH_KEY, PINHash);

  try
    // 🔑 Application-level encryption: храним PIN в памяти для шифрования/дешифрования полей
    TDatabaseKeyManager.SetCurrentPIN(PIN);

    if not TFile.Exists(System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'audit.sqlite')) then
    begin
      dmLocDB.InitDatabase;
    end;

    FPinVerified := True;
    LoadTasks;
  except
    on E: Exception do
    begin
      ShowMessage('Ошибка инициализации базы данных: ' + E.Message);
      CheckAndRequestPIN;
    end;
  end;
end;

procedure TformMain.OnPINEntered(const PIN: string);
const
  PIN_HASH_KEY = 'pin_hash';
  PIN_SALT_KEY = 'pin_salt';
var
  StoredHash, Salt, PINHash: string;
  Hash: THashSHA2;
  HashBytes: TBytes;
  I: Integer;
  Combined: string;
  DeviceID: string;
  IsValid: Boolean;
begin
  StoredHash := TDatabaseKeyManager.GetSharedPrefString(PIN_HASH_KEY, '');
  Salt := TDatabaseKeyManager.GetSharedPrefString(PIN_SALT_KEY, '');

  DeviceID := TDatabaseKeyManager.GetAndroidDeviceID;
  Combined := PIN + DeviceID + Salt;
  Hash := THashSHA2.Create;
  Hash.Update(TEncoding.UTF8.GetBytes(Combined));
  HashBytes := Hash.HashAsBytes;

  PINHash := '';
  for I := 0 to Length(HashBytes) - 1 do
    PINHash := PINHash + IntToHex(HashBytes[I], 2);

  IsValid := (StoredHash <> '') and (StoredHash = PINHash);
  if IsValid then
  begin
    try
      // 🔑 Application-level encryption: сохраняем PIN в памяти для дешифрования полей
      TDatabaseKeyManager.SetCurrentPIN(PIN);

      if not TFile.Exists(System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'audit.sqlite')) then
      begin
        dmLocDB.InitDatabase;
      end;

      FPinVerified := True;
      LoadTasks;
    except
      on E: Exception do
      begin
        ShowMessage('Ошибка открытия базы данных: ' + E.Message);
        CheckAndRequestPIN;
      end;
    end;
  end
  else
  begin
    ShowMessage('Неверный PIN. Попробуйте снова.');
    CheckAndRequestPIN;
  end;
end;

procedure TformMain.LoadTasks;
var
  Item: TListViewItem;
begin
  lvTasks.BeginUpdate;
  try
    lvTasks.Items.Clear;

    dmLocDB.FDQuery1.Close;
    dmLocDB.FDQuery1.SQL.Text := 'SELECT id, title, description, status FROM tasks ORDER BY id DESC';
    dmLocDB.FDQuery1.Open;

    while not dmLocDB.FDQuery1.Eof do
    begin
      Item := lvTasks.Items.Add;
      // 🔑 Application-level encryption: расшифровка полей при чтении
      Item.Text := TDatabaseKeyManager.DecryptField(dmLocDB.FDQuery1.FieldByName('title').AsString);
      Item.Detail := TDatabaseKeyManager.DecryptField(dmLocDB.FDQuery1.FieldByName('description').AsString);
      Item.Tag := dmLocDB.FDQuery1.FieldByName('id').AsInteger;

      dmLocDB.FDQuery1.Next;
    end;
  finally
    lvTasks.EndUpdate;
  end;
end;

procedure TformMain.lsMainLocationChanged(Sender: TObject; const OldLocation,
  NewLocation: TLocationCoord2D);
var
  JSCode: string;
begin
  FCurrentLat := NewLocation.Latitude;
  FCurrentLon := NewLocation.Longitude;

  lblCoords.Text := Format('Широта: %.5f, Долгота: %.5f', [FCurrentLat, FCurrentLon]);

  JSCode := Format('updateLocation(%s, %s);',
    [StringReplace(FloatToStr(FCurrentLat), ',', '.', [rfReplaceAll]),
     StringReplace(FloatToStr(FCurrentLon), ',', '.', [rfReplaceAll])]);

  wbMaps.EvaluateJavaScript(JSCode);
end;

procedure TformMain.lvTasksItemClick(const Sender: TObject;
  const AItem: TListViewItem);
begin
  btnPhoto.Enabled := Assigned(AItem);
end;

end.
