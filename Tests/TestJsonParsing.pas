unit TestJsonParsing;

interface

uses
  DUnitX.TestFramework,
  System.JSON,
  System.Generics.Collections,
  System.SysUtils,
  System.DateUtils;

type
  [TestFixture]
  TTestClientJsonParsing = class
  public
    [Test]
    procedure TestParseLoginResponse;
    
    [Test]
    procedure TestParseLoginResponseWithError;
    
    [Test]
    procedure TestParseLoginResponseWithInvalidFormat;
    
    [Test]
    procedure TestBuildSyncPayload;
    
    [Test]
    procedure TestParseSyncResponse;
    
    [Test]
    procedure TestParseSyncResponseWithError;
    
    [Test]
    procedure TestBuildPayloadWithMultipleItems;
    
    [Test]
    procedure TestParseEmptyResultArray;
  end;

implementation

procedure TTestClientJsonParsing.TestParseLoginResponse;
var
  JsonStr: string;
  RootObj: TJSONObject;
  ResultArr: TJSONArray;
  InnerObj: TJSONObject;
  Token, Status: string;
begin
  JsonStr := '{"result":[{"status":"success","token":"{86AB48DA-D896-4480-8BA8-99E620F05C5E}"}]}';
  RootObj := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  
  try
    Assert.IsNotNull(RootObj, 'JSON должен распарситься');
    
    ResultArr := RootObj.GetValue('result') as TJSONArray;
    Assert.IsNotNull(ResultArr, 'result должен быть массивом');
    Assert.AreEqual(1, ResultArr.Count, 'Массив должен содержать 1 элемент');
    
    InnerObj := ResultArr.Items[0] as TJSONObject;
    Status := InnerObj.GetValue('status').Value;
    Token := InnerObj.GetValue('token').Value;
    
    Assert.AreEqual('success', Status, 'Статус должен быть success');
    Assert.AreEqual('{86AB48DA-D896-4480-8BA8-99E620F05C5E}', Token, 'Токен должен совпадать');
  finally
    RootObj.Free;
  end;
end;

procedure TTestClientJsonParsing.TestParseLoginResponseWithError;
var
  JsonStr: string;
  RootObj: TJSONObject;
  ResultArr: TJSONArray;
  InnerObj: TJSONObject;
  Status: string;
begin
  JsonStr := '{"result":[{"status":"error","message":"Invalid credentials"}]}';
  RootObj := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  
  try
    ResultArr := RootObj.GetValue('result') as TJSONArray;
    Assert.IsNotNull(ResultArr, 'result должен быть массивом');
    
    InnerObj := ResultArr.Items[0] as TJSONObject;
    Status := InnerObj.GetValue('status').Value;
    
    Assert.AreEqual('error', Status, 'Статус должен быть error');
    Assert.AreEqual('Invalid credentials', InnerObj.GetValue('message').Value, 
      'Сообщение об ошибке должно совпадать');
  finally
    RootObj.Free;
  end;
end;

procedure TTestClientJsonParsing.TestParseLoginResponseWithInvalidFormat;
var
  JsonStr: string;
  RootObj: TJSONObject;
  ResultArr: TJSONArray;
begin
  // Формат без обёртки result
  JsonStr := '{"status":"success","token":"abc123"}';
  RootObj := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  
  try
    Assert.IsNotNull(RootObj, 'JSON должен распарситься');
    
    ResultArr := RootObj.GetValue('result') as TJSONArray;
    // ResultArr должен быть nil, так как нет поля "result"
    Assert.IsNull(ResultArr, 'result должен быть nil при отсутствии поля');
  finally
    RootObj.Free;
  end;
end;

procedure TTestClientJsonParsing.TestBuildSyncPayload;
var
  JsonArr: TJSONArray;
  JObj, Details: TJSONObject;
  Payload: TJSONObject;
  JsonStr: string;
begin
  JsonArr := TJSONArray.Create;
  
  JObj := TJSONObject.Create;
  JObj.AddPair('event_type', TJSONString.Create('mobile_audit'));
  
  Details := TJSONObject.Create;
  Details.AddPair('lat', TJSONNumber.Create(55.75));
  Details.AddPair('lon', TJSONNumber.Create(37.62));
  JObj.AddPair('details', Details);
  
  JsonArr.Add(JObj);
  
  Payload := TJSONObject.Create;
  Payload.AddPair('AJsonData', JsonArr);
  
  try
    JsonStr := Payload.ToString;
    
    Assert.IsTrue(Pos('"event_type":"mobile_audit"', JsonStr) > 0, 
      'JSON должен содержать event_type');
    Assert.IsTrue(Pos('"lat":55.75', JsonStr) > 0, 
      'JSON должен содержать координаты');
    Assert.IsTrue(Pos('"AJsonData"', JsonStr) > 0, 
      'JSON должен содержать обёртку AJsonData');
  finally
    Payload.Free;
  end;
end;

procedure TTestClientJsonParsing.TestParseSyncResponse;
var
  JsonStr: string;
  RootObj: TJSONObject;
  ResultStr: string;
  Count: Integer;
begin
  JsonStr := '{"result":"ok","count":5}';
  RootObj := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  
  try
    ResultStr := RootObj.GetValue('result').Value;
    Count := (RootObj.GetValue('count') as TJSONNumber).AsInt;
    
    Assert.AreEqual('ok', ResultStr, 'Результат должен быть ok');
    Assert.AreEqual(5, Count, 'Количество должно быть 5');
  finally
    RootObj.Free;
  end;
end;

procedure TTestClientJsonParsing.TestParseSyncResponseWithError;
var
  JsonStr: string;
  RootObj: TJSONObject;
  ResultStr, MessageStr: string;
begin
  JsonStr := '{"result":"error","message":"Database connection failed"}';
  RootObj := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  
  try
    ResultStr := RootObj.GetValue('result').Value;
    MessageStr := RootObj.GetValue('message').Value;
    
    Assert.AreEqual('error', ResultStr, 'Результат должен быть error');
    Assert.AreEqual('Database connection failed', MessageStr, 
      'Сообщение об ошибке должно совпадать');
  finally
    RootObj.Free;
  end;
end;

procedure TTestClientJsonParsing.TestBuildPayloadWithMultipleItems;
var
  JsonArr: TJSONArray;
  JObj1, JObj2, Details1, Details2: TJSONObject;
  Payload: TJSONObject;
begin
  JsonArr := TJSONArray.Create;
  
  // Первый элемент
  JObj1 := TJSONObject.Create;
  JObj1.AddPair('event_type', TJSONString.Create('mobile_audit'));
  Details1 := TJSONObject.Create;
  Details1.AddPair('lat', TJSONNumber.Create(55.75));
  Details1.AddPair('lon', TJSONNumber.Create(37.62));
  JObj1.AddPair('details', Details1);
  JsonArr.Add(JObj1);
  
  // Второй элемент
  JObj2 := TJSONObject.Create;
  JObj2.AddPair('event_type', TJSONString.Create('mobile_audit'));
  Details2 := TJSONObject.Create;
  Details2.AddPair('lat', TJSONNumber.Create(55.76));
  Details2.AddPair('lon', TJSONNumber.Create(37.63));
  JObj2.AddPair('details', Details2);
  JsonArr.Add(JObj2);
  
  Payload := TJSONObject.Create;
  Payload.AddPair('AJsonData', JsonArr);
  
  try
    Assert.AreEqual(2, JsonArr.Count, 'Массив должен содержать 2 элемента');
    Assert.IsTrue(Payload.ToString.Length > 0, 'JSON не должен быть пустым');
  finally
    Payload.Free;
  end;
end;

procedure TTestClientJsonParsing.TestParseEmptyResultArray;
var
  JsonStr: string;
  RootObj: TJSONObject;
  ResultArr: TJSONArray;
begin
  JsonStr := '{"result":[]}';
  RootObj := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  
  try
    ResultArr := RootObj.GetValue('result') as TJSONArray;
    Assert.IsNotNull(ResultArr, 'result должен быть массивом');
    Assert.AreEqual(0, ResultArr.Count, 'Массив должен быть пустым');
  finally
    RootObj.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestClientJsonParsing);

end.
