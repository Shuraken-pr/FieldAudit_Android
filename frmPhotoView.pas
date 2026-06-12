unit frmPhotoView;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.StdCtrls, FMX.Controls.Presentation;

type
  TformPhotoView = class(TForm)
    pnlPhotoViewer: TPanel;
    btnCloseViewer: TButton;
    imgPhoto: TImage;
    procedure btnCloseViewerClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  formPhotoView: TformPhotoView;

implementation

{$R *.fmx}

procedure TformPhotoView.btnCloseViewerClick(Sender: TObject);
begin
  Close;
end;

end.
