program TestRunner;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.UI,
  TestSessionManager in 'TestSessionManager.pas',
  TestJsonParsing in 'TestJsonParsing.pas',
  TestLocalDb in 'TestLocalDb.pas',
  TestJpegUtils in 'TestJpegUtils.pas',
  TestSQLiteEncryption in 'TestSQLiteEncryption.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NunitLogger: ITestLogger;
  SQLiteDriverLink: TFDPhysSQLiteDriverLink;
  FDWaitCursor: TFDGUIxWaitCursor;

// Initialize SQLite3 Multiple Ciphers driver for test encryption support
procedure InitSQLiteDriver;
var
  DLLPath: string;
begin
  SQLiteDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  DLLPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'sqlite3mc.dll');
  if TFile.Exists(DLLPath) then
  begin
    SQLiteDriverLink.VendorLib := DLLPath;
    Writeln('SQLite3MC loaded: ' + DLLPath);
  end
  else
  begin
    Writeln('WARNING: sqlite3mc.dll not found at: ' + DLLPath);
    Writeln('Encryption tests will fail!');
  end;
end;

procedure DoneSQLiteDriver;
begin
  if Assigned(SQLiteDriverLink) then
    SQLiteDriverLink.Free;
end;

begin
  ReportMemoryLeaksOnShutdown := True;

  // Create global wait cursor for FireDAC (needed for TFDSQLiteSecurity)
  FDWaitCursor := TFDGUIxWaitCursor.Create(nil);

  try
    try
      // Initialize SQLite3MC driver for encryption tests
      InitSQLiteDriver;

      // Создаём раннер
      Runner := TDUnitX.CreateRunner;
      Runner.UseRTTI := True;

      // Добавляем консольный логгер
      Logger := TDUnitXConsoleLogger.Create(True);
      Runner.AddLogger(Logger);

      // Добавляем NUnit-логгер для CI/CD
      NunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      Runner.AddLogger(NunitLogger);

      // Запускаем тесты
      Writeln('=== Android Delphi Client Tests ===');
      Writeln('Запуск тестов...');
      Writeln('');

      Results := Runner.Execute;

      Writeln('');
      Writeln(Format('Всего тестов: %d', [Results.TestCount]));
      Writeln(Format('Пройдено: %d', [Results.PassCount]));
      Writeln(Format('Провалено: %d', [Results.FailureCount]));
      Writeln(Format('Ошибок: %d', [Results.ErrorCount]));

      // Выходим с кодом ошибки, если есть проваленные тесты
      if not Results.AllPassed then
        System.ExitCode := 1
      else
        System.ExitCode := 0;

      Writeln('');
      if Results.AllPassed then
        Writeln('ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!')
      else
        Writeln('ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ!');

    finally
      DoneSQLiteDriver;
      FDWaitCursor.Free;
    end;

  except
    on E: Exception do
    begin
      Writeln('Критическая ошибка: ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
