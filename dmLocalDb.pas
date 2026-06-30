unit dmLocalDb;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.Phys.SQLiteDef, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.FMXUI.Wait, FireDAC.Comp.UI, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, System.IOUtils;

type
  TdmLocDB = class(TDataModule)
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    FDConnection1: TFDConnection;
    FDQuery1: TFDQuery;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    procedure DataModuleCreate(Sender: TObject);
  private
    procedure MigrateDatabase(FromVersion: Integer);
  public
    procedure InitDatabase;
    procedure InitDatabaseWithPassword(const DBPassword: string);
    procedure EncryptExistingDatabase(const DBPassword: string);
    function IsDatabaseEncrypted: Boolean;
    procedure ReconnectWithPassword(const DBPassword: string);
  end;

var
  dmLocDB: TdmLocDB;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

{ TDataModule2 }

procedure TdmLocDB.DataModuleCreate(Sender: TObject);
{$IFDEF MSWINDOWS}
var
  DLLPath: string;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  // For Windows: load sqlite3mc.dll from app directory or Documents (for tests)
  DLLPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'sqlite3mc.dll');
  if TFile.Exists(DLLPath) then
    FDPhysSQLiteDriverLink1.VendorLib := DLLPath
  else
  begin
    DLLPath := TPath.Combine(TPath.GetDocumentsPath, 'sqlite3mc.dll');
    if TFile.Exists(DLLPath) then
      FDPhysSQLiteDriverLink1.VendorLib := DLLPath;
  end;
{$ENDIF}

  InitDatabase;
end;

procedure TdmLocDB.MigrateDatabase(FromVersion: Integer);
begin
  if FromVersion < 2 then
  begin
    try
      FDConnection1.ExecSQL('ALTER TABLE tasks ADD COLUMN server_file_id TEXT');
    except
      // column may already exist
    end;
    try
      FDConnection1.ExecSQL('ALTER TABLE tasks ADD COLUMN upload_attempts INTEGER DEFAULT 0');
    except
    end;
    try
      FDConnection1.ExecSQL('ALTER TABLE tasks ADD COLUMN last_error TEXT');
    except
    end;
    try
      FDConnection1.ExecSQL('ALTER TABLE tasks ADD COLUMN can_delete_local INTEGER DEFAULT 0');
    except
    end;
    FDConnection1.ExecSQL('PRAGMA user_version = 2');
  end;
end;

procedure TdmLocDB.InitDatabase;
var
  DBPath: string;
  DBVersion: Integer;
begin
  DBPath := TPath.Combine(TPath.GetDocumentsPath, 'audit.sqlite');

  FDConnection1.Params.Clear;
  FDConnection1.Params.DriverID := 'SQLite';
  FDConnection1.Params.Database := DBPath;
  FDConnection1.Params.Add('LockingMode=Normal');
  FDConnection1.Params.Add('Synchronous=Normal');

  try
    FDConnection1.Open;

    try
      DBVersion := FDConnection1.ExecSQLScalar('PRAGMA user_version');
    except
      DBVersion := 0;
    end;

    if DBVersion < 1 then
    begin
      FDConnection1.ExecSQL(
        'CREATE TABLE IF NOT EXISTS tasks (' +
        '  id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        '  title TEXT NOT NULL UNIQUE, ' +
        '  description TEXT, ' +
        '  status TEXT DEFAULT "new", ' +
        '  latitude REAL DEFAULT 0.0, ' +
        '  longitude REAL DEFAULT 0.0, ' +
        '  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ' +
        '  is_synced INTEGER DEFAULT 0, ' +
        '  server_file_id TEXT, ' +
        '  upload_attempts INTEGER DEFAULT 0, ' +
        '  last_error TEXT, ' +
        '  can_delete_local INTEGER DEFAULT 0 ' +
        ');'
      );
      FDConnection1.ExecSQL('PRAGMA user_version = 1');
    end;

    if DBVersion < 2 then
      MigrateDatabase(DBVersion);

    FDConnection1.ExecSQL('INSERT OR IGNORE INTO tasks (title, description) VALUES ("Инспекция участка А", "Проверка состояния оборудования");');
    FDConnection1.ExecSQL('INSERT OR IGNORE INTO tasks (title, description) VALUES ("Обход территории", "Проверка ограждений и вывесок");');

  except
    on E: Exception do
      raise Exception.Create('Ошибка инициализации БД: ' + E.Message);
  end;
end;

procedure TdmLocDB.InitDatabaseWithPassword(const DBPassword: string);
var
  DBPath: string;
  DBVersion: Integer;
begin
  DBPath := TPath.Combine(TPath.GetDocumentsPath, 'audit.sqlite');

  FDConnection1.Params.Clear;
  FDConnection1.Params.DriverID := 'SQLite';
  FDConnection1.Params.Database := DBPath;
  FDConnection1.Params.Add('LockingMode=Normal');
  FDConnection1.Params.Add('Synchronous=Normal');
  if DBPassword <> '' then
    FDConnection1.Params.Add('Password=' + DBPassword);

  try
    FDConnection1.Open;

    try
      DBVersion := FDConnection1.ExecSQLScalar('PRAGMA user_version');
    except
      DBVersion := 0;
    end;

    if DBVersion < 1 then
    begin
      FDConnection1.ExecSQL(
        'CREATE TABLE IF NOT EXISTS tasks (' +
        '  id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        '  title TEXT NOT NULL UNIQUE, ' +
        '  description TEXT, ' +
        '  status TEXT DEFAULT "new", ' +
        '  latitude REAL DEFAULT 0.0, ' +
        '  longitude REAL DEFAULT 0.0, ' +
        '  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ' +
        '  is_synced INTEGER DEFAULT 0, ' +
        '  server_file_id TEXT, ' +
        '  upload_attempts INTEGER DEFAULT 0, ' +
        '  last_error TEXT, ' +
        '  can_delete_local INTEGER DEFAULT 0 ' +
        ');'
      );
      FDConnection1.ExecSQL('PRAGMA user_version = 1');
    end;

    if DBVersion < 2 then
      MigrateDatabase(DBVersion);

    FDConnection1.ExecSQL('INSERT OR IGNORE INTO tasks (title, description) VALUES ("Инспекция участка А", "Проверка состояния оборудования");');
    FDConnection1.ExecSQL('INSERT OR IGNORE INTO tasks (title, description) VALUES ("Обход территории", "Проверка ограждений и вывесок");');

  except
    on E: Exception do
      raise Exception.Create('Ошибка инициализации БД: ' + E.Message);
  end;
end;

procedure TdmLocDB.EncryptExistingDatabase(const DBPassword: string);
var
  DBPath: string;
  TempPath: string;
  TempConn: TFDConnection;
  DriverLink: TFDPhysSQLiteDriverLink;
  WaitCursor: TFDGUIxWaitCursor;
begin
  DBPath := TPath.Combine(TPath.GetDocumentsPath, 'audit.sqlite');
  TempPath := TPath.Combine(TPath.GetDocumentsPath, 'audit_temp.sqlite');

  if not TFile.Exists(DBPath) then
    raise Exception.Create('Database file not found: ' + DBPath);

  // Close current connection
  FDConnection1.Connected := False;

  // Create temp connection for encryption
  DriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  TempConn := TFDConnection.Create(nil);
  WaitCursor := TFDGUIxWaitCursor.Create(nil);
  try
    // Copy original to temp
    TFile.Copy(DBPath, TempPath, True);

    // Open temp with new password (creates encrypted copy)
    TempConn.Params.DriverID := 'SQLite';
    TempConn.Params.Database := TempPath;
    TempConn.Params.Add('Password=' + DBPassword);
    TempConn.Open;
    TempConn.Close;

    // Delete original, rename temp
    TFile.Delete(DBPath);
    TFile.Move(TempPath, DBPath);

    // Reconnect main connection with password
    ReconnectWithPassword(DBPassword);
  finally
    WaitCursor.Free;
    TempConn.Free;
    DriverLink.Free;
  end;
end;

function TdmLocDB.IsDatabaseEncrypted: Boolean;
var
  DBPath: string;
  TempConn: TFDConnection;
begin
  DBPath := TPath.Combine(TPath.GetDocumentsPath, 'audit.sqlite');
  Result := False;

  if not TFile.Exists(DBPath) then
    Exit;

  TempConn := TFDConnection.Create(nil);
  try
    TempConn.Params.DriverID := 'SQLite';
    TempConn.Params.Database := DBPath;
    try
      TempConn.Open;
      TempConn.Close;
      Result := False; // Opened without password = not encrypted
    except
      Result := True; // Failed to open without password = encrypted
    end;
  finally
    TempConn.Free;
  end;
end;

procedure TdmLocDB.ReconnectWithPassword(const DBPassword: string);
begin
  FDConnection1.Connected := False;
  FDConnection1.Params.Clear;
  FDConnection1.Params.DriverID := 'SQLite';
  FDConnection1.Params.Database := TPath.Combine(TPath.GetDocumentsPath, 'audit.sqlite');
  FDConnection1.Params.Add('LockingMode=Normal');
  FDConnection1.Params.Add('Synchronous=Normal');
  if DBPassword <> '' then
    FDConnection1.Params.Add('Password=' + DBPassword);
  FDConnection1.Open;
end;

end.
