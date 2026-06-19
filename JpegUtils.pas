unit JpegUtils;

interface

uses
  System.SysUtils, System.IOUtils, FMX.Graphics, FMX.Surfaces;

function CompressPhoto(const SourcePath, DestPath: string; MaxWidth: Integer = 1920; Quality: Integer = 85): Boolean;

implementation

function CompressPhoto(const SourcePath, DestPath: string; MaxWidth: Integer; Quality: Integer): Boolean;
var
  Bitmap: TBitmap;
  Surface: TBitmapSurface;
  CodecParams: TBitmapCodecSaveParams;
  Scale: Single;
  NewWidth, NewHeight: Integer;
begin
  Result := False;
  if not TFile.Exists(SourcePath) then Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.LoadFromFile(SourcePath);

    if Bitmap.Width > MaxWidth then
    begin
      Scale := MaxWidth / Bitmap.Width;
      NewWidth := MaxWidth;
      NewHeight := Round(Bitmap.Height * Scale);
      Bitmap.Resize(NewWidth, NewHeight);
    end;

    // Try with quality control via TBitmapSurface + TBitmapCodecManager
    try
      Surface := TBitmapSurface.Create;
      try
        Surface.Assign(Bitmap);
        CodecParams.Quality := Quality;
        Result := TBitmapCodecManager.SaveToFile(DestPath, Surface, @CodecParams);
        // If codec returns False, fallback to simple save
        if not Result then
        begin
          Bitmap.SaveToFile(DestPath);
          Result := True;
        end;
      finally
        Surface.Free;
      end;
    except
      // Fallback: simple save without quality control
      Bitmap.SaveToFile(DestPath);
      Result := True;
    end;
  finally
    Bitmap.Free;
  end;
end;

end.
