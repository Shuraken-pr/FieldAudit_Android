unit frmMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ListView.Types, FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base, FMX.ListView, FMX.MediaLibrary, System.Actions,
  FMX.ActnList, FMX.StdActns, FMX.Platform, System.IOUtils, System.StrUtils,
  System.Sensors, FMX.Maps, System.Sensors.Components, FMX.WebBrowser,
  FMX.Objects;

type
  TForm1 = class(TForm)
    ToolBar1: TToolBar;
    lblTitle: TLabel;
    lvTasks: TListView;
    alMain: TActionList;
    btnTakePhoto: TButton;
    lsMain: TLocationSensor;
    lblCoords: TLabel;
    wbMaps: TWebBrowser;
    pnlPhotoViewer: TPanel;
    imgPhoto: TImage;
    btnCloseViewer: TButton;
    btnPhoto: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure btnTakePhotoClick(Sender: TObject);
    procedure lsMainLocationChanged(Sender: TObject; const OldLocation,
      NewLocation: TLocationCoord2D);
    procedure btnCloseViewerClick(Sender: TObject);
    procedure btnPhotoClick(Sender: TObject);
    procedure lvTasksItemClick(const Sender: TObject;
      const AItem: TListViewItem);
  private
    FLoadedOnce: Boolean;
    FCurrentLat, FCurrentLon: Double; // Храним последние координаты
    procedure LoadTasks;
    procedure DoDidFinish(Image: TBitmap);
    procedure DoDidCancel;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses dmLocalDb;

{$R *.fmx}

{ TForm1 }

procedure TForm1.btnCloseViewerClick(Sender: TObject);
begin
  pnlPhotoViewer.Visible := False;
  wbMaps.Visible := true;
  imgPhoto.Bitmap.Clear(TAlphaColorRec.Null); // Освобождаем память
end;

procedure TForm1.btnPhotoClick(Sender: TObject);
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
      // Загружаем картинку
      imgPhoto.Bitmap.LoadFromFile(FilePath);
      // Показываем панель просмотра
      pnlPhotoViewer.Visible := True;
      wbMaps.Visible := false;
    except
      on E: Exception do
        ShowMessage('Ошибка открытия фото: ' + E.Message);
    end;
  end
  else
    ShowMessage('Для этой записи нет фотографии.');
end;

procedure TForm1.btnTakePhotoClick(Sender: TObject);
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

procedure TForm1.DoDidCancel;
begin
  ShowMessage('Съемка отменена');
end;

procedure TForm1.DoDidFinish(Image: TBitmap);
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

procedure TForm1.FormActivate(Sender: TObject);
begin
  // Перезагружаем список при каждом возврате на форму (например, после добавления задачи)
  // Используем флаг, чтобы не грузить дважды при первом старте
  if not FLoadedOnce then
  begin
    LoadTasks;
    FLoadedOnce := True;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
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

procedure TForm1.LoadTasks;
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

procedure TForm1.lsMainLocationChanged(Sender: TObject; const OldLocation,
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

procedure TForm1.lvTasksItemClick(const Sender: TObject;
  const AItem: TListViewItem);
begin
  btnPhoto.Enabled := Assigned(AItem);
end;

end.
