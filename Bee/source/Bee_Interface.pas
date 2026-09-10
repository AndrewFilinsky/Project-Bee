unit Bee_Interface;

{ Contains:

  TApp, abstract class of Thread.

  (C) 2005-2006 Melchiorre Caruso.

  Modifyed:

  v0.7.9 build 0298 - 2006/01/05 by Melchiorre Caruso.
}

{$I Compiler.inc}

interface

uses
  Classes;

type
  TAppListNode = class
  public
    FileName: string;
    FilePath: string;
    FileType: string;
    FileSize: integer;
    FilePacked: integer;
    FileRatio: integer;
    FileAttr: integer;
    FileTime: integer;
    FileComm: string;
    FileCrc: cardinal;
    FileMethod: string;
    FileVersion: string;
    FilePassword: string;
    FilePosition: integer;
    FileIcon: integer;
  end;

  TAppInterface = class
  public
    cMsg: string;
    cList: TList;
    cFileName: string;
    cFileSize: integer;
    cFileTime: integer;
    cPercentage: integer;
    OnOverWrite: TThreadMethod;
    OnRename: TThreadMethod;
    OnWarning: TThreadMethod;
    OnDisplay: TThreadMethod;
    OnError: TThreadMethod;
    OnList: TThreadMethod;
    OnTick: TThreadMethod;
    OnClear: TThreadMethod;
    OnKey: TThreadMethod;
  end;

  TApp = class (TThread)
  protected
    AppInterface: TAppInterface;
    AppParams: TStringList;
  public
    constructor Create (aAppInterface: TAppInterface; aAppParams: TStringList);
    procedure SetPriority (aPriority: integer);
  end;

implementation

/// TApp class ...

constructor TApp.Create (aAppInterface: TAppInterface; aAppParams: TStringList);
begin
  AppInterface := aAppInterface;
  AppParams := aAppParams;
  FreeOnTerminate := True;
  inherited Create(True);
end;

procedure TApp.SetPriority (aPriority: integer); // Priority is 0..3
begin
  case aPriority of
    3: Priority := tpTimeCritical;
    2: Priority := tpHigher;
    1: Priority := tpNormal;
    0: Priority := tpIdle;
    else Priority := tpNormal;
  end;
end;

end.

