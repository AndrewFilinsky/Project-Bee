unit Bee_Configuration;

{ Contains:

  Bee configuration support.

  (C) 2003-2007 Andrew Filinsky.

  Modifyed:

  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky.
  v0.7.9 build 0312 - 2007/02/16 by Andrew Filinsky.
}

{$I Compiler.inc}

interface

uses
  SysUtils,            // Trim
  Classes,             // TStringList
  Bee_Common;

const
  TablePagesCount = 2;

type
  TTablePage = record
    Escape: array [0..16] of cardinal;
    RecencyScaling: cardinal;
    FrequencyThreshold: cardinal;
    InitialFrequency: cardinal;
    RangeThreshold: cardinal;
  end;

  TTable = packed record
    Level: Cardinal;
    Page: array [0..TablePagesCount - 1] of TTablePage;
  end;

  TTableParameters = array [0..SizeOf (TTable) div SizeOf(Cardinal) - 1] of Byte;

  TConfigSection = class (TStringList)
  public
    function   GetTable (const Ext: string; out T: TTableParameters): Boolean;
    procedure  PutData  (const Name: string; var Data; aCount: Integer);
    function   GetData  (const Name: string; var Data; aCount: Integer): Boolean;
  end;

  TConfiguration = class (TStringList)
  public
    constructor Create;
    destructor  Destroy; override;

    procedure   LoadFromFile (const FileName: string); override;
    procedure   SaveToFile   (const FileName: string); override;
    function    GetTable     (const Ext: string; out T: TTableParameters): Boolean;
    procedure   PutData      (const Name: string; var Data; aCount: Integer);
    function    GetData      (const Name: string; var Data; aCount: Integer): Boolean;
    procedure   Selector     (const Name: string);
    function    Split        (const S: string; var Name, Value: string): Boolean;
  public
    CurrentSection: TConfigSection;
  end;

implementation

(***************************************************************************)
(* Class:  TConfiguration | methods
(* Domain: public
(***************************************************************************)

constructor TConfiguration.Create;
begin
  inherited;
  Selector ('\main');
end;

destructor TConfiguration.Destroy;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do Objects [I].Free;
  inherited;
end;

procedure TConfiguration.LoadFromFile (const FileName: string);
var
  List: TStringList;
  I: Integer;
  S, aName, aValue: string;
begin
  List := TStringList.Create;
  List.LoadFromFile (FileName);
  Selector ('\main');

  for I := 0 to List.Count - 1 do
  begin
    S := List [I];
    if (S > '') and (S [1] = '\') then
      Selector (S)
    else if (S = '') or (S [1] = ';') or not Split (S, aName, aValue) then
      CurrentSection.Add (S)
    else
      CurrentSection.Values [aName] := aValue
  end;

  Selector ('\main');
  List.Free;
end;

procedure TConfiguration.SaveToFile (const FileName: string);
var
  List: TStringList;
  I: Integer;
begin
  List := TStringList.Create;

  for I := 0 to Count - 1 do
  begin
    List.Add (Names [I]);
    List.AddStrings (TConfigSection (Objects [I]));
  end;

  List.SaveToFile (FileName);
  List.Free;
end;

function TConfiguration.GetTable (const Ext: string; out T: TTableParameters): Boolean;
var
  OldSection: TConfigSection;
begin
  OldSection := CurrentSection;
  Selector ('\main');
  Selector ('\m' + CurrentSection.Values ['Method']);
  Result := CurrentSection.GetTable (Ext, T);
  CurrentSection := OldSection;
end;

procedure TConfiguration.PutData (const Name: string; var Data; aCount: Integer);
begin
  CurrentSection.PutData (Name, Data, aCount);
end;

function TConfiguration.GetData (const Name: string; var Data; aCount: Integer): Boolean;
begin
  Result := CurrentSection.GetData (Name, Data, aCount);
end;

procedure TConfiguration.Selector (const Name: string);
var
  Index: Integer;
begin
  Index := IndexOfName (Name);
  if Index < 0 then
  begin
    CurrentSection := TConfigSection.Create;
    Objects [Add (Name + '=yes')] := CurrentSection;
  end else
    CurrentSection := TConfigSection (Objects [Index]);
end;

function TConfiguration.Split (const S: string; var Name, Value: string): Boolean;
var
  Index: Integer;
begin
  Index  := Pos ('=', S);
  Result := Index > 0;
  if Result then
  begin
    Name  := Trim (Copy (S, 1, Index - 1));
    Value := Trim (Copy (S, Index + 1, MaxInt));
  end;
end;

(***************************************************************************)
(* Class:  TConfigSection | methods
(* Domain: public
(***************************************************************************)

function TConfigSection.GetTable (const Ext: string; out T: TTableParameters): Boolean;
var
  S: string;
begin
  S := Values [Ext];
  Result := GetData (Ext, T, SizeOf (T));
  if not Result then
    Result := (S = '') and (CompareText (Ext, '.Default') <> 0) and GetTable ('.Default', T);
  if not Result then
    Result := (S > '') and (IndexOfName (S) >= 0) and (IndexOfName (S) < IndexOfName (Ext)) and GetTable (S, T);
end;

procedure TConfigSection.PutData (const Name: string; var Data; aCount: Integer);
begin
  Values [Name] := Hex (Data, aCount);
end;

function TConfigSection.GetData (const Name: string; var Data; aCount: Integer): Boolean;
begin
  FillChar (Data, aCount, 0);
  Result := HexToData (Values [Name], Data, aCount);
end;

end.

