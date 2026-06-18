program TestRunner;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  System.SysUtils,
  TestSessionManager in 'TestSessionManager.pas',
  TestJsonParsing in 'TestJsonParsing.pas',
  TestLocalDb in 'TestLocalDb.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NunitLogger: ITestLogger;
begin
  ReportMemoryLeaksOnShutdown := True;
  
  try
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
      
  except
    on E: Exception do
    begin
      Writeln('Критическая ошибка: ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
