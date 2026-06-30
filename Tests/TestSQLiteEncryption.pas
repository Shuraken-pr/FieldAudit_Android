unit TestSQLiteEncryption;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Threading,
  FireDAC.Comp.Client,
  FireDAC.Comp.UI,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.Def;

type
  [TestFixture]
  TTestSQLiteEncryption = class
  private
    FConnection: TFDConnection;
    FTestDBPath: string;
    FWaitCursor: TFDGUIxWaitCursor;
    procedure CreateTestDB(const Password: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestCreateEncryptedDB;

    [Test]
    procedure TestOpenWithoutPasswordFails;

    [Test]
    procedure TestOpenWithCorrectPassword;

    [Test]
    procedure TestChangePassword;

    [Test]
    procedure TestEncryptExistingDB;

    [Test]
    procedure TestDataIntegrityAfterEncryption;

    [Test]
    procedure TestPasswordWithAES256Prefix;

    [Test]
    procedure TestMigrationFromUnencrypted;
  end;

implementation

procedure TTestSQLiteEncryption.Setup;
begin
  FTestDBPath := TPath.Combine(TPath.GetTempPath, 'test_enc_' +
    IntToStr(TThread.GetTickCount64) + '.db');

  FConnection := TFDConnection.Create(nil);
  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
end;

procedure TTestSQLiteEncryption.TearDown;
begin
  if Assigned(FConnection) then
  begin
    FConnection.Connected := False;
    FConnection.Free;
  end;

  if Assigned(FWaitCursor) then
    FWaitCursor.Free;

  if TFile.Exists(FTestDBPath) then
    TFile.Delete(FTestDBPath);
end;

procedure TTestSQLiteEncryption.CreateTestDB(const Password: string);
begin
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  if Password <> '' then
    FConnection.Params.Add('Password=' + Password);
  FConnection.Connected := True;

  // Create test table
  FConnection.ExecSQL(
    'CREATE TABLE test_data (id INTEGER PRIMARY KEY, value TEXT)');
  FConnection.ExecSQL('INSERT INTO test_data (value) VALUES (:v)', ['test_value']);
  FConnection.Connected := False;
end;

[Test]
procedure TTestSQLiteEncryption.TestCreateEncryptedDB;
begin
  CreateTestDB('aes-256:test_password');

  // Verify file exists
  Assert.IsTrue(TFile.Exists(FTestDBPath), 'DB file should exist');
  Assert.IsTrue(TFile.GetSize(FTestDBPath) > 0, 'DB file should not be empty');

  // Verify opening without password fails
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  Assert.WillRaise(
    procedure
    begin
      FConnection.Connected := True;
    end,
    nil,
    'Opening without password should fail');
end;

[Test]
procedure TTestSQLiteEncryption.TestOpenWithoutPasswordFails;
begin
  CreateTestDB('aes-256:test_password');

  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;

  Assert.WillRaise(
    procedure
    begin
      FConnection.Connected := True;
    end,
    nil,
    'Should fail without password');
end;

[Test]
procedure TTestSQLiteEncryption.TestOpenWithCorrectPassword;
var
  Count: Integer;
begin
  CreateTestDB('aes-256:test_password');

  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Params.Add('Password=aes-256:test_password');

  Assert.WillNotRaise(
    procedure
    begin
      FConnection.Connected := True;
    end,
    nil,
    'Should open with correct password');

  // Verify data exists
  Count := FConnection.ExecSQLScalar('SELECT COUNT(*) FROM test_data');
  Assert.AreEqual(1, Count, 'test_data should contain 1 row');
end;

[Test]
procedure TTestSQLiteEncryption.TestChangePassword;
begin
  CreateTestDB('aes-256:old_password');

  FConnection.Connected := False;

  // Change password via TFDConnection NewPassword parameter
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Params.Add('Password=aes-256:old_password');
  FConnection.Params.Add('NewPassword=aes-256:new_password');

  Assert.WillNotRaise(
    procedure
    begin
      FConnection.Connected := True; // Re-encrypts with new password
      FConnection.Connected := False;
    end,
    Exception,
    'Should change password without error');

  // Verify old password does not work
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Params.Add('Password=aes-256:old_password');
  Assert.WillRaise(
    procedure
    begin
      FConnection.Connected := True;
    end,
    nil,
    'Old password should not work');

  // Verify new password works
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Params.Add('Password=aes-256:new_password');
  Assert.WillNotRaise(
    procedure
    begin
      FConnection.Connected := True;
    end,
    nil,
    'New password should work');
end;

[Test]
procedure TTestSQLiteEncryption.TestEncryptExistingDB;
const
  TempPath = 'test_unenc.db';
var
  Count: integer;
  TempPathFull: string;
begin
  TempPathFull := TPath.Combine(TPath.GetTempPath, TempPath);

  // Cleanup any leftovers
  if TFile.Exists(TempPathFull) then
    TFile.Delete(TempPathFull);

  // 1. Create unencrypted DB
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := TempPathFull;
  FConnection.Connected := True;
  FConnection.ExecSQL('CREATE TABLE test (id INTEGER)');
  FConnection.ExecSQL('INSERT INTO test VALUES (42)');
  FConnection.Connected := False;

  // 2. Encrypt via NewPassword
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := TempPathFull;
  FConnection.Params.Add('NewPassword=aes-256:new_secret');
  FConnection.Connected := True; // Encryption happens on connect
  FConnection.Connected := False;

  // 3. Verify without password fails
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := TempPathFull;
  Assert.WillRaise(
    procedure
    begin
      FConnection.Connected := True;
    end,
    nil,
    'Should be encrypted now');

  // 4. Verify with password works and data is intact
  FConnection.Params.Add('Password=aes-256:new_secret');
  FConnection.Connected := True;
  Count := FConnection.ExecSQLScalar('SELECT id FROM test');
  Assert.AreEqual(42, Count, 'Data should be preserved after encryption');

  // Cleanup
  FConnection.Connected := False;
  if TFile.Exists(TempPathFull) then
    TFile.Delete(TempPathFull);
end;

[Test]
procedure TTestSQLiteEncryption.TestDataIntegrityAfterEncryption;
const
  TestData = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.';
var
  RetrievedData: string;
  Qry: TFDQuery;
begin
  CreateTestDB('aes-256:integrity_test');

  // Write data
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Params.Add('Password=aes-256:integrity_test');
  FConnection.Connected := True;
  FConnection.ExecSQL('INSERT INTO test_data (value) VALUES (:v)', [TestData]);
  FConnection.Connected := False;

  // Read data
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Params.Add('Password=aes-256:integrity_test');
  FConnection.Connected := True;

  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text := 'SELECT value FROM test_data WHERE id = 2';
    Qry.Open;
    RetrievedData := Qry.FieldByName('value').AsString;
  finally
    Qry.Free;
  end;

  Assert.AreEqual(TestData, RetrievedData,
    'Data should be intact after encryption/decryption');
end;

[Test]
procedure TTestSQLiteEncryption.TestPasswordWithAES256Prefix;
begin
  // Verify that aes-256: prefix works correctly
  CreateTestDB('aes-256:prefixed_password');

  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := FTestDBPath;
  FConnection.Params.Add('Password=aes-256:prefixed_password');
  Assert.WillNotRaise(
    procedure
    begin
      FConnection.Connected := True;
    end,
    nil,
    'aes-256 prefix should work');
end;

[Test]
procedure TTestSQLiteEncryption.TestMigrationFromUnencrypted;
const
  UnencPath = 'unenc_audit.db';
  EncPath = 'enc_audit.db';
var
  Count: integer;
  UnencPathFull, EncPathFull: string;
begin
  UnencPathFull := TPath.Combine(TPath.GetTempPath, UnencPath);
  EncPathFull := TPath.Combine(TPath.GetTempPath, EncPath);

  // Cleanup any leftovers from previous runs
  if TFile.Exists(UnencPathFull) then
    TFile.Delete(UnencPathFull);
  if TFile.Exists(EncPathFull) then
    TFile.Delete(EncPathFull);

  // 1. Create unencrypted DB (like current app)
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := UnencPathFull;
  FConnection.Connected := True;
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS tasks (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    '  title TEXT, ' +
    '  is_synced INTEGER DEFAULT 0' +
    ')');
  FConnection.ExecSQL('INSERT INTO tasks (title) VALUES (:t)', ['Test Task']);
  FConnection.Connected := False;

  // 2. Copy file (for safe migration)
  TFile.Copy(UnencPathFull, EncPathFull, True);

  // 3. Encrypt copy using NewPassword
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := EncPathFull;
  FConnection.Params.Add('NewPassword=aes-256:migration_pwd');
  FConnection.Connected := True; // Encryption happens on connect
  FConnection.Connected := False;

  // 4. Delete original, rename encrypted
  TFile.Delete(UnencPathFull);
  TFile.Move(EncPathFull, UnencPathFull);

  // 5. Verify data is preserved
  FConnection.Params.Clear;
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := UnencPathFull;
  FConnection.Params.Add('Password=aes-256:migration_pwd');
  FConnection.Connected := True;
  Count := FConnection.ExecSQLScalar('SELECT COUNT(*) FROM tasks');
  Assert.AreEqual(1, Count, 'Migration should preserve data');

  // Cleanup
  FConnection.Connected := False;
  if TFile.Exists(UnencPathFull) then
    TFile.Delete(UnencPathFull);
  if TFile.Exists(EncPathFull) then
    TFile.Delete(EncPathFull);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSQLiteEncryption);

end.
