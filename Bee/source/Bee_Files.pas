unit Bee_Files;

{ Contains:

  TFileReader class, bufferized TStream-similar input stream;
  TFileWriter class, bufferized TStream-similar output stream;
  TNulWriter class,  TStream-similar output stream, but works with 'nul' file.

  (C) 1999-2006 Andrew Filinsky and Melchiorre Caruso.

  Modifyed:

  v0.7.8 build 0148 - 2005/06/23 by Andrew Filinsky;
  v0.7.9 build 0298 - 2006/01/05 by Melchiorre Caruso.
}

{$I Compiler.inc}
{$R-}

interface

uses
  Classes,
  SysUtils,
  Bee_Assembler,        // Low-level routines ...
  Bee_Common,           // ForceDirectories (), ...
  Bee_BlowFish;

type
  TFileReader = class (TFileStream)
  public
    constructor  Create (const FileName: string; Mode: word);
    destructor   Destroy; override;
    function     Read (var aData; aCount: longint): longint; override;
    function     Seek (Offset: longint; Origin: word): longint; override;
  public
    BlowFish:    TBlowFish;
  private
    Size,
    Readed:      longint;
    LocalBuffer: array [0..$FFFF] of byte;
  end;

  TFileWriter = class (TFileStream)
  public
    constructor  Create (const FileName: string; Mode: word);
    destructor   Destroy; override;
    procedure    Flush;
    function     Write (const aData; aCount: longint): longint; override;
    function     Seek (Offset: longint; Origin: word): longint; override;
  public
    BlowFish:    TBlowFish;
  private
    Size:        longint;
    LocalBuffer: array [0..$FFFF] of byte;
  end;

  TNulWriter = class (TFileStream)
  public
    constructor  Create;
    destructor   Destroy; override;
    function     Read (var aData; aCount: longint): longint; override;
    function     Write (const aData; aCount: longint): longint; override;
    function     Seek (Offset: longint; Origin: word): longint; override;
  public
    BlowFish:    TBlowFish;
  protected
    procedure    SetSize (NewSize: longint); override;
  // private
  public
    Current,
    Longest:     longint;
  end;

implementation

(**************************************************************************
(* Class TFileReader
(**************************************************************************)

constructor TFileReader.Create (const FileName: string; Mode: word);
begin
  if (Mode and fmCreate <> 0) then
    Bee_Common.ForceDirectories (ExtractFilePath (FileName));
  BlowFish := TBlowFish.Create;
  Readed   := 0;
  Size     := 0;
  inherited;
end;

destructor TFileReader.Destroy;
begin
  BlowFish.Free;
  inherited;
end;

function TFileReader.Read (var aData; aCount: longint): longint;
var
  Data: array [0..MaxInt - 1] of byte absolute aData;
  S: longint;
begin
  if (aCount = 1) and (Readed < Size) then
  begin
    Data [0] := LocalBuffer [Readed];
    Inc (Readed);
    Result := aCount;
  end else
  begin
    Result := 0;
    while aCount > Size - Readed do
    begin
      S := Size - Readed;
      Move(LocalBuffer [Readed], Data [Result], S);
      Dec (aCount, S);
      Inc (Result, S);
      Readed := 0;
      Size := inherited Read (LocalBuffer, SizeOf (LocalBuffer));
      if BlowFish.Started then
        BlowFish.Decode (LocalBuffer, Size);
      if Size = 0 then Exit;
    end;
    Move(LocalBuffer [Readed], Data [Result], aCount);
    Inc (Readed, aCount);
    Inc (Result, aCount);
  end;
end;

function TFileReader.Seek (Offset: longint; Origin: word): longint;
begin
  Size   := 0;
  Readed := 0;
  Result := inherited Seek (Offset, Origin);
end;

(**************************************************************************
(* Class TFileWriter
(**************************************************************************)

constructor TFileWriter.Create (const FileName: string; Mode: word);
begin
  if (Mode and fmCreate <> 0) then
    Bee_Common.ForceDirectories (ExtractFilePath (FileName));
  BlowFish := TBlowFish.Create;
  Size := 0;
  inherited;
end;

destructor TFileWriter.Destroy;
begin
  if Size > 0 then Flush;
  BlowFish.Free;
  inherited;
end;

procedure TFileWriter.Flush;
begin
  if BlowFish.Started then
    Size := BlowFish.Encode (LocalBuffer, Size);
  if inherited Write (LocalBuffer, Size) <> Size then
    raise EWriteError.Create ('SWriteError');
  Size := 0;
end;

function TFileWriter.Write (const aData; aCount: longint): longint;
var
  Data: array [0..MaxInt - 1] of byte absolute aData;
  S: longint;
begin
  if (aCount = 1) and (Size < SizeOf (LocalBuffer)) then
  begin
    LocalBuffer [Size] := Data [0];
    Inc (Size);
    Result := aCount;
  end else
  begin
    Result := 0;
    while aCount - Result > SizeOf (LocalBuffer) - Size do
    begin
      S := SizeOf (LocalBuffer) - Size;
      Move(Data [Result], LocalBuffer [Size], S);
      Inc (Size, S);
      Inc (Result, S);
      Flush;
    end;
    Move(Data [Result], LocalBuffer [Size], aCount - Result);
    Inc (Size, aCount - Result);
    Inc (Result, aCount - Result);
  end;
end;

function TFileWriter.Seek (Offset: longint; Origin: word): longint;
begin
  if Size > 0 then Flush;
  Result := inherited Seek (Offset, Origin);
end;

(**************************************************************************
(* Class TNulWriter
(**************************************************************************)

constructor TNulWriter.Create;
begin
  inherited Create ('nul', fmCreate);
  BlowFish := TBlowFish.Create;
  Current  := 0;
  Longest  := 0;
end;

destructor TNulWriter.Destroy;
begin
  BlowFish.Free;
  inherited;
end;

function TNulWriter.Read (var aData; aCount: longint): longint;
begin
  Result := 0;
end;

function TNulWriter.Write (const aData; aCount: longint): longint;
begin
  Inc (Current, aCount);
  if Current > Longest then Longest := Current;
  Result := aCount;
end;

function TNulWriter.Seek(Offset: longint; Origin: word): longint;
begin
  case Origin of
    soFromCurrent: Inc(Offset, Current);
    soFromEnd: Inc(Offset, Longest);
  end;

  Current := Offset;
  if Current > Longest then Longest := Current;
  Result  := Offset;
end;

procedure TNulWriter.SetSize(NewSize: longint);
begin
  Current := NewSize;
  Longest := NewSize;
end;

end.
