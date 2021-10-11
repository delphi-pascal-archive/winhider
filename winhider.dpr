program winhider;

uses
  windows,messages;

{$R winhider.res}

type
  PNotifyIconDataA = ^TNotifyIconDataA;
  PNotifyIconDataW = ^TNotifyIconDataW;
  PNotifyIconData = PNotifyIconDataA;

  _NOTIFYICONDATAA = record
    cbSize: DWORD;
    Wnd: HWND;
    uID: UINT;
    uFlags: UINT;
    uCallbackMessage: UINT;
    hIcon: HICON;
    szTip: array [0..63] of AnsiChar;
  end;

  _NOTIFYICONDATAW = record
    cbSize: DWORD;
    Wnd: HWND;
    uID: UINT;
    uFlags: UINT;
    uCallbackMessage: UINT;
    hIcon: HICON;
    szTip: array [0..63] of WideChar;
  end;

  _NOTIFYICONDATA = _NOTIFYICONDATAA;
  TNotifyIconDataA = _NOTIFYICONDATAA;
  TNotifyIconDataW = _NOTIFYICONDATAW;
  TNotifyIconData = TNotifyIconDataA;
  NOTIFYICONDATAA = _NOTIFYICONDATAA;
  NOTIFYICONDATAW = _NOTIFYICONDATAW;
  NOTIFYICONDATA = NOTIFYICONDATAA;

const
  NIF_MESSAGE     = $00000001;
  NIF_ICON        = $00000002;
  NIF_TIP         = $00000004;
  NIM_ADD         = $00000000;
  NIM_MODIFY      = $00000001;
  NIM_DELETE      = $00000002;

  WM_NULL             = $0000;
  WM_KEYDOWN          = $0100;
  WM_LBUTTONDOWN      = $0201;
  WM_SIZE             = $0005;
  WM_DESTROY          = $0002;
  WM_USER             = $0400;
  WM_COMMAND          = $0111;
  WM_GETICON          = $007F;
  WM_HOTKEY           = $0312;
  WM_KEYUP            = $0101;

var
  WinClass : TWndClass;
  hInst : HWND;
  Handle: HWND;
  hMsgLabelPass,hMsgLabelConf,hMsgEditPass,hMsgEditConf,hMsgBtn,hMsgYes,hMsgNo : HWND;
  hPopup,hPopup_vis,hPopup_invis,hPopup_all_invis: HWND;
  cur_pos:TPoint;
  Msg : TMSG;
  NID:TNotifyIconData;
  pr_Pass,pr_Conf,pr_BtnClick,pr_YesClick,pr_NoClick:Pointer;
  scr_height,scr_widht:integer;
  error_click:Boolean;
  check_pass:Boolean=false;
  focused_wind:HWND;
  arrHiding:Array [0..50,0..2] of ShortString;
  count_hiding:integer=0;
  cur_hnd:HWND;
  protect_win:Boolean;
  IconInfo:_ICONINFO;
  Icon_Handle:HICON;
  vis_pos,invis_pos,all_in_vis_pos:cardinal;
  hbmp:HBITMAP;
  icon_in_tray:Boolean;
  DialogNum:Integer;
  DialogHND:HWND=0;
  pass_str,conf_str:ShortString;
  cur_btm:HBITMAP;
////////////// external funcs and procs

function Shell_NotifyIcon(dwMessage: DWORD; lpData: PNotifyIconData): BOOL; stdcall; external 'shell32.dll' name 'Shell_NotifyIconA';

function StrPas(const Str: PChar): string;
begin
  Result := Str;
end;

procedure CvtInt;
asm
        OR      CL,CL
        JNZ     @CvtLoop
@C1:    OR      EAX,EAX
        JNS     @C2
        NEG     EAX
        CALL    @C2
        MOV     AL,'-'
        INC     ECX
        DEC     ESI
        MOV     [ESI],AL
        RET
@C2:    MOV     ECX,10

@CvtLoop:
        PUSH    EDX
        PUSH    ESI
@D1:    XOR     EDX,EDX
        DIV     ECX
        DEC     ESI
        ADD     DL,'0'
        CMP     DL,'0'+10
        JB      @D2
        ADD     DL,('A'-'0')-10
@D2:    MOV     [ESI],DL
        OR      EAX,EAX
        JNE     @D1
        POP     ECX
        POP     EDX
        SUB     ECX,ESI
        SUB     EDX,ECX
        JBE     @D5
        ADD     ECX,EDX
        MOV     AL,'0'
        SUB     ESI,EDX
        JMP     @z
@zloop: MOV     [ESI+EDX],AL
@z:     DEC     EDX
        JNZ     @zloop
        MOV     [ESI],AL
@D5:
end;

function IntToStr(Value: Integer): string;
asm
        PUSH    ESI
        MOV     ESI, ESP
        SUB     ESP, 16
        XOR     ECX, ECX
        PUSH    EDX
        XOR     EDX, EDX
        CALL    CvtInt
        MOV     EDX, ESI
        POP     EAX
        CALL    System.@LStrFromPCharLen
        ADD     ESP, 16
        POP     ESI
end;

/////////////// window procs

procedure Resize;
var Rect:TRect;
begin
  GetWindowRect(Handle,Rect);
end;

procedure ShutDown;
var
i:smallint;
wnd:Cardinal;
begin

for i:=0 to GetMenuItemCount(hPopup_invis)-1 do
begin
wnd:=GetMenuItemID(hPopup_invis,i);
ShowWindow(wnd,SW_NORMAL);
end;

  UnRegisterHotKey(Handle,0);
  UnRegisterHotKey(Handle,1);
  UnRegisterHotKey(Handle,2);
  UnRegisterHotKey(Handle,3);

  Shell_NotifyIcon(NIM_DELETE,@NID);
  UnRegisterClass('Sample Class', hInst);
  ExitProcess(hInst);
end;

/// img procs

function HSGetWindowIcon (WindowHandle: HWND): THandle;
begin
 if SendMessageTimeOut(WindowHandle, WM_GETICON, ICON_SMALL, 0,
 SMTO_NORMAL, 300, Result) = 0 then
 Result := 0;
 if Result = 0 then
 Result := GetClassLong(WindowHandle, GCL_HICONSM);
end;



function GetBitmap(Wnd:HWND):HBITMAP;
var
hbmpOld,hbmpNew,hbmMask,hbmToConvert:HBITMAP;
hdcDest,dc,hdcMem,hdcMask :HDC;
bm: BITMAP;
ptSize,ptOrg: TPoint;
begin

    Icon_Handle:=HSGetWindowIcon(Wnd);
    if Icon_Handle>0 then
    begin
    GetIconInfo(Icon_Handle, IconInfo);
    Result:=IconInfo.hbmColor;
    end
    else
    Result:=LoadBitmap(hInst,'NA');
end;


///////////////// popup procs

procedure Popup_Main;
begin
if DialogHND>0 then EndDialog(DialogHND,DialogNum);
SetForegroundWindow(Handle);
GetCursorPos(cur_pos);
TrackPopupMenu(hPopup,0,cur_pos.X,cur_pos.y,5,Handle,nil);
PostMessage(Handle,WM_NULL,0,0);
end;

procedure ClearInvisibleList;
begin
while DeleteMenu(hPopup_invis,0,MF_BYPOSITION) do;
end;

function AddToVisiblePopup(wTitle:string;Wnd:THandle):boolean;
begin
    AppendMenu(hPopup_vis,MF_BYPOSITION,Wnd,pchar(wTitle));
    hbmp:=GetBitmap(Wnd);
    SetMenuItemBitmaps(hPopup_vis,vis_pos,MF_BYPOSITION,hbmp,hbmp);
    inc(vis_pos);
end;

function AddToInVisiblePopup(wTitle:string;Wnd:THandle):boolean;
begin
    AppendMenu(hPopup_invis,MF_BYPOSITION,Wnd,pchar(wTitle));
    hbmp:=GetBitmap(Wnd);
    SetMenuItemBitmaps(hPopup_invis,invis_pos,MF_BYPOSITION,hbmp,hbmp);
    inc(invis_pos);
end;

function AddToAllInVisiblePopup(wTitle:string;Wnd:THandle):boolean;
begin
    AppendMenu(hPopup_all_invis,MF_BYPOSITION,Wnd,pchar(wTitle));
    hbmp:=GetBitmap(Wnd);
    SetMenuItemBitmaps(hPopup_all_invis,all_in_vis_pos,MF_BYPOSITION,hbmp,hbmp);
    inc(all_in_vis_pos);
end;

/// hotkey procs

procedure HotKey_ChangeTrayIcon;
begin
if icon_in_tray then
begin
  Shell_NotifyIcon(NIM_DELETE,@NID);
  icon_in_tray:=false;
end
else
begin
  Shell_NotifyIcon(NIM_ADD,@NID);
  icon_in_tray:=true;
end;
end;

procedure HotKey_HideForegroundWindow;
var
hnd:HWND;
buff: ARRAY [0..78] OF Char;

begin
hnd:=GetForegroundWindow;
ShowWindow(hnd,0);

GetWindowText(hnd, buff, sizeof(buff));

if length(buff)>75 then
begin
buff[76]:=#46;
buff[77]:=#46;
end;
AddToInVisiblePopup(StrPas(buff),hnd);
DeleteMenu(hPopup_vis,hnd,MF_STRING);
end;

/// get visible or invisible windows

procedure getVisibleW;
VAR
Wnd : hWnd;
buff: ARRAY [0..78] OF Char;
begin
vis_pos:=0;

while DeleteMenu(hPopup_vis,0,MF_BYPOSITION) do;

Wnd := GetWindow(Handle, gw_HWndFirst);
WHILE Wnd <> 0 DO
BEGIN
   IF (Wnd <> Handle) AND
   IsWindowVisible(Wnd) AND
   (GetWindow(Wnd, gw_Owner) = 0) AND
   (GetWindowText(Wnd, buff, sizeof(buff)) <> 0)
   THEN
   BEGIN
      GetWindowText(Wnd, buff, sizeof(buff));
      if length(buff)>75 then
      begin
      buff[76]:=#46;
      buff[77]:=#46;
      end;
      AddToVisiblePopup(StrPas(buff),Wnd);
   END;
   Wnd := GetWindow(Wnd, gw_hWndNext);
END;
end;

procedure getAllInVisibleW;
VAR
Wnd : hWnd;
buff: ARRAY [0..78] OF Char;
begin
all_in_vis_pos:=0;
while DeleteMenu(hPopup_all_invis,0,MF_BYPOSITION) do;

Wnd := GetWindow(Handle, gw_HWndFirst);
WHILE Wnd <> 0 DO
BEGIN
   IF (Wnd <> Handle) AND
   (GetWindow(Wnd, gw_Owner) = 0) AND
   (GetWindowText(Wnd, buff, sizeof(buff)) <> 0)
   THEN
   BEGIN
      GetWindowText(Wnd, buff, sizeof(buff));
      if length(buff)>75 then
      begin
      buff[76]:=#46;
      buff[77]:=#46;
      end;
      AddToAllInVisiblePopup(StrPas(buff),Wnd);
   END;
   Wnd := GetWindow(Wnd, gw_hWndNext);
END;
end;

////////// show window mode func

procedure ShowErrorWin(err_msg:PCHAR);
begin
SetWindowText(hMsgLabelPass,err_msg);
ShowWindow(hMsgLabelConf,0);
ShowWindow(hMsgEditPass,0);
ShowWindow(hMsgEditConf,0);
error_click:=true;
end;

procedure ShowPasswordWin;
begin
ShowWindow(hMsgLabelPass,SW_NORMAL);
ShowWindow(hMsgLabelConf,SW_NORMAL);
ShowWindow(hMsgEditPass,SW_NORMAL);
ShowWindow(hMsgEditConf,SW_NORMAL);
ShowWindow(hMsgBtn,SW_NORMAL);
SetWindowText(hMsgLabelPass, 'Enter password for protection this window ...',);
SetWindowText(hMsgLabelConf, 'Confirm password for protection this window ',);
SetFocus(hMsgEditPass);
error_click:=false;
end;

/// check func

function CheckEmptyValue(edit_handle:HWND):Boolean;
  var CheckText:PCHAR;
  LText:integer;
begin
  LText:=GetWindowTextLength(edit_handle)+1;
  GetMem(CheckText,LText);
  GetWindowText(edit_handle,CheckText,LText);
  if LText=1 then
  Result:=false
  else Result:=true;
end;

function ComparePassAndConf:Boolean;
  var PassText,ConfText:PCHAR;
  LTextPass,LTextConf:integer;
begin
  LTextPass:=GetWindowTextLength(hMsgEditPass)+1;
  GetMem(PassText,LTextPass);
  GetWindowText(hMsgEditPass,PassText,LTextPass);
  LTextConf:=GetWindowTextLength(hMsgEditConf)+1;
  GetMem(ConfText,LTextConf);
  GetWindowText(hMsgEditConf,ConfText,LTextConf);

  if strpas(ConfText)<>strpas(PassText) then
  Result:=false
  else
  begin
  arrHiding[count_hiding,0]:=inttostr(cur_hnd);
  arrHiding[count_hiding,1]:='1';
  arrHiding[count_hiding,2]:=PassText;
  inc(count_hiding);
  Result:=true;
  end;
end;

/// edits func

function PassProc(hwnd,msg,wparam,lParam:longint):longint;stdcall;
var
    LTextPass:Smallint;
    PassText:array of PCHAR;
    i:byte;
    tmp_chars:Pchar;
begin
  Result:=CallWindowProc(pr_Pass,hWnd,Msg,wParam,lParam);
  case Msg of
    WM_KEYDOWN :
    case wparam of
      9:
        begin
            if IsWindowVisible(hMsgEditConf) then
            begin
              if  (GetKeyState (VK_SHIFT) and $8000) <> 0   then
              SetFocus(hMsgBtn) else SetFocus(hMsgEditConf);
            end
            else SetFocus(hMsgBtn);
        end;
      13:
      begin
          if not CheckEmptyValue(hMsgEditPass) then
          begin
            if IsWindowVisible(hMsgEditConf) then
             begin
             focused_wind:=hMsgEditPass;
             ShowErrorWin('password can`t to be empty');
             SetFocus(hMsgBtn);
             end
             else ShowWindow(Handle,0);
        end
        else
            if IsWindowVisible(hMsgEditConf) then
            SetFocus(hMsgEditConf)
            else SetFocus(hMsgBtn);
      end;
    end;
  end;
end;

function ConfProc(hwnd,msg,wparam,lParam:longint):longint;stdcall;
begin
  Result:=CallWindowProc(pr_Conf,hWnd,Msg,wParam,lParam);
  case Msg of
    WM_KEYDOWN :
    case wparam of
      9:
        begin
          if  (GetKeyState (VK_SHIFT) and $8000) <> 0   then
          SetFocus(hMsgEditPass) else SetFocus(hMsgBtn);
        end;
      13:
          begin
          if not CheckEmptyValue(hMsgEditConf) then
          begin
          SetFocus(hMsgBtn);
          focused_wind:=hMsgEditConf;
          ShowErrorWin('confirmation can`t to be empty');
          end
          else SetFocus(hMsgBtn);
          end;
    end;
  end;
end;

/// buttoms procs

procedure BtnPress;
var
i:smallint;
PassText:PCHAR;
LTextPass:integer;
begin

if check_pass then
begin

    LTextPass:=GetWindowTextLength(hMsgEditPass)+1;
    GetMem(PassText,LTextPass);
    GetWindowText(hMsgEditPass,PassText,LTextPass);

  for i:=0 to count_hiding do
  begin

    if arrHiding[i,0]=inttostr(cur_hnd) then
    begin
      if arrHiding[i,2]=strpas(PassText) then
      begin
      check_pass:=false;
      arrHiding[i,0]:='';
      arrHiding[i,1]:='';
      arrHiding[i,2]:='';
      dec(count_hiding);
      ShowWindow(cur_hnd,SW_NORMAL);
      SetWindowText(hMsgEditPass,'');
      SetWindowText(hMsgEditConf,'');
      DeleteMenu(hPopup_invis,cur_hnd,MF_STRING);
      ShowWindow(Handle,0);
      protect_win:=False;
      end
      else
      begin
      ShowWindow(Handle,0);
      check_pass:=false;
      protect_win:=False;
      end;
    end
    else continue;
  end;
end
else
begin
  if not error_click then
  begin
    if CheckEmptyValue(hMsgEditPass) then
    begin
    if CheckEmptyValue(hMsgEditConf) then
    begin
    if not ComparePassAndConf then
    begin
      ShowErrorWin('Password and confirmation are difference...');
      focused_wind:=hMsgEditConf;
    end
    else
    begin
      ShowWindow(Handle,0);
      ShowWindow(cur_hnd,0);
      SetWindowText(hMsgEditPass,'');
      SetWindowText(hMsgEditConf,'');
      end;
      end
      else
        begin
        focused_wind:=hMsgEditConf;
        ShowErrorWin('Confirmation is empty');
        end;
    end
    else
      begin
      focused_wind:=hMsgEditPass;
      ShowErrorWin('Password is empty');
      end;
    end
    else
    begin
    ShowPasswordWin;
    SetFocus(focused_wind);
  end;
end;
end;

procedure YesPress;
begin

ShowWindow(hMsgNo,0);
ShowWindow(hMsgYes,0);

ShowPasswordWin;
end;

procedure NoPress;
begin
ShowWindow(Handle,0);
ShowWindow(cur_hnd,0);
end;

/// buttoms funcs

function BtnProc(hwnd,msg,wparam,lParam:longint):longint;stdcall;
begin
  Result:=CallWindowProc(pr_BtnClick,hWnd,Msg,wParam,lParam);
  case Msg of
    WM_KEYDOWN:
    case wparam of
      9:
        begin
            if IsWindowVisible(hMsgEditConf) then
            begin
              if  (GetKeyState (VK_SHIFT) and $8000) <> 0   then
              SetFocus(hMsgBtn) else SetFocus(hMsgEditConf);
            end
            else SetFocus(hMsgEditPass);
        end;
      13,32: BtnPress;
    end;
    WM_LBUTTONDOWN: BtnPress;
  end;
end;

function YesProc(hwnd,msg,wparam,lParam:longint):longint;stdcall;
begin
  Result:=CallWindowProc(pr_YesClick,hWnd,Msg,wParam,lParam);
  case Msg of
    WM_KEYDOWN:
    case wparam of
      9: SetFocus(hMsgNo);
      13,32: YesPress;
    end;
    WM_LBUTTONDOWN: YesPress;
  end;
end;

function NoProc(hwnd,msg,wparam,lParam:longint):longint;stdcall;
begin
  Result:=CallWindowProc(pr_NoClick,hWnd,Msg,wParam,lParam);
  case Msg of
    WM_KEYDOWN:
    case wparam of
      9: SetFocus(hMsgYes);
      13,32: NoPress;
    end;
    WM_LBUTTONDOWN: NoPress;
  end;
end;

/// request func

function ShowPassProtectionRequest(wHnd:cardinal):Boolean;
begin
ShowWindow(hMsgLabelConf,0);
ShowWindow(hMsgEditPass,0);
ShowWindow(hMsgEditConf,0);
ShowWindow(hMsgBtn,0);
ShowWindow(hMsgYes,SW_SHOWNORMAL);
ShowWindow(hMsgNo,SW_SHOWNORMAL);
SetFocus(hMsgNo);
SetWindowText(hMsgLabelPass, 'Are you want to protection this window?',);
ShowWindow(Handle,SW_SHOWNORMAL);
end;

function RequestShowProtectionWin(hnd:Cardinal):Boolean;
var
i:Smallint;
begin
  for i:=0 to count_hiding do
  begin
    if arrHiding[i,0]=inttostr(hnd) then
    begin
       if arrHiding[i,1]='1' then
       begin

          SetWindowText(hMsgLabelPass,'Enter the password for showing hiding window');
          SetWindowText(hMsgEditPass,'');
          ShowWindow(hMsgLabelConf,0);
          ShowWindow(hMsgEditConf,0);
          ShowWindow(Handle,SW_NORMAL);
          SetFocus(hMsgEditPass);
          check_pass:=True;
          protect_win:=True;
          break;

       end
       else ShowWindow(hnd,SW_NORMAL);
    end;
  end;
if not protect_win then ShowWindow(hnd,SW_NORMAL);
end;

/// dialog func

function DialogProc(hWnd: THandle; Msg: Integer; wParam, lParam : Integer): Bool; stdcall;
begin
DialogHND:=hWnd;
case Msg of
WM_COMMAND: EndDialog(hWnd,DialogNum);
end;
end;

///default funct for main window

function WindowProc(hwnd, msg, wparam, lparam:longint):longint;stdcall;
VAR
buff: ARRAY [0..78] OF Char;
begin
  Result:=DefWindowProc(hwnd,msg,wparam,lparam);
  case Msg of
    WM_SIZE : Resize;
    WM_DESTROY : ShutDown;
    /// right_click on tray_icon
    WM_USER:
    if lparam=$0204 then
    begin
      getVisibleW;
      getAllInVisibleW;
      Popup_Main;
    end;
    WM_COMMAND:
      begin
         case lparam of
           0: // click on item popup menu
              begin
                  case wparam of
                    10: ClearInvisibleList;
                    11: HotKey_ChangeTrayIcon;
                    12: DialogNum:=DialogBoxParam(hInst,'DDABOUT',Handle,@DialogProc,11);
                    13: DialogNum:=DialogBoxParam(hInst,'DDHELP',Handle,@DialogProc,12);
                    14: ShutDown;
                    15: DialogNum:=DialogBoxParam(hInst,'DDHISTORY',Handle,@DialogProc,15);
                  else // if click on window item
                     begin
                       GetWindowText(wparam, buff, sizeof(buff));
                       if length(buff)>75 then
                       begin
                       buff[76]:=#46;
                       buff[77]:=#46;
                       end;
                       cur_hnd:=wparam;

                       if IsWindowVisible(wparam) then
                        begin
                        ShowPassProtectionRequest(wparam);
                        AddToInVisiblePopup(StrPas(buff),wparam);
                        DeleteMenu(hPopup_vis,wparam,MF_STRING);
                        end
                        else
                        begin
                        RequestShowProtectionWin(wparam);
                        if not protect_win then
                          begin
                          ShowWindow(wparam,SW_NORMAL);
                          DeleteMenu(hPopup_invis,wparam,MF_STRING);
                          end;
                        end;
                        getVisibleW;
                        getAllInVisibleW;
                     end; ///else
                  end; // case wparam
              end; /// if lparam=0
         end; // case lparam
      end; // if WM_COMMAND
      WM_HOTKEY:
      begin
        case wparam of
        0: HotKey_HideForegroundWindow;
        1: HotKey_ChangeTrayIcon;
        2: ShutDown;
        3:
          begin
          getVisibleW;
          getAllInVisibleW;
          Popup_Main;
          end;
        end;// case wparam WM_HOTKEY
      end; // if WM_HOTKEY
  end; // case msg
end;

////// start of programm
begin

scr_height:=GetSystemMetrics(SM_CXVIRTUALSCREEN);
scr_widht:=GetSystemMetrics(SM_CYVIRTUALSCREEN);
error_click:=false;

hInst:=GetModuleHandle(nil);

///create class

  with WinClass do
  begin
    Style:= CS_PARENTDC;
    hIcon:= LoadIcon(hInst,'WINHIDER');
    lpfnWndProc:= @WindowProc;
    hInstance:= hInst;
    hbrBackground:= COLOR_BTNFACE+1;
    lpszClassName:= 'Sample Class';
    hCursor:= LoadCursor(0,IDC_ARROW);
    end;
  RegisterClass(WinClass);

//// create main window

  Handle:=CreateWindow(
    'Sample Class',
    'Winhider v.1.0',
    WS_POPUP or WS_CAPTION,
    round((scr_height/2)-(316/2)), round((scr_widht/2)-(174/2)),
    316, 174,
    0, 0,
    hInst, nil
  );

/// create lable and edits
   hMsgLabelPass:=CreateWindow(
    'Static',
    'Enter password for protection this window ...',
    WS_VISIBLE or WS_CHILD or SS_LEFT,
    8,10,390,50,Handle,0,hInst,nil
   );


    hMsgEditPass:=CreateWindowEx(
    WS_EX_CLIENTEDGE,
    'Edit',
    '',
    WS_VISIBLE or WS_CHILD or ES_LEFT or ES_AUTOHSCROLL or ES_PASSWORD,
    10,35,280,20,Handle,0,hInst,nil
   );

   hMsgLabelConf:=CreateWindow(
    'Static',
    'Confirm password for protection this window ',
    WS_VISIBLE or WS_CHILD or SS_LEFT,
    8,60,390,50,Handle,0,hInst,nil
   );

    hMsgEditConf:=CreateWindowEx(
    WS_EX_CLIENTEDGE,
    'Edit',
    '',
    WS_VISIBLE or WS_CHILD or ES_LEFT or ES_AUTOHSCROLL or ES_PASSWORD,
    10,85,280,20,Handle,0,hInst,nil
   );

/// create buttoms
   hMsgBtn:=CreateWindow(
    'Button',
    'OK',
    WS_VISIBLE or WS_CHILD or BS_PUSHLIKE or BS_TEXT,
    115,115,65,24,Handle,0,hInst,nil
   );

   hMsgYes:=CreateWindow(
    'Button',
    'Yes',
    WS_CHILD or BS_PUSHLIKE or BS_TEXT,
    55,115,65,24,Handle,0,hInst,nil
   );

   hMsgNo:=CreateWindow(
    'Button',
    'No',
    WS_CHILD or BS_PUSHLIKE or BS_TEXT,
    175,115,65,24,Handle,0,hInst,nil
   );

//// set default procs for edits and buttoms
  pr_Pass:=Pointer(GetWindowLong(hMsgEditPass,GWL_WNDPROC));
  SetWindowLong(hMsgEditPass,GWL_WNDPROC,Longint(@PassProc));

  pr_Conf:=Pointer(GetWindowLong(hMsgEditConf,GWL_WNDPROC));
  SetWindowLong(hMsgEditConf,GWL_WNDPROC,Longint(@ConfProc));

  pr_BtnClick:=Pointer(GetWindowLong(hMsgBtn,GWL_WNDPROC));
  SetWindowLong(hMsgBtn,GWL_WNDPROC,Longint(@BtnProc));

  pr_YesClick:=Pointer(GetWindowLong(hMsgYes,GWL_WNDPROC));
  SetWindowLong(hMsgYes,GWL_WNDPROC,Longint(@YesProc));

  pr_NoClick:=Pointer(GetWindowLong(hMsgNo,GWL_WNDPROC));
  SetWindowLong(hMsgNo,GWL_WNDPROC,Longint(@NoProc));

/// create popup menu

   hPopup:=CreatePopupMenu;
   hPopup_vis:=CreatePopupMenu;
   hPopup_invis:=CreatePopupMenu;
   hPopup_all_invis:=CreatePopupMenu;

/// adding items into main_popup

  AppendMenu(hPopup,MF_POPUP,hPopup_vis,'ALL VISIBLE WINDOWS');
  AppendMenu(hPopup,MF_POPUP,hPopup_invis,'HIDING BY WINHIDER');
  AppendMenu(hPopup,MF_POPUP,hPopup_all_invis,'ALL INVISIBLE WINDOWS');
  AppendMenu(hPopup,MF_SEPARATOR,5,nil);
  AppendMenu(hPopup,MF_STRING,10,'Clear Winhider`s invisible list');
  AppendMenu(hPopup,MF_STRING,11,'Hide Winhider`s tray icon');
  AppendMenu(hPopup,MF_SEPARATOR,6,nil);
  AppendMenu(hPopup,MF_STRING,12,'About...');
  AppendMenu(hPopup,MF_STRING,13,'Help...');
  AppendMenu(hPopup,MF_STRING,15,'History...');
  AppendMenu(hPopup,MF_STRING,14,'Exit');

///adding icon in tray

  NID.uID :=0;
  NID.Wnd := Handle;
  NID.uCallbackMessage :=WM_USER;
  NID.hIcon := LoadIcon(hInst,'winhider');
  NID.szTip := 'Winhider v.1.01';
  NID.uFlags :=NIF_ICON or NIF_MESSAGE or NIF_TIP;
  NID.cbSize :=sizeof(NID);

  Shell_NotifyIcon(NIM_ADD,@NID);
  icon_in_tray:=true;

  getVisibleW;
  getAllInVisibleW;

/// register global hotkes  
  RegisterHotKey(Handle,0,MOD_WIN or MOD_CONTROL or MOD_ALT,VK_F12);
  RegisterHotKey(Handle,1,MOD_WIN or MOD_CONTROL or MOD_ALT,VK_F9);
  RegisterHotKey(Handle,2,MOD_WIN or MOD_CONTROL or MOD_ALT,VK_F4);
  RegisterHotKey(Handle,3,MOD_WIN or MOD_CONTROL or MOD_ALT,VK_F5);

/// waiting messages cicle
  while(GetMessage(Msg,Handle,0,0))do
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;

end.

