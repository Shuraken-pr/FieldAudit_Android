unit frmMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ListView.Types, FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base, FMX.ListView, FMX.MediaLibrary, System.Actions,
  FMX.ActnList, FMX.StdActns, FMX.Platform, System.IOUtils, System.StrUtils,
  System.Sensors, FMX.Maps, System.Sensors.Components, FMX.WebBrowser,
  FMX.Objects, REST.Types, REST.Client, Data.Bind.Components,
  Data.Bind.ObjectScope, System.JSON, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, Data.DB,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client, System.ImageList, FMX.ImgList,
  System.Net.HttpClient;

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
    RESTClient1: TRESTClient;
    RESTRequest1: TRESTRequest;
    RESTResponse1: TRESTResponse;
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
    FCurrentLat, FCurrentLon: Double; // Храним последние координаты
    procedure LoadTasks;
    procedure DoDidFinish(Image: TBitmap);
    procedure DoDidCancel;
    procedure DoLogin;
  public
    { Public declarations }
  end;

var
  formMain: TformMain;

implementation

uses dmLocalDb, frmPhotoView, SessionManager, uLogin;

{$R *.fmx}

{ TformMain }

procedure TformMain.acSynchronizeExecute(Sender: TObject);
var
  Query: TFDQuery;
  JsonArr: TJSONArray;
  JObj, Details: TJSONObject;
  Payload: TJSONObject;
  ResponseStr: string;
begin
  // 1. Проверка авторизации перед началом любых действий
  if not AppSession.IsLoggedIn then
  begin
    ShowMessage('Сессия истекла. Пожалуйста, войдите в систему заново.');
    DoLogin;
    Exit;
  end;

  // Инициализация
  Query := TFDQuery.Create(nil);
  Query.Connection := dmLocDB.FDConnection1;
  JsonArr := TJSONArray.Create;
  Payload := nil;

  try
    // 2. Выбираем несохранённые записи
    Query.SQL.Text := 'SELECT id, title, description, latitude, longitude FROM tasks WHERE is_synced = 0';
    Query.Open;

    if Query.IsEmpty then
    begin
      ShowMessage('Все данные уже синхронизированы.');
      Exit;
    end;

    // 3. Формируем JSON-массив
    while not Query.Eof do
    begin
      JObj := TJSONObject.Create;
      JObj.AddPair('event_type', TJSONString.Create('mobile_audit'));

      Details := TJSONObject.Create;
      Details.AddPair('photo_path', TJSONString.Create(Query.FieldByName('description').AsString));
      Details.AddPair('lat', TJSONNumber.Create(Query.FieldByName('latitude').AsFloat));
      Details.AddPair('lon', TJSONNumber.Create(Query.FieldByName('longitude').AsFloat));

      JObj.AddPair('details', Details);
      JsonArr.Add(JObj);

      Query.Next;
    end;

    // 4. Создаём обёртку
    Payload := TJSONObject.Create;
    Payload.AddPair('AJsonData', JsonArr);

    // 5. Настройка REST-запроса
    RESTClient1.BaseURL := AppSession.ServerURL;// 'http://192.168.1.113:8082'; // ⚠️ Проверьте ваш актуальный IP
    RESTRequest1.Client := RESTClient1;
    RESTRequest1.Response := RESTResponse1;
    RESTRequest1.Resource := 'datasnap/rest/TServerMethods1/SyncUpload';
    RESTRequest1.Method := TRESTRequestMethod.rmPOST;
    RESTRequest1.Params.Clear;

    // Добавляем динамический токен в заголовок
    with RESTRequest1.Params.AddItem do
    begin
      Name := 'X-Session-Token';
      Value := AppSession.Token;
      Kind := TRESTRequestParameterKind.pkHTTPHEADER;
      Options := [TRESTRequestParameterOption.poDoNotEncode];
    end;

    RESTRequest1.Body.ClearBody;
    RESTRequest1.Body.Add(Payload.ToString, TRESTContentType.ctAPPLICATION_JSON);

    // 6. Выполнение и УНИВЕРСАЛЬНАЯ обработка ответа (работает во всех версиях Delphi)
    try
      RESTRequest1.Execute;
    except
      on E: Exception do
      begin
        // Даже при возникновении исключения, RESTResponse1 содержит ответ сервера
        if RESTResponse1.StatusCode = 401 then
        begin
          AppSession.Logout;
          ShowMessage('Ваша сессия истекла или была аннулирована. Требуется повторный вход.');
          DoLogin;
          Exit;
        end;

        // Если это другая ошибка, показываем её и прерываем выполнение
        ShowMessage('Ошибка сети: ' + E.Message);
        Exit;
      end;
    end;

    // 7. Если мы здесь, значит исключения не было. Проверяем успешный статус.
    if RESTResponse1.StatusCode = 200 then
    begin
      ResponseStr := RESTResponse1.Content;
      // Сервер вернул 200 OK → помечаем локальные записи как синхронизированные
      dmLocDB.FDConnection1.ExecSQL('UPDATE tasks SET is_synced = 1 WHERE is_synced = 0');
      LoadTasks; // Обновляем UI
      ShowMessage('Синхронизация успешна: ' + ResponseStr);
    end
    else
    begin
      ShowMessage('Ошибка сервера (Код: ' + IntToStr(RESTResponse1.StatusCode) + '): ' + RESTResponse1.Content);
    end;

  finally
    Query.Free;
    // Освобождаем ТОЛЬКО Payload (он владеет JsonArr). Если Payload не создан, освобождаем JsonArr.
    if Assigned(Payload) then
      Payload.Free
    else
      JsonArr.Free;
  end;
end;

procedure TformMain.btnPhotoClick(Sender: TObject);
var
  FilePath: string;
begin
  if not Assigned(lvTasks.Selected) then Exit;

  // В нашем коде путь к файлу хранится в Detail
  FilePath := TListViewItem(lvTasks.Selected).Detail;

  // Проверяем, что это файл и он существует
  if (FilePath <> '') and TFile.Exists(FilePath) then
  begin
    try
      if not Assigned(formPhotoView) then
        formPhotoView := TformPhotoView.Create(nil);
      // Загружаем картинку
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
  // Запрашиваем сервис камеры
  if TPlatformServices.Current.SupportsPlatformService(IFMXCameraService, Service) then
  begin
    // Настройки съемки
    Params.Editable := False;           // Не открывать редактор после съемки
    Params.NeedSaveToAlbum := False;    // Не сохранять в галерею (мы сохраним сами в БД)
    // ВАЖНО: Ограничиваем разрешение, чтобы не забить память телефона
    Params.RequiredResolution := TSize.Create(1024, 1024);

    // Назначаем обработчики событий
    Params.OnDidFinishTaking := DoDidFinish;
    Params.OnDidCancelTaking := DoDidCancel;

    // Запускаем камеру
    Service.TakePhoto(Sender as TControl, Params);
  end
  else
    ShowMessage('Камера недоступна на этом устройстве');
end;

procedure TformMain.DoDidCancel;
begin
  ShowMessage('Съемка отменена');
end;

procedure TformMain.DoDidFinish(Image: TBitmap);
var
  Dir, FileName: string;
begin
  try
    // Создаем папку для фото, если нет
    Dir := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'photos');
    if not TDirectory.Exists(Dir) then
      TDirectory.CreateDirectory(Dir);

    // Уникальное имя файла
    FileName := System.IOUtils.TPath.Combine(Dir, FormatDateTime('yyyymmdd_hhnnss', Now) + '.jpg');

    // Сохраняем
    Image.SaveToFile(FileName);

    // Пишем в БД
    dmLocDB.FDConnection1.ExecSQL(
      'INSERT INTO tasks (title, description, status, latitude, longitude) VALUES (?, ?, ?, ?, ?)',
     ['Фото-отчет ' + FormatDateTime('hh_mm_ss', Now), FileName, 'new', FCurrentLat, FCurrentLon]);

    // Обновляем список
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
    // После успешного входа автоматически перезапускаем синхронизацию
    acSynchronize.Execute;
  end;
  frmLogin.Show;
end;

procedure TformMain.FormActivate(Sender: TObject);
begin
  // Перезагружаем список при каждом возврате на форму (например, после добавления задачи)
  // Используем флаг, чтобы не грузить дважды при первом старте
  if not FLoadedOnce then
  begin
    LoadTasks;
    FLoadedOnce := True;
  end;
end;

procedure TformMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(formPhotoView) then
    FreeAndNil(formPhotoView);
end;

procedure TformMain.FormCreate(Sender: TObject);
var
  FilePath: string;
begin
  lsMain.Active := True;

  // Загрузка локального HTML файла
  FilePath := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'map.html');
  if TFile.Exists(FilePath) then
    wbMaps.Navigate('file://' + FilePath)
  else
    wbMaps.Navigate('about:blank');

  FLoadedOnce := false;
  LoadTasks;
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
      Item.Text := dmLocDB.FDQuery1.FieldByName('title').AsString;
      Item.Detail := dmLocDB.FDQuery1.FieldByName('description').AsString;
      // Можно менять цвет или иконку в зависимости от статуса
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

  // Формируем вызов JS-функции из нашего HTML
  // Используем точку как разделитель дробной части (JS требует точку, а не запятую)
  JSCode := Format('updateLocation(%s, %s);',
    [StringReplace(FloatToStr(FCurrentLat), ',', '.', [rfReplaceAll]),
     StringReplace(FloatToStr(FCurrentLon), ',', '.', [rfReplaceAll])]);

  // Выполняем скрипт в браузере
  wbMaps.EvaluateJavaScript(JSCode);
end;

procedure TformMain.lvTasksItemClick(const Sender: TObject;
  const AItem: TListViewItem);
begin
  btnPhoto.Enabled := Assigned(AItem);
end;

end.
