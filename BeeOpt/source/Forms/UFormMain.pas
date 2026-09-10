unit UFormMain;

{$R-,Q-,S-}

interface

uses
  Math,                 // Max (), Min (), ...
  Forms,
  Classes,
  Windows,
  Messages,
  SysUtils,
  ComCtrls,
  StdCtrls,
  Controls,

  Bee_Common,           // SetPriority (), ...
  UTrayIcon,
  UOptimizer;

type
  TMainForm = class (TForm)
    Memo1: TMemo;
  published
    PageControl: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet3: TTabSheet;
    Label_Extension: TLabel;
    Label_ExtensionValue: TLabel;
    Label_variantsEstimated: TLabel;
    Label_variantsEstimatedValue: TLabel;
    Label_PercentOfImprovements: TLabel;
    Label_PercentOfImprovementsValue: TLabel;
    Label_LevelValue: TLabel;
    StatusBar: TStatusBar;
    Label_SampleSize: TLabel;
    Label_SampleSizeValue: TLabel;
    Label_PackedSize: TLabel;
    Label_PackedSizeValue: TLabel;
    Label_DictionaryLevel: TLabel;
    Label_DictionaryLevelValue: TLabel;
    procedure FormCreate (Sender: TObject);
    procedure FormClose (Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy (Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    App: TApp;
    TrayIcon: TTrayIcon;
    NeedToRecalculate,        /// Нужно вычислить оценки особей заново?
    NeedToCollectConfig,      /// Is it need to collect configurations to Bee.ini?
    NeedToReduceIni,          /// Is it need to reduce Bee.ini?
    NeedToMerge,              /// Нужно собрать рекурсивно все ".dat" файлы в один.
    NeedToClose,              /// Нужно прекратить расчет и закончить работу программы?
    NeedToRun: Boolean;       /// Нужно начать расчет?
    NeedToHide: Boolean;      /// Нужно спрятать приложение?
    DeepOptimizationEnabled: Boolean;   // It is need to perform deep optomization?
  public
    procedure ApplicationMinimize (Sender: TObject);
    procedure ApplicationRestore (Sender: TObject);
    procedure TrayIconClick (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure ShowStatusBar (const aText: string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.DFM}

procedure TMainForm.FormCreate (Sender: TObject);
begin
  TrayIcon := TTrayIcon.Create (Self);
  TrayIcon.Icon := Icon;
  TrayIcon.FormVisible := False;
  TrayIcon.AppVisible  := False;
  TrayIcon.IconVisible := False;
  TrayIcon.OnClick := TrayIconClick;

  Application.OnMinimize := ApplicationMinimize;
  Application.OnRestore  := ApplicationRestore;

  NeedToRecalculate := False;
  NeedToCollectConfig := False;
  NeedToReduceIni := False;
  NeedToMerge := False;
  NeedToClose := False;
  NeedToRun := True;
  NeedToHide := False;
  DeepOptimizationEnabled := False;

  App := TApp.Create;
end;

procedure TMainForm.FormClose (Sender: TObject; var Action: TCloseAction);
begin
  SetPriority (1);
  NeedToClose := True;
  ShowStatusBar ('Saving...');
end;

procedure TMainForm.FormDestroy (Sender: TObject);
begin
  TrayIcon.FormVisible := False;
  TrayIcon.AppVisible  := False;
  TrayIcon.IconVisible := False;
  TrayIcon.Free;
  if App <> nil then App.Free;
end;

procedure TMainForm.ApplicationMinimize (Sender: TObject);
begin
  TrayIcon.FormVisible := False;
  TrayIcon.AppVisible  := False;
  TrayIcon.IconVisible := not NeedToHide;
end;

procedure TMainForm.ApplicationRestore (Sender: TObject);
begin
  TrayIcon.IconVisible := False;
  TrayIcon.AppVisible  := True;
  TrayIcon.FormVisible := True;

  Application.Restore;
  SetForegroundWindow (Application.Handle);
end;

procedure TMainForm.TrayIconClick (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  ApplicationRestore (Sender);
end;

procedure TMainForm.ShowStatusBar (const aText: string);
begin
  StatusBar.Panels.Items [0].Text := aText;
end;

end.

