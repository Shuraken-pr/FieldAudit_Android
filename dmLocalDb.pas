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
    procedure InitDatabase;
    procedure MigrateDatabase(FromVersion: Integer);
  public
    { Public declarations }
  end;

var
  dmLocDB: TdmLocDB;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

{ TDataModule2 }

procedure TdmLocDB.DataModuleCreate(Sender: TObject);
begin
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

end.
