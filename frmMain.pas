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
  System.Net.HttpClient, System.Net.URLClient, System.NetConsts;

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
    FCurrentLat, FCurrentLon: Double;
    procedure LoadTasks;
    procedure DoDidFinish(Image: TBitmap);
    procedure DoDidCancel;
    procedure DoLogin;
    procedure ValidateCert(
      const Sender: TObject; const ARequest: TURLRequest;
      const Certificate: TCertificate; var Accepted: Boolean);
  public
    { Public declarations }
  end;

var
  formMain: TformMain;

implementation

uses dmLocalDb, frmPhotoView, SessionManager, uLogin;

{$R *.fmx}

procedure TformMain.acSynchronizeExecute(Sender: TObject);
var
  Query: TFDQuery;
  JsonArr: TJSONArray;
  JObj, Details: TJSONObject;
  Payload: TJSONObject;
  HTTP: THTTPClient;
  Response: IHTTPResponse;
  ResponseStr: string;
  PayloadStream: TStringStream;
begin
  if not AppSession.IsLoggedIn then
  begin
    ShowMessage('Сессия истекла. Пожалуйста, войдите в систему заново.');
    DoLogin;
    Exit;
  end;

  Query := TFDQuery.Create(nil);
  Query.Connection := dmLocDB.FDConnection1;
  JsonArr := TJSONArray.Create;
  Payload := nil;

  try
    Query.SQL.Text := 'SELECT id, title, description, latitude, longitude FROM tasks WHERE is_synced = 0';
    Query.Open;

    if Query.IsEmpty then
    begin
      ShowMessage('Все данные уже синхронизированы.');
      Exit;
    end;

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

    Payload := TJSONObject.Create;
    Payload.AddPair('AJsonData', JsonArr);

    HTTP := THTTPClient.Create;
    try
      HTTP.ConnectionTimeout := 30000;
      HTTP.ResponseTimeout := 60000;

      // Принимаем самоподписанный сертификат (только для LAN/отладки)
      HTTP.OnValidateServerCertificate := ValidateCert;

      HTTP.CustomHeaders['X-Session-Token'] := AppSession.Token;
      HTTP.ContentType := 'application/json';

      PayloadStream := TStringStream.Create(Payload.ToString, TEncoding.UTF8);
      try
        Response := HTTP.Post(
          AppSession.ServerURL + '/datasnap/rest/TServerMethods1/SyncUpload',
          PayloadStream);

        ResponseStr := Response.ContentAsString;

        if Response.StatusCode = 200 then
        begin
          dmLocDB.FDConnection1.ExecSQL('UPDATE tasks SET is_synced = 1 WHERE is_synced = 0');
          LoadTasks;
          ShowMessage('Синхронизация успешна: ' + ResponseStr);
        end
        else if Response.StatusCode = 401 then
        begin
          AppSession.Logout;
          ShowMessage('Ваша сессия истекла. Требуется повторный вход.');
          DoLogin;
        end
        else
        begin
          ShowMessage('Ошибка сервера (Код: ' + IntToStr(Response.StatusCode) + '): ' + ResponseStr);
        end;
      finally
        PayloadStream.Free;
      end;
    finally
      HTTP.Free;
    end;

  finally
    Query.Free;
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

procedure TformMain.DoDidFinish(Image: TBitmap);
var
  Dir, FileName: string;
begin
  try
    Dir := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'photos');
    if not TDirectory.Exists(Dir) then
      TDirectory.CreateDirectory(Dir);

    FileName := System.IOUtils.TPath.Combine(Dir, FormatDateTime('yyyymmdd_hhnnss', Now) + '.jpg');

    Image.SaveToFile(FileName);

    dmLocDB.FDConnection1.ExecSQL(
      'INSERT INTO tasks (title, description, status, latitude, longitude) VALUES (?, ?, ?, ?, ?)',
     ['Фото-отчет ' + FormatDateTime('hh_mm_ss', Now), FileName, 'new', FCurrentLat, FCurrentLon]);

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

procedure TformMain.ValidateCert(const Sender: TObject;
  const ARequest: TURLRequest; const Certificate: TCertificate;
  var Accepted: Boolean);
begin
  //не использовать для Production.
  Accepted := true;
end;

end.
