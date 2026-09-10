unit Bee_Common;

{ Contains:

  Various helper routines.

  (C) 1999-2006 Andrew Filinsky and Melchiorre Caruso

  Modifyed:

  v0.7.8 build 0150 - 2005/06/27 by Melchiorre Caruso;
  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky;
  v0.7.8 build 0154 - 2005/07/23 by Melchiorre Caruso;
  v0.7.9 build 0298 - 2006/01/05 by Melchiorre Caruso;
  v0.7.9 build 0301 - 2007/01/23 by Andrew Filinsky.
  v0.7.9 build 0316 - 2007/02/16 by Andrew Filinsky.
}

{$I Compiler.inc}

interface

uses
  Math,
  Windows,
  SysUtils;

const
  Cr = #13#10;
  Cl = #13'                                                                               '#13;
  KeyPressed = False;

  RecursiveSign = '*\';
  PathDelim = '\';

type
  TByteArray = array [0..MaxInt - 1] of Byte;

// string text functions

function CompareText (const S1, S2: string): Integer;
function PosText (const Substr, Str: string): Integer;
function DeleteText (const SubStr, Str: string): string;

// filename utilies

procedure DoDirSeparators (var FileName: string);
function DeleteFileDrive (const FileName: string): string;
function IncludeDelimiter (const DirName: string): string;
function FixFileName (const FileName: string): string;

// oem-ansi charset functions

function ParamToOem(const Param: string): AnsiString;
function OemToParam(const Param: AnsiString): string;

// end new function

procedure DelLine;
procedure Line (const S: string);
procedure LineLn (const S: string);
procedure Pause;
function  DateTime (DateTime: TDateTime): string;
function  TimeDifference (X: Double): string;

function  DirectoryExists (const DirName: string): Boolean;
function  ForceDirectories (const Dir: string): Boolean;

function  CreateText (var T: text; const Name: string): Boolean;
function  AppendText (var T: text; const Name: string): Boolean;
function  OpenText (var T: text; const Name: string): Boolean;
function  WriteText (const FileName, S: string): Boolean;

function  CreateFile (var F: file; const Name: string): Boolean;
function  AppendFile (var F: file; const Name: string): Boolean;
function  OpenFile (var F: file; const Name: string): Boolean;

// Filename handling routines

function  SelfName: string;
function  SelfPath: string;
function  GenerateFilename (const Path: string): string;
function  ConcatFiles (const FromName, ToName: string): Boolean;
function  SizeOfFile (const Name: string): Integer;

// String handling routines

function  LastPos (const Substr, S: string): Integer;
function  Spaces (Count: Integer): string;

function  StoI (const S: string; var I: Integer): Boolean;
function  ExtrR (const S: string; From, Length: Integer): Double;
function  ExtrI (const S: string; From, Length: Integer): Integer;

function  ReadIntFromString (var S: string; var Value: Integer): Boolean;
function  ReadByteFromString (var S: string; var Value: Byte): Boolean;

function  Hex (const Data; Count: Integer): string;
function  HexToData (const S: string; var Data; Count: Integer): Boolean;

// Math extension routines

function  Sgn (A: Double): Integer;
function  IsInside (X, A, B: Integer): Boolean;

// Debugging

procedure Debug (I: Integer);
procedure DBack;

// Strings matching

function MatchString (const S, Before, After: string; var Matched: string): Boolean;

// System control

function SetPriority (Priority: Integer): Boolean; // Priority is 0..3

implementation

const
  HexaDecimals: array [0..15] of Char = '0123456789ABCDEF';
  HexValues: array ['0'..'F'] of Byte = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0, 10, 11, 12, 13, 14, 15);

  // new functions

function PosText (const Substr, Str: string): Integer;
begin
  Result := Pos (LowerCase (SubStr), LowerCase (Str));
  // {$IFDEF UNIX} Result := Pos (SubStr, Str); {$ENDIF}
end;

function DeleteText (const SubStr, Str: string): string;
begin
  Result := Str;
  if PosText (SubStr, Result) = 1 then
    Delete (Result, 1, Length (SubStr));
end;

function CompareText (const S1, S2: string): Integer;
begin
  Result := Sysutils.CompareText (S1, S2);
  // {$IFDEF UNIX} Result := Sysutils.CompareStr (S1, S2); {$ENDIF}
end;

function DeleteFileDrive (const FileName: string): string;
begin
  Result := FileName;
  if Pos (':' + PathDelim, Result) = 2 then Delete (Result, 1, 3);
  while Pos (PathDelim, Result) = 1 do
    Delete (Result, 1, 1);
end;

procedure DoDirSeparators (var FileName: string);
var
  I: Integer;
begin
  for I := 1 to Length (FileName) do
    if FileName [I] in ['\', '/'] then
      FileName [I] := PathDelim;
end;

function IncludeDelimiter (const DirName: string): string;
begin
  if Length (DirName) = 0 then
    Result := DirName
  else
    Result := IncludeTrailingBackslash (DirName);
end;

function FixFileName (const FileName: string): string;
const
  DoublePathDelim = PathDelim + PathDelim;
var
  I: Integer;
begin
  Result := FileName;
  DoDirSeparators (Result);
  I := Pos (DoublePathDelim, Result);
  while I > 0 do
  begin
    System.Delete (Result, I, 2);
    I := Pos (DoublePathDelim, Result);
  end;
  Result := ExcludeTrailingBackSlash (Result);
  if Pos (PathDelim, Result) = 1 then
    System.Delete (Result, I, 1);
end;

// oem-ansi charset functions

function ParamToOem(const Param: string): AnsiString;
begin
  if Length(Param) = 0 then
    Result := ''
  else
  begin
    SetLength(Result, Length(Param));
    CharToOem(PChar(Param), PAnsiChar(Result));
  end;
  // {$IFDEF UNIX} Result := Param; {$ENDIF}
end;

function OemToParam(const Param: AnsiString): string;
begin
  if Length(Param) = 0 then
    Result := ''
  else
  begin
    SetLength(Result, Length(Param));
    OemToChar(PAnsiChar(Param), PChar(Result));
  end;
  // {$IFDEF UNIX} Result := Param; {$ENDIF}
end;

// end new function

procedure DelLine;
begin
  Write (#13, #13: 80);
end;

procedure Line (const S: string);
begin
  DelLine;
  Write (S);
end;

procedure LineLn (const S: string);
begin
  DelLine;
  Writeln (S);
end;

procedure Pause;
begin
  Line ('Press ENTER to continue');
  Readln;
  DelLine;
end;

function DateTime (DateTime: TDateTime): string;
var
  Year, Month, Day, Hour, Min, Sec, MSec: Word;
begin
  DecodeDate (DateTime, Year, Month, Day);
  DecodeTime (DateTime, Hour, Min, Sec, MSec);
  Result := Format ('%2.2d/%2.2u/%2.2u %2.2u:%2.2u', [Year mod 100, Month, Day, Hour, Min]);
end;

function TimeDifference (X: Double): string;
begin
  Result := Format ('%f', [(Now - X) * (24 * 60 * 60)]); ;
end;

function DirectoryExists (const DirName: string): Boolean;
var
  Code: Integer;
begin
  Code := FileGetAttr (DirName);
  Result := (Code <> -1) and (faDirectory and Code <> 0);
end;

function ForceDirectories (const Dir: string): Boolean;
begin
  Result := True;
  if Dir = '' then Exit;
  if Dir [Length (Dir)] = '\' then
    Result := ForceDirectories (Copy (Dir, 1, Length (Dir) - 1))
  else
  begin
    if DirectoryExists (Dir) or (ExtractFilePath (Dir) = Dir) then Exit;
    if ForceDirectories (ExtractFilePath (Dir)) then
      Result := CreateDir (Dir)
    else
      Result := False;
  end;
end;

function CreateText (var T: text; const Name: string): Boolean;
begin
  {$I-} Assign (T, Name); Rewrite (T); {$I+} Result := IOResult = 0;
end;

function AppendText (var T: text; const Name: string): Boolean;
begin
  {$I-} Assign (T, Name); Append (T); {$I+} Result := IOResult = 0;
end;

function OpenText (var T: text; const Name: string): Boolean;
begin
  {$I-} Assign (T, Name); Reset (T); {$I+} Result := IOResult = 0;
end;

function WriteText (const FileName, S: string): Boolean;
var
  T: Text;
begin
  if AppendText (T, FileName) or CreateText (T, FileName) then
  begin
    Write (T, S);
    Close (T);
    Result := True;
  end
  else
    Result := False;
end;

function CreateFile (var F: file; const Name: string): Boolean;
begin
  {$I-}Assign (F, Name); Rewrite (F, 1); {$I+}Result := IOResult = 0;
end;

function AppendFile (var F: file; const Name: string): Boolean;
begin
  {$I-}Assign (F, Name); Reset (F, 1); Seek (F, FileSize (F)); {$I+}Result := IOResult = 0;
end;

function OpenFile (var F: file; const Name: string): Boolean;
begin
  {$I-}Assign (F, Name); Reset (F, 1); {$I+}Result := IOResult = 0;
end;

// Filename handling routines ...

function SelfName: string;
begin
  Result := ExtractFileName (ParamStr (0));
end;

function SelfPath: string;
begin
  Result := ExtractFilePath (ParamStr (0));
end;

function GenerateFilename (const Path: string): string;
var
  I: Integer;
begin
  repeat
    Result := '????????.$$$';
    for I := 1 to 8 do
      Result [I] := Char (Byte ('A') + Random (Byte ('Z') - Byte ('A')));
    if Path > '' then Result := IncludeTrailingBackslash (Path) + Result;
  until not FileExists(Result);
end;

function ConcatFiles (const FromName, ToName: string): Boolean;
var
  FFrom, FTo: file;
  B: array [0..255] of Byte;
  K: Longint;
begin
  Result := False;
  if not OpenFile (FFrom, FromName) then Exit;

  if not AppendFile (FTo, ToName) and not CreateFile (FTo, ToName) then
  begin
    Close (FFrom);
    Exit;
  end;

  repeat
    BlockRead (FFrom, B, SizeOf (B), K);
    BlockWrite (FTo, B, K);
  until K = 0;

  Close (FFrom);
  Close (FTo);
  Result := True;
end;

function SizeOfFile (const Name: string): Integer;
var
  F: file;
begin
  if OpenFile (F, Name) then
  begin
    Result := FileSize (F);
    Close (F);
  end
  else
    Result := -1;
end;

// String handling routines ...

function LastPos (const Substr, S: string): Integer;
begin
  if Substr > '' then
  begin
    Result := Length (S);
    while (Result > 0) and (Copy (S, Result, Length (Substr)) <> Substr) do
      Dec (Result);
  end
  else
    Result := 0;
end;

function Spaces (Count: Integer): string;
begin
  Result := StringOfChar (' ', Count);
end;

function Stoi (const S: string; var I: Integer): Boolean;
var
  Err: Integer;
begin
  Val (S, I, Err);
  Result := (Err = 0);
end;

function ExtrR (const S: string; From, Length: Integer): Double;
var
  Err: Integer;
begin
  Val (Copy (S, From, Length), Result, Err);
end;

function ExtrI (const S: string; From, Length: Integer): Integer;
var
  Err: Integer;
begin
  Val (Copy (S, From, Length), Result, Err);
end;

function ReadIntFromString (var S: string; var Value: Integer): Boolean;
var
  BlankPos, Err: Integer;
begin
  repeat
    BlankPos := Pos (' ', S);
    if BlankPos > 0 then
      Val (Copy (S, 1, BlankPos - 1), Value, Err)
    else
      Val (S, Value, Err);
    Delete (S, 1, BlankPos);
    Result := Err = 0;
  until Result or (S = '') or (BlankPos < 1);
end;

function ReadByteFromString (var S: string; var Value: Byte): Boolean;
var
  SubValue: Integer;
begin
  Result := ReadIntFromString (S, SubValue) and (SubValue and $FFFFFF00 = 0);
  Value := SubValue;
end;

function Hex (const Data; Count: Integer): string;
var
  I, J: Integer;
  K: cardinal;
begin
  SetLength (Result, Count shl 1);
  J := 1;
  for I := 0 to Count - 1 do
  begin
    K := TByteArray (Data) [I];
    Result [J] := HexaDecimals [K shr 4]; Inc (J);
    Result [J] := HexaDecimals [K and $F]; Inc (J);
  end;
end;

function HexToData (const S: string; var Data; Count: Integer): Boolean;
var
  I: Integer;
begin
  Result := false;
  if Length (S) < Count * 2 then Exit;
  for I := 0 to Count - 1 do
    if (S [I * 2 + 1] in ['0'..'9', 'A'..'F'])
      and (S [I * 2 + 2] in ['0'..'9', 'A'..'F']) then
      TByteArray (Data) [I] := HexValues [S [I * 2 + 1]] shl 4 + HexValues [S [I * 2 + 2]]
    else
      Exit;
  Result := true;
end;

// Math extension routines ...

function Sgn (A: Double): Integer;
begin
  if A = 0 then
    Sgn := 0
  else if A < 0 then
    Sgn := -1
  else
    Sgn := 1;
end;

function IsInside (X, A, B: Integer): Boolean;
begin
  Result := (X >= A) and (X <= B);
end;

// Debugging

procedure Debug (I: Integer);
begin
  Write ('(', I: 3, ')');
end;

procedure DBack;
begin
  Write (#8#8#8#8#8'     '#8#8#8#8#8);
end;

// Strings matching

function MatchString (const S, Before, After: string; var Matched: string): Boolean;
var
  Sample: string;
begin
  Sample := Trim (S);

  if UpperCase (Copy (Sample, 1, Length (Before))) <> UpperCase (Before) then
  begin
    Result := false;
    Exit;
  end
  else
    Delete (Sample, 1, Length (Before));

  if UpperCase (Copy (Sample, Length (Sample) - Length (After) + 1, MaxInt)) <> UpperCase (After) then
  begin
    Result := false;
    Exit;
  end
  else
    SetLength (Sample, Length (Sample) - Length (After));

  Matched := Trim (Sample);
  Result := True;
end;

// System control

function SetPriority (Priority: Integer): Boolean; // Priority is 0..3
const
  PriorityValue: array [0..3] of Integer = (IDLE_PRIORITY_CLASS, NORMAL_PRIORITY_CLASS, HIGH_PRIORITY_CLASS, REALTIME_PRIORITY_CLASS);
begin
  Result := SetPriorityClass (GetCurrentProcess, PriorityValue [Max (0, Min (Priority, 3))]);
end;

end.

