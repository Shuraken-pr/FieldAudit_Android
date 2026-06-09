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

procedure TdmLocDB.InitDatabase;
var
  DBPath: string;
begin
  // 1. Определяем путь к БД
  // На Android это будет /data/user/0/com.embarcadero.ProjectName/files/audit.sqlite
  // На Windows это будет C:\Users\Alexandr\Documents\audit.sqlite
  DBPath := TPath.Combine(TPath.GetDocumentsPath, 'audit.sqlite');

  FDConnection1.Params.Clear;
  FDConnection1.Params.DriverID := 'SQLite';
  FDConnection1.Params.Database := DBPath;
  // Важно для мобильных: не блокировать UI при длительных операциях
  FDConnection1.Params.Add('LockingMode=Normal');
  FDConnection1.Params.Add('Synchronous=Normal');

  try
    FDConnection1.Open;

    // 2. Создаем таблицы
    FDConnection1.ExecSQL(
      'CREATE TABLE IF NOT EXISTS tasks (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      '  title TEXT NOT NULL UNIQUE, ' +
      '  description TEXT, ' +
      '  status TEXT DEFAULT "new", ' +
      '  latitude REAL DEFAULT 0.0, ' +   // <-- Новое поле
      '  longitude REAL DEFAULT 0.0, ' +  // <-- Новое поле
      '  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ' +
      '  is_synced INTEGER DEFAULT 0 ' +
      ');'
    );

    // Для отладки добавим пару тестовых записей, если таблица пуста
    FDConnection1.ExecSQL('INSERT OR IGNORE INTO tasks (title, description) VALUES ("Проверка склада А", "Проверить наличие огнетушителей");');
    FDConnection1.ExecSQL('INSERT OR IGNORE INTO tasks (title, description) VALUES ("Обход периметра", "Проверить целостность забора");');

  except
    on E: Exception do
    begin
      // В мобильном приложении критично показать ошибку при старте
      raise Exception.Create('Ошибка инициализации БД: ' + E.Message);
    end;
  end;
end;

end.
