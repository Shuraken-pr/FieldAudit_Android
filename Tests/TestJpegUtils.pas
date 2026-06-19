unit TestJpegUtils;

interface

uses
  DUnitX.TestFramework, System.SysUtils, System.IOUtils, FMX.Graphics, System.Types;

type
  [TestFixture]
  TTestJpegUtils = class
  private
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestCompressPhoto_InvalidPath;

    [Test]
    procedure TestCompressPhoto_ReducesWidth;

    [Test]
    procedure TestCompressPhoto_CreatesFile;

    [Test]
    procedure TestCompressPhoto_MaintainsAspectRatio;

    [Test]
    procedure TestCompressPhoto_SmallImageUnchanged;
  end;

implementation

uses JpegUtils;

{ TTestJpegUtils }

procedure TTestJpegUtils.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'TestJpegUtils_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TTestJpegUtils.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestJpegUtils.TestCompressPhoto_InvalidPath;
var
  DestPath: string;
  Result: Boolean;
begin
  DestPath := TPath.Combine(FTempDir, 'output.jpg');
  Result := CompressPhoto('nonexistent.jpg', DestPath, 1920, 85);
  Assert.IsFalse(Result, 'Should fail for non-existent source');
  Assert.IsFalse(TFile.Exists(DestPath), 'Should not create output for invalid input');
end;

procedure TTestJpegUtils.TestCompressPhoto_ReducesWidth;
var
  SourcePath, DestPath: string;
  Bitmap: TBitmap;
  DestBitmap: TBitmap;
  Result: Boolean;
const
  SOURCE_WIDTH = 3000;
  MAX_WIDTH = 1920;
begin
  SourcePath := TPath.Combine(FTempDir, 'source.jpg');
  DestPath := TPath.Combine(FTempDir, 'dest.jpg');

  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(SOURCE_WIDTH, 2000);
    Bitmap.SaveToFile(SourcePath);
  finally
    Bitmap.Free;
  end;

  Result := CompressPhoto(SourcePath, DestPath, MAX_WIDTH, 85);
  Assert.IsTrue(Result, 'Compression should succeed');
  Assert.IsTrue(TFile.Exists(DestPath), 'Output file should exist');

  DestBitmap := TBitmap.Create;
  try
    DestBitmap.LoadFromFile(DestPath);
    Assert.IsTrue(DestBitmap.Width <= MAX_WIDTH,
      Format('Width should be <= %d, got %d', [MAX_WIDTH, DestBitmap.Width]));
  finally
    DestBitmap.Free;
  end;
end;

procedure TTestJpegUtils.TestCompressPhoto_CreatesFile;
var
  SourcePath, DestPath: string;
  Bitmap: TBitmap;
  Result: Boolean;
begin
  SourcePath := TPath.Combine(FTempDir, 'source.jpg');
  DestPath := TPath.Combine(FTempDir, 'dest.jpg');

  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(500, 500);
    Bitmap.SaveToFile(SourcePath);
  finally
    Bitmap.Free;
  end;

  Result := CompressPhoto(SourcePath, DestPath, 1920, 85);
  Assert.IsTrue(Result);
  Assert.IsTrue(TFile.Exists(DestPath));
  Assert.IsTrue(TFile.GetSize(DestPath) > 0);
end;

procedure TTestJpegUtils.TestCompressPhoto_MaintainsAspectRatio;
var
  SourcePath, DestPath: string;
  SourceBitmap, DestBitmap: TBitmap;
  SourceRatio, DestRatio: Double;
  Result: Boolean;
const
  TOLERANCE = 0.01;
begin
  SourcePath := TPath.Combine(FTempDir, 'source_wide.jpg');
  DestPath := TPath.Combine(FTempDir, 'dest_wide.jpg');

  SourceBitmap := TBitmap.Create;
  try
    SourceBitmap.SetSize(3000, 1500); // 2:1 ratio
    SourceBitmap.SaveToFile(SourcePath);
    SourceRatio := SourceBitmap.Width / SourceBitmap.Height;
  finally
    SourceBitmap.Free;
  end;

  Result := CompressPhoto(SourcePath, DestPath, 1920, 85);
  Assert.IsTrue(Result);

  DestBitmap := TBitmap.Create;
  try
    DestBitmap.LoadFromFile(DestPath);
    DestRatio := DestBitmap.Width / DestBitmap.Height;
    Assert.AreEqual(SourceRatio, DestRatio, TOLERANCE,
      Format('Aspect ratio should be preserved: source=%f, dest=%f', [SourceRatio, DestRatio]));
  finally
    DestBitmap.Free;
  end;
end;

procedure TTestJpegUtils.TestCompressPhoto_SmallImageUnchanged;
var
  SourcePath, DestPath: string;
  SourceBitmap, DestBitmap: TBitmap;
  Result: Boolean;
const
  SMALL_WIDTH = 500;
begin
  SourcePath := TPath.Combine(FTempDir, 'small.jpg');
  DestPath := TPath.Combine(FTempDir, 'small_out.jpg');

  SourceBitmap := TBitmap.Create;
  try
    SourceBitmap.SetSize(SMALL_WIDTH, 400);
    SourceBitmap.SaveToFile(SourcePath);
  finally
    SourceBitmap.Free;
  end;

  Result := CompressPhoto(SourcePath, DestPath, 1920, 85);
  Assert.IsTrue(Result);

  DestBitmap := TBitmap.Create;
  try
    DestBitmap.LoadFromFile(DestPath);
    Assert.AreEqual(SMALL_WIDTH, DestBitmap.Width,
      'Small image should not be resized when below max width');
  finally
    DestBitmap.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJpegUtils);

end.
