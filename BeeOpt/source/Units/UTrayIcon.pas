unit UTrayIcon;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Classes,
  Controls,
  AppEvnts,
  Forms,
  ShellAPI,
  Graphics,
  Menus;

const
  TI_MESSAGE = WM_USER + 1;

type
  TWhatShow = (ShIcon, ShForm, ShApplication, ShTask); //Task=Form+App

  TTrayIcon = class (TComponent)        //TCustomApplicationEvents)
  private
    FWindow: HWnd;
    FForm: TForm;
    FIconVisible: Boolean;
    FDestroying: Boolean;
    FIconData: TNotifyIconData;
    FNT351: Boolean;
    FTip: string;
    FIcon: TIcon;
    FPopupMenu: TPopupMenu;
    FShowIcon: Boolean;
    FShowTip: Boolean;
    FRespondMouse: Boolean;
    FOnClick: TMouseEvent;
    FOnDblClick: TNotifyEvent;
    FFormVisible: Boolean;
    FAppVisible: Boolean;
    FMinimiseToTray: Boolean;
    procedure IconChanged (Sender: TObject);
    procedure SendCancelMode;
    procedure SetTip (const Value: string);
    procedure SetIcon (const Value: TIcon);
    procedure SetFlags (const Index: Integer; const Value: Boolean);
    procedure SendTrayMessage (Msg: DWORD);
    procedure SetPopupMenu (const Value: TPopupMenu); //Процедура установки/удаления/модификации иконки
    function CheckMenuPopup (X, Y: Integer): Boolean;
    function CheckDefaultMenuItem: Boolean;
    procedure SetMinimiseToTray (const Value: Boolean);
  protected
    procedure WndProc (var Message: TMessage);
    procedure Loaded; override;
    procedure Notification (AComponent: TComponent; Operation: TOperation); override;
    procedure DoClick (Button: TMouseButton); virtual;
    procedure DoDblClick; virtual;
  public
    constructor Create (AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowX (const Index: TWhatShow; const Value: Boolean);
  published
    property Tip: string read FTip write SetTip;
    property Icon: TIcon read FIcon write SetIcon;
    property NIF_MESSAGE: Boolean index 0 read FRespondMouse write SetFlags default True;
    property NIF_ICON: Boolean index 1 read FShowIcon write SetFlags default True;
    property NIF_TIP: Boolean index 2 read FShowTip write SetFlags default True;
    property PopupMenu: TPopupMenu read FPopupMenu write SetPopupMenu;
    property OnClick: TMouseEvent read FOnClick write FOnClick;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
    property PForm: TForm read FForm;
    property IconVisible: Boolean index ShIcon read FIconVisible write ShowX;
    property FormVisible: Boolean index ShForm read FFormVisible write ShowX;
    property AppVisible: Boolean index ShApplication read FAppVisible write ShowX;
    property MinimiseToTray: Boolean read FMinimiseToTray write SetMinimiseToTray;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents ('Samples', [TTrayIcon]);
end;

{ TTrayIcon }

function TTrayIcon.CheckDefaultMenuItem: Boolean;
var
  i: Integer;
begin
  Result := False;
  if not (csDesigning in ComponentState) and IconVisible and
    (PopupMenu <> nil) and (PopupMenu.Items <> nil) then
    for i := 0 to PopupMenu.Items.Count - 1 do
      if PopupMenu.Items [I].Default then
      begin
        PopupMenu.Items [I].Click;
        Result := True;
        Break;
      end;
end;

function TTrayIcon.CheckMenuPopup (X, Y: Integer): Boolean;
begin
  Result := False;
  if not (csDesigning in ComponentState) and IconVisible and
    (PopupMenu <> nil) and PopupMenu.AutoPopup then
  begin
    PopupMenu.PopupComponent := Self;
    SendCancelMode;
    SetForegroundWindow (FWindow);
    try
      PopupMenu.Popup (X, Y);
    finally
      SetForegroundWindow (FWindow);
    end;
    Result := True;
  end;
end;

constructor TTrayIcon.Create (AOwner: TComponent);
//Рекурсивная ф-ия поиска формы, на которой лежит компонент.

  function FindForm (Component: TComponent): TForm;
  var
    OwnerCmpt: TComponent;
  begin
    OwnerCmpt := Component.Owner;
    if (OwnerCmpt <> nil) then
    begin
      if OwnerCmpt.ClassParent = TForm then
      begin
        (OwnerCmpt as TForm).HandleNeeded;
        Result := OwnerCmpt as TForm;
      end
      else
        Result := FindForm (OwnerCmpt);
    end
    else
      Result := nil;
  end;

begin
  inherited;
  FNT351 := (Win32MajorVersion <= 3) and (Win32Platform = VER_PLATFORM_WIN32_NT);
  FIcon := TIcon.Create;
  FIcon.OnChange := IconChanged;
  FWindow := {Classes.}AllocateHWnd (WndProc);
  FForm := FindForm (Self);
  NIF_MESSAGE := True;
  NIF_ICON := True;
  NIF_TIP := True;
  with FIconData do
  begin
    cbSize := System.SizeOf(FIconData);
    Wnd := FWindow;
    uID := UINT (Self);
    uCallbackMessage := TI_MESSAGE;
  end;
end;

destructor TTrayIcon.Destroy;
begin
  FDestroying := True;
  if IconVisible then
    SendTrayMessage (NIM_DELETE);
  FIcon.Free;
  {Classes.}DeallocateHWnd (FWindow);
  inherited;
end;

procedure TTrayIcon.DoClick (Button: TMouseButton);
var
  MousePos: TPoint;
begin
  GetCursorPos (MousePos);
  if (Button = mbRight) and CheckMenuPopup (MousePos.X, MousePos.Y) then
    Exit;
  if Assigned (FOnClick) then
    FOnClick (Self, Button, [], MousePos.X, MousePos.Y);
end;

procedure TTrayIcon.DoDblClick;
begin
  if (not CheckDefaultMenuItem) and Assigned (FOnDblClick) then
    FOnDblClick (Self);
end;

procedure TTrayIcon.IconChanged (Sender: TObject);
begin
  FIconData.hIcon := FIcon.Handle;
  if IconVisible then
    SendTrayMessage (NIM_MODIFY);
end;

procedure TTrayIcon.Loaded;
begin
  inherited Loaded;
  if FIcon.Empty then                   //Если иконка не задана - берем иконку приложения
    FIcon.Assign (Application.Icon);
  FIconData.hIcon := FIcon.Handle;
  if IconVisible then
    SendTrayMessage (NIM_MODIFY);
  if not (csDesigning in ComponentState) and (FForm <> nil) then
  begin
    ShowWindow (Application.Handle, SW_SHOW * Integer (FAppVisible));
    ShowWindow (FForm.Handle, SW_SHOW * Integer (FFormVisible));
    Application.ShowMainForm := FFormVisible;
    FForm.Visible := FFormVisible;
  end;
end;

procedure TTrayIcon.Notification (AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification (AComponent, Operation);
  if (Operation = opRemove) and (AComponent = PopupMenu) then
    PopupMenu := nil;
end;

procedure TTrayIcon.SendCancelMode;
var
  F: TForm;
begin
  if not ((csDestroying in ComponentState) or FDestroying) then
  begin
    F := Screen.ActiveForm;
    if F = nil then
      F := Application.MainForm;
    if F <> nil then
      F.SendCancelMode (nil);
  end;
end;

procedure TTrayIcon.SendTrayMessage (Msg: DWORD);
begin
  if not FNT351 and not (csDesigning in ComponentState) then
    Shell_NotifyIcon (Msg, @FIconData);
end;

procedure TTrayIcon.SetFlags (const Index: Integer; const Value: Boolean);
begin
  case Index of
    0: FRespondMouse := Value;
    1: FShowIcon := Value;
    2: FShowTip := Value;
  end;
  FIconData.uFlags := Ord (FRespondMouse) or (Ord (FShowIcon) * 2) or (Ord (FShowTip) * 4);
  if IconVisible then
  begin                                 //NIM_MODIFY НЕ меняет флаги!!! (uFlags), т.е. нельзя убрать иконку или хинт если они уже есть!
    SendTrayMessage (NIM_DELETE);
    SendTrayMessage (NIM_ADD);
  end
end;

procedure TTrayIcon.SetIcon (const Value: TIcon);
begin
  FIcon.Assign (Value);
end;

procedure TTrayIcon.SetMinimiseToTray (const Value: Boolean);
begin
  FMinimiseToTray := Value;
end;

procedure TTrayIcon.SetPopupMenu (const Value: TPopupMenu);
begin
  FPopupMenu := Value;
  if Value <> nil then
    Value.FreeNotification (Self);
end;

procedure TTrayIcon.SetTip (const Value: string);
begin
  FTip := Value;
  StrPLCopy (FIconData.szTip, GetShortHint (Value), SizeOf (FIconData.szTip) - 1);
  if IconVisible then
    SendTrayMessage (NIM_MODIFY);
end;

procedure TTrayIcon.ShowX (const Index: TWhatShow; const Value: Boolean);
begin
  case Index of
    ShIcon:
      begin
        SendTrayMessage (NIM_DELETE * Integer (not Value));
        FIconVisible := Value;
      end;
    ShForm: 
      FFormVisible := Value;
    ShApplication: 
      FAppVisible := Value;
  end;
  if not (csDesigning in ComponentState) and (FForm <> nil) then
  begin
    ShowWindow (FForm.Handle, SW_SHOW * Integer (FFormVisible));
    FForm.Visible := FFormVisible;
    ShowWindow (Application.Handle, SW_SHOW * Integer (FAppVisible));
    Application.ShowMainForm := False;
  end;
end;

procedure TTrayIcon.WndProc (var Message: TMessage);
begin
  try
    with Message do
      if Msg = TI_MESSAGE then
        case Message.lParam of
          WM_LBUTTONDBLCLK: DoDblClick;
          WM_LBUTTONUP: DoClick (mbLeft);
          WM_RBUTTONUP: DoClick (mbRight);
        end
      else
        Result := DefWindowProc (FWindow, Msg, wParam, lParam);
  except
    Application.HandleException (Self);
  end;
end;

end.
