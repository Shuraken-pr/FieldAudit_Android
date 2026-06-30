unit DatabaseKeyManager;

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding, System.IOUtils,
  System.StrUtils
  {$IFDEF ANDROID}
  , Androidapi.JNI.JavaTypes, Androidapi.Helpers, Androidapi.JNI.Os,
    Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.Telephony,
    Androidapi.JNI.Provider
  {$ENDIF}
  ;

type
  TDatabaseKeyManager = class
  private
    class var FCurrentPIN: string;
    class function GenerateSalt: string;
    class function SaveSaltToPreferences(const Salt: string): Boolean;
    class function LoadSaltFromPreferences: string;
    class function GetFieldKey: string;
  public
    class function GetAndroidDeviceID: string;
    class function DeriveDatabasePassword(const UserPIN: string): string;
    class function HasStoredSalt: Boolean;
    class function CreateAndStoreSalt: string;
    class procedure ClearSalt;
    class function GetSharedPrefString(const Key, DefaultValue: string): string;
    class procedure SetSharedPrefString(const Key, Value: string);
    class procedure ClearSharedPref(const Key: string);
    class procedure SetCurrentPIN(const PIN: string);
    class function EncryptField(const PlainText: string): string;
    class function DecryptField(const EncryptedText: string): string;
  end;

implementation

class function TDatabaseKeyManager.GenerateSalt: string;
begin
  // Generate 16 random hex chars (64 bits of entropy)
  Result := TGUID.NewGuid.ToString;
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := Copy(Result, 1, 16);
end;

class function TDatabaseKeyManager.SaveSaltToPreferences(const Salt: string): Boolean;
{$IFDEF ANDROID}
var
  JSharedPref: JSharedPreferences;
  JEditor: JSharedPreferences_Editor;
{$ELSE}
var
  FilePath: string;
{$ENDIF}
begin
{$IFDEF ANDROID}
  try
    JSharedPref := TAndroidHelper.Context.getSharedPreferences(
      StringToJString('FieldAuditPrefs'), 0);
    JEditor := JSharedPref.edit;
    JEditor.putString(StringToJString('pin_salt'), StringToJString(Salt));
    JEditor.apply;
    Result := True;
  except
    Result := False;
  end;
{$ELSE}
  FilePath := TPath.Combine(TPath.GetTempPath, 'fieldaudit_salt.txt');
  try
    TFile.WriteAllText(FilePath, Salt, TEncoding.UTF8);
    Result := True;
  except
    Result := False;
  end;
{$ENDIF}
end;

class function TDatabaseKeyManager.LoadSaltFromPreferences: string;
{$IFDEF ANDROID}
var
  JSharedPref: JSharedPreferences;
  JValue: JString;
{$ELSE}
var
  FilePath: string;
{$ENDIF}
begin
{$IFDEF ANDROID}
  try
    JSharedPref := TAndroidHelper.Context.getSharedPreferences(
      StringToJString('FieldAuditPrefs'), 0);
    JValue := JSharedPref.getString(StringToJString('pin_salt'), nil);
    if JValue <> nil then
      Result := JStringToString(JValue)
    else
      Result := '';
  except
    Result := '';
  end;
{$ELSE}
  FilePath := TPath.Combine(TPath.GetTempPath, 'fieldaudit_salt.txt');
  if TFile.Exists(FilePath) then
    Result := TFile.ReadAllText(FilePath, TEncoding.UTF8)
  else
    Result := '';
{$ENDIF}
end;

class function TDatabaseKeyManager.GetAndroidDeviceID: string;
{$IFDEF ANDROID}
var
  Context: JContext;
{$ENDIF}
begin
{$IFDEF ANDROID}
  Result := '';
  try
    Context := TAndroidHelper.Context;
    Result := JStringToString(
      TJSettings_Secure.JavaClass.getString(
        Context.getContentResolver,
        TJSettings_Secure.JavaClass.ANDROID_ID));
  except
    Result := 'unknown_device';
  end;
{$ELSE}
  // Windows: use machine name + user name as pseudo-device ID
  Result := GetEnvironmentVariable('COMPUTERNAME') + '_' + GetEnvironmentVariable('USERNAME');
  if Result = '_' then
    Result := 'windows_test_device';
{$ENDIF}
end;

class function TDatabaseKeyManager.DeriveDatabasePassword(const UserPIN: string): string;
var
  DeviceID, Salt, Combined: string;
  Hash: THashSHA2;
  HashBytes: TBytes;
begin
  DeviceID := GetAndroidDeviceID;
  Salt := LoadSaltFromPreferences;

  if Salt = '' then
  begin
    Salt := CreateAndStoreSalt;
    if Salt = '' then
      raise Exception.Create('Failed to generate and store salt');
  end;

  Combined := UserPIN + DeviceID + Salt;
  Hash := THashSHA2.Create;
  Hash.Update(TEncoding.UTF8.GetBytes(Combined));
  HashBytes := Hash.HashAsBytes;

  Result := 'aes-256:' + TNetEncoding.Base64.EncodeBytesToString(HashBytes);
end;

class function TDatabaseKeyManager.HasStoredSalt: Boolean;
begin
  Result := LoadSaltFromPreferences <> '';
end;

class function TDatabaseKeyManager.CreateAndStoreSalt: string;
begin
  Result := GenerateSalt;
  if not SaveSaltToPreferences(Result) then
    Result := '';
end;

class procedure TDatabaseKeyManager.ClearSalt;
{$IFDEF ANDROID}
var
  JSharedPref: JSharedPreferences;
  JEditor: JSharedPreferences_Editor;
{$ELSE}
var
  FilePath: string;
{$ENDIF}
begin
{$IFDEF ANDROID}
  try
    JSharedPref := TAndroidHelper.Context.getSharedPreferences(
      StringToJString('FieldAuditPrefs'), 0);
    JEditor := JSharedPref.edit;
    JEditor.remove(StringToJString('pin_salt'));
    JEditor.apply;
  except
    // Ignore errors
  end;
{$ELSE}
  FilePath := TPath.Combine(TPath.GetTempPath, 'fieldaudit_salt.txt');
  if TFile.Exists(FilePath) then
    TFile.Delete(FilePath);
{$ENDIF}
end;

{$IFDEF ANDROID}
class function TDatabaseKeyManager.GetSharedPrefString(const Key, DefaultValue: string): string;
var
  JSharedPref: JSharedPreferences;
  JValue: JString;
begin
  try
    JSharedPref := TAndroidHelper.Context.getSharedPreferences(
      StringToJString('FieldAuditPrefs'), 0);
    JValue := JSharedPref.getString(StringToJString(Key), StringToJString(DefaultValue));
    Result := JStringToString(JValue);
  except
    Result := DefaultValue;
  end;
end;

class procedure TDatabaseKeyManager.SetSharedPrefString(const Key, Value: string);
var
  JSharedPref: JSharedPreferences;
  JEditor: JSharedPreferences_Editor;
begin
  try
    JSharedPref := TAndroidHelper.Context.getSharedPreferences(
      StringToJString('FieldAuditPrefs'), 0);
    JEditor := JSharedPref.edit;
    JEditor.putString(StringToJString(Key), StringToJString(Value));
    JEditor.apply;
  except
    // Ignore errors
  end;
end;

class procedure TDatabaseKeyManager.ClearSharedPref(const Key: string);
var
  JSharedPref: JSharedPreferences;
  JEditor: JSharedPreferences_Editor;
begin
  try
    JSharedPref := TAndroidHelper.Context.getSharedPreferences(
      StringToJString('FieldAuditPrefs'), 0);
    JEditor := JSharedPref.edit;
    JEditor.remove(StringToJString(Key));
    JEditor.apply;
  except
    // Ignore errors
  end;
end;
{$ELSE}
class function TDatabaseKeyManager.GetSharedPrefString(const Key, DefaultValue: string): string;
var
  FilePath: string;
  Stream: TFileStream;
  Reader: TStreamReader;
  Line: string;
  Prefix: string;
begin
  Result := DefaultValue;
  FilePath := TPath.Combine(TPath.GetTempPath, 'fieldaudit_prefs.txt');
  if not TFile.Exists(FilePath) then
    Exit;

  try
    Stream := TFileStream.Create(FilePath, fmOpenRead);
    Reader := TStreamReader.Create(Stream);
    try
      Prefix := Key + '=';
      while not Reader.EndOfStream do
      begin
        Line := Reader.ReadLine;
        if Pos(Prefix, Line) = 1 then
        begin
          Result := Copy(Line, Length(Prefix) + 1, MaxInt);
          Exit;
        end;
      end;
    finally
      Reader.Free;
      Stream.Free;
    end;
  except
    Result := DefaultValue;
  end;
end;

class procedure TDatabaseKeyManager.SetSharedPrefString(const Key, Value: string);
var
  FilePath: string;
  Lines: TStringList;
  I: Integer;
  Found: Boolean;
  Prefix: string;
begin
  FilePath := TPath.Combine(TPath.GetTempPath, 'fieldaudit_prefs.txt');
  Lines := TStringList.Create;
  try
    if TFile.Exists(FilePath) then
      Lines.LoadFromFile(FilePath);

    Prefix := Key + '=';
    Found := False;
    for I := 0 to Lines.Count - 1 do
    begin
      if Pos(Prefix, Lines[I]) = 1 then
      begin
        Lines[I] := Prefix + Value;
        Found := True;
        Break;
      end;
    end;

    if not Found then
      Lines.Add(Prefix + Value);

    Lines.SaveToFile(FilePath);
  finally
    Lines.Free;
  end;
end;

class procedure TDatabaseKeyManager.ClearSharedPref(const Key: string);
var
  FilePath: string;
  Lines: TStringList;
  I: Integer;
  Prefix: string;
begin
  FilePath := TPath.Combine(TPath.GetTempPath, 'fieldaudit_prefs.txt');
  if not TFile.Exists(FilePath) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath);
    Prefix := Key + '=';
    for I := Lines.Count - 1 downto 0 do
    begin
      if Pos(Prefix, Lines[I]) = 1 then
        Lines.Delete(I);
    end;
    Lines.SaveToFile(FilePath);
  finally
    Lines.Free;
  end;
end;
{$ENDIF}

class procedure TDatabaseKeyManager.SetCurrentPIN(const PIN: string);
begin
  FCurrentPIN := PIN;
end;

class function TDatabaseKeyManager.GetFieldKey: string;
var
  DeviceID, Salt: string;
  Hash: THashSHA2;
begin
  if FCurrentPIN = '' then
    raise Exception.Create('PIN not set - cannot generate encryption key');

  DeviceID := GetAndroidDeviceID;
  Salt := LoadSaltFromPreferences;
  if Salt = '' then
    raise Exception.Create('Salt not found - cannot generate encryption key');

  Hash := THashSHA2.Create;
  Hash.Update(TEncoding.UTF8.GetBytes(FCurrentPIN + DeviceID + Salt + 'FIELD_ENCRYPT'));
  Result := TNetEncoding.Base64.EncodeBytesToString(Hash.HashAsBytes);
end;

class function TDatabaseKeyManager.EncryptField(const PlainText: string): string;
// Application-level encryption: stream cipher using SHA-256 keystream + XOR
// Not AES-256, but cryptographically reasonable for this project without external libraries
var
  Key: string;
  KeyBytes, PlainBytes, ResultBytes: TBytes;
  I, Counter: Integer;
  Hash: THashSHA2;
  BlockHash: TBytes;
begin
  if PlainText = '' then
    Exit('');

  Key := GetFieldKey;
  KeyBytes := TNetEncoding.Base64.DecodeStringToBytes(Key);

  PlainBytes := TEncoding.UTF8.GetBytes(PlainText);
  SetLength(ResultBytes, Length(PlainBytes));

  Counter := 0;
  for I := 0 to Length(PlainBytes) - 1 do
  begin
    if I mod 32 = 0 then
    begin
      Hash := THashSHA2.Create;
      Hash.Update(KeyBytes);
      Hash.Update(TEncoding.UTF8.GetBytes(IntToStr(Counter)));
      BlockHash := Hash.HashAsBytes;
      Inc(Counter);
    end;
    ResultBytes[I] := PlainBytes[I] xor BlockHash[I mod 32];
  end;

  Result := 'ENC:' + TNetEncoding.Base64.EncodeBytesToString(ResultBytes);
end;

class function TDatabaseKeyManager.DecryptField(const EncryptedText: string): string;
// Decrypts field encrypted by EncryptField. Backward compatible: returns plaintext if no ENC: prefix
var
  Key: string;
  KeyBytes, EncryptedBytes, ResultBytes: TBytes;
  I, Counter: Integer;
  Hash: THashSHA2;
  BlockHash: TBytes;
  ActualEncrypted: string;
begin
  if EncryptedText = '' then
    Exit('');

  // Backward compatible: not encrypted, return as-is
  if Pos('ENC:', EncryptedText) <> 1 then
    Exit(EncryptedText);

  ActualEncrypted := Copy(EncryptedText, 5, MaxInt);

  Key := GetFieldKey;
  KeyBytes := TNetEncoding.Base64.DecodeStringToBytes(Key);

  EncryptedBytes := TNetEncoding.Base64.DecodeStringToBytes(ActualEncrypted);
  SetLength(ResultBytes, Length(EncryptedBytes));

  Counter := 0;
  for I := 0 to Length(EncryptedBytes) - 1 do
  begin
    if I mod 32 = 0 then
    begin
      Hash := THashSHA2.Create;
      Hash.Update(KeyBytes);
      Hash.Update(TEncoding.UTF8.GetBytes(IntToStr(Counter)));
      BlockHash := Hash.HashAsBytes;
      Inc(Counter);
    end;
    ResultBytes[I] := EncryptedBytes[I] xor BlockHash[I mod 32];
  end;

  Result := TEncoding.UTF8.GetString(ResultBytes);
end;

end.
