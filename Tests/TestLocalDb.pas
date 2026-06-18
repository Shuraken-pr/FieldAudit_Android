unit TestLocalDb;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  Data.DB,
  FireDAC.DApt,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async;

type
  // Тестовая запись для задачи
  TTaskRecord = record
    Id: Integer;
    Title: string;
    Description: string;
    Latitude: Double;
    Longitude: Double;
    IsSynced: Boolean;
  end;

  [TestFixture]
  TTestLocalDb = class
  private
    FTestDbPath: string;
    FConnection: TFDConnection;
    
    procedure InitializeTestDb;
    procedure CreateTable;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure TestDatabaseConnection;
    
    [Test]
    procedure TestCreateTask;
    
    [Test]
    procedure TestGetAllTasks;
    
    [Test]
    procedure TestUpdateTask;
    
    [Test]
    procedure TestDeleteTask;
    
    [Test]
    procedure TestMarkAsSynced;
    
    [Test]
    procedure TestGetUnsyncedTasks;
    
    [Test]
    procedure TestTaskWithCoordinates;
  end;

implementation

procedure TTestLocalDb.Setup;
begin
  FTestDbPath := TPath.Combine(TPath.GetTempPath, 'test_local_' + 
    IntToStr(GetTickCount) + '.db');
  
  FConnection := TFDConnection.Create(nil);
  FConnection.Params.Database := FTestDbPath;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Connected := True;
  
  InitializeTestDb;
end;

procedure TTestLocalDb.TearDown;
begin
  if Assigned(FConnection) then
  begin
    FConnection.Connected := False;
    FConnection.Free;
  end;
  
  if TFile.Exists(FTestDbPath) then
    TFile.Delete(FTestDbPath);
end;

procedure TTestLocalDb.InitializeTestDb;
begin
  CreateTable;
end;

procedure TTestLocalDb.CreateTable;
var
  Qry: TFDQuery;
begin
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 
      'CREATE TABLE IF NOT EXISTS tasks (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  title TEXT NOT NULL,' +
      '  description TEXT,' +
      '  latitude REAL,' +
      '  longitude REAL,' +
      '  is_synced INTEGER DEFAULT 0' +
      ')';
    Qry.ExecSQL;
  finally
    Qry.Free;
  end;
end;

procedure TTestLocalDb.TestDatabaseConnection;
begin
  Assert.IsTrue(FConnection.Connected, 'Соединение с БД должно быть установлено');
end;

procedure TTestLocalDb.TestCreateTask;
var
  Qry: TFDQuery;
  TaskId: Integer;
begin
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 
      'INSERT INTO tasks (title, description, latitude, longitude) ' +
      'VALUES (:title, :desc, :lat, :lon)';
    Qry.ParamByName('title').AsString := 'Test Task';
    Qry.ParamByName('desc').AsString := 'Test Description';
    Qry.ParamByName('lat').AsFloat := 55.75;
    Qry.ParamByName('lon').AsFloat := 37.62;
    Qry.ExecSQL;
    
    // Получаем ID последней вставленной записи
    Qry.SQL.Text := 'SELECT last_insert_rowid() as id';
    Qry.Open;
    TaskId := Qry.FieldByName('id').AsInteger;
    
    Assert.IsTrue(TaskId > 0, 'ID задачи должен быть положительным');
  finally
    Qry.Free;
  end;
end;

procedure TTestLocalDb.TestGetAllTasks;
var
  Qry: TFDQuery;
  TaskCount: Integer;
begin
  // Создаём 2 задачи
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    
    Qry.SQL.Text := 'INSERT INTO tasks (title, description, latitude, longitude) VALUES (:t, :d, :la, :lo)';
    Qry.ParamByName('t').AsString := 'Task 1';
    Qry.ParamByName('d').AsString := 'Desc 1';
    Qry.ParamByName('la').AsFloat := 55.75;
    Qry.ParamByName('lo').AsFloat := 37.62;
    Qry.ExecSQL;
    
    Qry.ParamByName('t').AsString := 'Task 2';
    Qry.ParamByName('d').AsString := 'Desc 2';
    Qry.ParamByName('la').AsFloat := 55.76;
    Qry.ParamByName('lo').AsFloat := 37.63;
    Qry.ExecSQL;
    
    // Считаем задачи
    Qry.SQL.Text := 'SELECT COUNT(*) as cnt FROM tasks';
    Qry.Open;
    TaskCount := Qry.FieldByName('cnt').AsInteger;
    
    Assert.AreEqual(2, TaskCount, 'Должно быть 2 задачи');
  finally
    Qry.Free;
  end;
end;

procedure TTestLocalDb.TestUpdateTask;
var
  Qry: TFDQuery;
  TaskId: Integer;
  UpdatedTitle: string;
begin
  // Создаём задачу
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    
    Qry.SQL.Text := 'INSERT INTO tasks (title, description, latitude, longitude) VALUES (:t, :d, :la, :lo)';
    Qry.ParamByName('t').AsString := 'Original';
    Qry.ParamByName('d').AsString := 'Desc';
    Qry.ParamByName('la').AsFloat := 55.75;
    Qry.ParamByName('lo').AsFloat := 37.62;
    Qry.ExecSQL;
    
    Qry.SQL.Text := 'SELECT last_insert_rowid() as id';
    Qry.Open;
    TaskId := Qry.FieldByName('id').AsInteger;
    
    // Обновляем задачу
    Qry.SQL.Text := 'UPDATE tasks SET title = :t, latitude = :la WHERE id = :id';
    Qry.ParamByName('t').AsString := 'Updated';
    Qry.ParamByName('la').AsFloat := 55.76;
    Qry.ParamByName('id').AsInteger := TaskId;
    Qry.ExecSQL;
    
    // Проверяем обновление
    Qry.SQL.Text := 'SELECT title, latitude FROM tasks WHERE id = :id';
    Qry.ParamByName('id').AsInteger := TaskId;
    Qry.Open;
    
    UpdatedTitle := Qry.FieldByName('title').AsString;
    Assert.AreEqual('Updated', UpdatedTitle, 'Заголовок должен обновиться');
    Assert.AreEqual(55.76, Qry.FieldByName('latitude').AsFloat, 0.001, 
      'Координаты должны обновиться');
  finally
    Qry.Free;
  end;
end;

procedure TTestLocalDb.TestDeleteTask;
var
  Qry: TFDQuery;
  TaskCount: Integer;
begin
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    
    // Создаём задачу
    Qry.SQL.Text := 'INSERT INTO tasks (title, description, latitude, longitude) VALUES (:t, :d, :la, :lo)';
    Qry.ParamByName('t').AsString := 'To Delete';
    Qry.ParamByName('d').AsString := 'Desc';
    Qry.ParamByName('la').AsFloat := 55.75;
    Qry.ParamByName('lo').AsFloat := 37.62;
    Qry.ExecSQL;
    
    // Удаляем все задачи
    Qry.SQL.Text := 'DELETE FROM tasks';
    Qry.ExecSQL;
    
    // Считаем оставшиеся
    Qry.SQL.Text := 'SELECT COUNT(*) as cnt FROM tasks';
    Qry.Open;
    TaskCount := Qry.FieldByName('cnt').AsInteger;
    
    Assert.AreEqual(0, TaskCount, 'После удаления задач не должно быть');
  finally
    Qry.Free;
  end;
end;

procedure TTestLocalDb.TestMarkAsSynced;
var
  Qry: TFDQuery;
  TaskId: Integer;
  UnsyncedCount: Integer;
begin
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    
    // Создаём задачу
    Qry.SQL.Text := 'INSERT INTO tasks (title, description, latitude, longitude) VALUES (:t, :d, :la, :lo)';
    Qry.ParamByName('t').AsString := 'Task';
    Qry.ParamByName('d').AsString := 'Desc';
    Qry.ParamByName('la').AsFloat := 55.75;
    Qry.ParamByName('lo').AsFloat := 37.62;
    Qry.ExecSQL;
    
    Qry.SQL.Text := 'SELECT last_insert_rowid() as id';
    Qry.Open;
    TaskId := Qry.FieldByName('id').AsInteger;
    
    // Проверяем, что задача несинхронизирована
    Qry.SQL.Text := 'SELECT COUNT(*) as cnt FROM tasks WHERE is_synced = 0';
    Qry.Open;
    UnsyncedCount := Qry.FieldByName('cnt').AsInteger;
    Assert.AreEqual(1, UnsyncedCount, 'Должна быть 1 несинхронизированная задача');
    
    // Помечаем как синхронизированную
    Qry.SQL.Text := 'UPDATE tasks SET is_synced = 1 WHERE id = :id';
    Qry.ParamByName('id').AsInteger := TaskId;
    Qry.ExecSQL;
    
    // Проверяем, что несинхронизированных задач нет
    Qry.SQL.Text := 'SELECT COUNT(*) as cnt FROM tasks WHERE is_synced = 0';
    Qry.Open;
    UnsyncedCount := Qry.FieldByName('cnt').AsInteger;
    Assert.AreEqual(0, UnsyncedCount, 'После синхронизации несинхронизированных не должно быть');
  finally
    Qry.Free;
  end;
end;

procedure TTestLocalDb.TestGetUnsyncedTasks;
var
  Qry: TFDQuery;
  Id1: Integer;
  UnsyncedCount: Integer;
begin
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    
    // Создаём 2 задачи
    Qry.SQL.Text := 'INSERT INTO tasks (title, description, latitude, longitude) VALUES (:t, :d, :la, :lo)';
    Qry.ParamByName('t').AsString := 'Task 1';
    Qry.ParamByName('d').AsString := 'Desc 1';
    Qry.ParamByName('la').AsFloat := 55.75;
    Qry.ParamByName('lo').AsFloat := 37.62;
    Qry.ExecSQL;
    
    Qry.SQL.Text := 'SELECT last_insert_rowid() as id';
    Qry.Open;
    Id1 := Qry.FieldByName('id').AsInteger;
    
    Qry.SQL.Text := 'INSERT INTO tasks (title, description, latitude, longitude) VALUES (:t, :d, :la, :lo)';
    Qry.ParamByName('t').AsString := 'Task 2';
    Qry.ParamByName('d').AsString := 'Desc 2';
    Qry.ParamByName('la').AsFloat := 55.76;
    Qry.ParamByName('lo').AsFloat := 37.63;
    Qry.ExecSQL;
    
    // Помечаем первую как синхронизированную
    Qry.SQL.Text := 'UPDATE tasks SET is_synced = 1 WHERE id = :id';
    Qry.ParamByName('id').AsInteger := Id1;
    Qry.ExecSQL;
    
    // Считаем несинхронизированные
    Qry.SQL.Text := 'SELECT COUNT(*) as cnt FROM tasks WHERE is_synced = 0';
    Qry.Open;
    UnsyncedCount := Qry.FieldByName('cnt').AsInteger;
    
    Assert.AreEqual(1, UnsyncedCount, 'Должна быть 1 несинхронизированная задача');
  finally
    Qry.Free;
  end;
end;

procedure TTestLocalDb.TestTaskWithCoordinates;
var
  Qry: TFDQuery;
  Lat, Lon: Double;
begin
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    
    Qry.SQL.Text := 'INSERT INTO tasks (title, description, latitude, longitude) VALUES (:t, :d, :la, :lo)';
    Qry.ParamByName('t').AsString := 'Geo Task';
    Qry.ParamByName('d').AsString := 'With coordinates';
    Qry.ParamByName('la').AsFloat := 55.7558;
    Qry.ParamByName('lo').AsFloat := 37.6173;
    Qry.ExecSQL;
    
    Qry.SQL.Text := 'SELECT latitude, longitude FROM tasks WHERE title = :t';
    Qry.ParamByName('t').AsString := 'Geo Task';
    Qry.Open;
    
    Lat := Qry.FieldByName('latitude').AsFloat;
    Lon := Qry.FieldByName('longitude').AsFloat;
    
    Assert.AreEqual(55.7558, Lat, 0.0001, 'Широта должна сохраниться точно');
    Assert.AreEqual(37.6173, Lon, 0.0001, 'Долгота должна сохраниться точно');
  finally
    Qry.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLocalDb);

end.
