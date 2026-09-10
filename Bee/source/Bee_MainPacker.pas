unit Bee_MainPacker;

{ Contains:

  TEncoder class, file encoder;
  TDecoder class, file decoder;

  (C) 1999-2006 Andrew Filinsky and Melchiorre Caruso.

  Modifyed:

  v0.7.8 build 0148 - 2005/06/23 by Melchiorre Caruso;
  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky;

  v0.7.9 build 0298 - 2006/01/05 by Melchiorre Caruso.
}

{$I Compiler.inc}

interface

uses
  SysUtils,      // FileSetAttr...
  Classes,       // TStream
  Bee_Files,     // TBufferizedReader
  Bee_Crc,       // UpdCrc32...
  Bee_Headers,

  Bee_Assembler, // Low-level routines ...
  Bee_Common,    // Diag...
  Bee_Codec,     // TSecondaryEncoder, TSecondaryDecoder...
  Bee_BlowFish,
  Bee_Modeller,  // TBaseCoder...
  Bee_Interface;

const
  msgUpdating   = 'Updating   ';
  msgExtracting = 'Extracting ';
  msgTesting    = 'Testing    ';
  msgSkipping   = 'Skipping   ';
  msgEncoding   = 'Encoding   ';
  msgDecoding   = 'Decoding   ';
  msgCopying    = 'Copying    ';
  msgDeleting   = 'Deleting   ';
  msgScanning   = 'Scanning   ';
  msgOpening    = 'Opening    ';
  msgListing    = 'Listing    ';
  msgRenaming   = 'Renaming   ';
  msgRename     = 'Rename     ';
  msgAdding     = 'Adding     ';
  msgCRCERROR   = 'CRC-ERROR  ';

// Extracting Modes:
//   pmNorm  Extract files
//   pmSkip  Extract files, but skip current
//   pmTest  Test files (Extract to nul)
//   pmQuit  Cancel extracting

type
  TExtractMode = (pmNorm, pmSkip, pmTest, pmQuit);

// Encoding Modes:
//   emNorm  Encode files
//   emOpt   Encode files to nul, with no messages

type
  TEncodingMode = (emNorm, emOpt);

  // Execution Estimator, estimates execution percentage...

  TSynchronize = procedure (Method: TThreadMethod) of object;

  TPercentes = class
  private
    Synchronize: TSynchronize;
    procedure Tick;
  public
    GeneralSize: integer;
    RemainSize: integer;
    AppInterface: TAppInterface;
    constructor Create (aSynchronize: TSynchronize; aAppInterface: TAppInterface);
  end;

  // Encoder ...

  TEncoder = class
  public
    constructor  Create       (aStream: TStream; aPercentes: TPercentes);
    destructor   Destroy;     override;
    function     EncodeFile   (Header: THeader; Mode: TEncodingMode): Boolean;
    function     EncodeStrm   (Header: THeader; Mode: TEncodingMode; SrcStrm: TStream): Boolean;
    function     CopyStrm     (Header: THeader; Mode: TEncodingMode; SrcStrm: TStream): Boolean;
  private
    function     GetKey       (Header: THeader): string;
  private
    Stream: TStream;
    PPM: TBaseCoder;
    SecondaryCodec: TSecondaryCodec;
    Percentes: TPercentes;
  end;

  // Decoder ...

  TDecoder = class
  public
    constructor  Create       (aStream: TStream; aPercentes: TPercentes);
    destructor   Destroy;     override;
    function     DecodeFile   (Header: THeader; Mode: TExtractMode): Boolean;
    function     DecodeStrm   (Header: THeader; Mode: TExtractMode; DstStrm: TStream): Boolean;
  private
    function     GetKey       (Header: THeader): string;
  private
    Stream: TStream;
    PPM: TBaseCoder;
    SecondaryCodec: TSecondaryCodec;
    Percentes: TPercentes;
  end;

implementation

/// TPercentes

constructor TPercentes.Create (aSynchronize: TSynchronize; aAppInterface: TAppInterface);
begin
  RemainSize := 0;
  GeneralSize := 0;

  Synchronize := aSynchronize;
  AppInterface := aAppInterface;
end;

procedure TPercentes.Tick;
begin
  if RemainSize and $FFFF = 0 then
  begin
    AppInterface.cPercentage := MulDiv (RemainSize, 100, GeneralSize);
    Synchronize (AppInterface.OnTick);
  end;
  Inc (RemainSize);
end;

/// TEncoder

constructor TEncoder.Create;
begin
  Stream := aStream;
  Percentes := aPercentes;
  SecondaryCodec := TSecondaryEncoder.Create (Stream);
  PPM := TBaseCoder.Create (SecondaryCodec);
end;

destructor TEncoder.Destroy;
begin
  PPM.Free;
  SecondaryCodec.Free;
end;

function TEncoder.GetKey;
begin
  Percentes.AppInterface.cFileName := Header.Name;
  Percentes.AppInterface.cFileSize := Header.Size;
  Percentes.AppInterface.cFileTime := Header.Time;

  Percentes.Synchronize (Percentes.AppInterface.OnKey);
  Result := Percentes.AppInterface.cMsg;

  if Length (Percentes.AppInterface.cMsg) < MinKeyLength then
    Exclude (Header.Flags, foPassword);
end;

function TEncoder.EncodeFile;
var
  SrcFile: TFileReader;
  Symbol: byte;
  I: integer;
begin
  if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
  if foTable in Header.Flags then PPM.SetTable (Header.Table);
  if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

  Header.StartPos := Stream.Seek (0, 1); // stream flush
  Header.Crc := Cardinal (-1);

  try
    SrcFile := TFileReader.Create (Header.Name, fmOpenRead + fmShareDenyWrite);
  except
    SrcFile := nil;
  end;

  if (SrcFile <> nil) then
  begin
    if Mode = emNorm then
    begin
      Percentes.AppInterface.cMsg := msgUpdating + Header.GetName;
      Percentes.Synchronize (Percentes.AppInterface.OnDisplay);
    end;

    Header.Size := SrcFile.Size;
    Header.Attr := FileGetAttr (Header.Name);

    if foPassword in Header.Flags then TFileWriter (Stream).BlowFish.Start (GetKey (Header));

    if foMoved in Header.Flags then
    begin
      for I := 1 to Header.Size do
      begin
        if Mode = emNorm then Percentes.Tick;
        SrcFile.Read (Symbol, 1);
        UpdCrc32 (Header.Crc, Symbol);
        Stream.Write (Symbol, 1);
      end;
    end else
    begin
      SecondaryCodec.Start;
      for I := 1 to Header.Size do
      begin
        if Mode = emNorm then Percentes.Tick;
        SrcFile.Read (Symbol, 1);
        UpdCrc32 (Header.Crc, Symbol);
        PPM.UpdateModel (Symbol);
      end;
      SecondaryCodec.Flush;
    end;
    SrcFile.Free;

    Header.PackedSize := Stream.Seek (0 ,1) - Header.StartPos; // last stream flush
    TFileWriter (Stream).BlowFish.Finish; // finish after last stream flush

    if Mode = emNorm then Percentes.Synchronize (Percentes.AppInterface.OnClear);

  end else
  begin
    Percentes.AppInterface.cMsg := ('Error: can''t open file ' + Header.Name);
    Percentes.Synchronize (Percentes.AppInterface.OnError);
  end;

  if (not (foMoved in Header.Flags)) and (Header.PackedSize > Header.Size) then
  begin
    Include (Header.Flags, foTear);
    Include (Header.Flags, foMoved);
    Stream.Size := Header.StartPos;
    Result := EncodeFile (Header, emOpt);
  end else
    Result := True;
end;

function  TEncoder.EncodeStrm;
var
  SrcFile: TStream;
  SrcPosition: integer;
  Symbol: Byte;
  I: Integer;
begin
  if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
  if foTable in Header.Flags then PPM.SetTable (Header.Table);
  if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

  SrcPosition := 0;
  SrcFile := SrcStrm;

  if (SrcFile <> nil) then
  begin
    if Mode = emNorm then
    begin
      Percentes.AppInterface.cMsg := msgEncoding + Header.Name;
      Percentes.Synchronize (Percentes.AppInterface.OnDisplay);
    end;

    SrcPosition:= Header.StartPos;
    SrcFile.Seek (Header.StartPos, 0);

    Header.Crc := Cardinal (-1);
    Header.StartPos := Stream.Seek (0, 1); // stream flush

    if foPassword in Header.Flags then
    begin
      TFileReader (SrcFile).BlowFish.Start (GetKey (Header));
      TFileWriter (Stream ).BlowFish.Start (Percentes.AppInterface.cMsg);
    end;

    if foMoved in Header.Flags then
    begin
      for I := 1 to Header.Size do
      begin
        if Mode = emNorm then Percentes.Tick;
        SrcFile.Read (Symbol, 1);
        UpdCrc32 (Header.Crc, Symbol);
        Stream.Write (Symbol, 1);
      end;
    end else
    begin
      SecondaryCodec.Start;
      for I := 1 to Header.Size do
      begin
        if Mode = emNorm then Percentes.Tick;
        SrcFile.Read (Symbol, 1);
        UpdCrc32 (Header.Crc, Symbol);
        PPM.UpdateModel (Symbol);
      end;
      SecondaryCodec.Flush;
    end;
    TFileReader (SrcFile).BlowFish.Finish;

    Header.PackedSize := Stream.Seek (0, 1) - Header.StartPos; // last stream flush
    TFileWriter (Stream).BlowFish.Finish; // finish after last stream flush

    if Mode = emNorm then Percentes.Synchronize (Percentes.AppInterface.OnClear);

  end else
  begin
    Percentes.AppInterface.cMsg := ('Error: stream  not found');
    Percentes.Synchronize (Percentes.AppInterface.OnError);
  end;

  if (not (foMoved in Header.Flags)) and (Header.PackedSize > Header.Size) then
  begin
    Include (Header.Flags, foTear);
    Include (Header.Flags, foMoved);
    Stream.Size := Header.StartPos;
    Header.StartPos := SrcPosition;
    Result := EncodeStrm (Header, emOpt, SrcStrm);
  end else
    Result := True;
end;

function  TEncoder.CopyStrm;
var
  SrcFile: TStream;
  Symbol: Byte;
  I: Integer;
begin
  if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
  if foTable in Header.Flags then PPM.SetTable (Header.Table);
  if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

  SrcFile := SrcStrm;

  if (SrcFile <> nil) then
  begin
    if Mode = emNorm then
    begin
      Percentes.AppInterface.cMsg := msgCopying + Header.Name;
      Percentes.Synchronize (Percentes.AppInterface.OnDisplay);
    end;

    SrcFile.Seek (Header.StartPos, 0);
    Header.StartPos := Stream.Seek (0, 1);

    for I := 1 to Header.PackedSize do
    begin
      if Mode = emNorm then Percentes.Tick;
      SrcFile.Read (Symbol, 1);
      Stream.Write (Symbol, 1);
    end;

    if Mode = emNorm then Percentes.Synchronize (Percentes.AppInterface.OnClear);

  end else
  begin
    Percentes.AppInterface.cMsg := ('Error: stream  not found');
    Percentes.Synchronize (Percentes.AppInterface.OnError);
  end;

  Result := True;
end;

/// TDecoder

constructor  TDecoder.Create;
begin
  Stream := aStream;
  Percentes := aPercentes;
  SecondaryCodec := TSecondaryDecoder.Create (Stream);
  PPM := TBaseCoder.Create (SecondaryCodec);
end;

destructor  TDecoder.Destroy;
begin
  PPM.Free;
  SecondaryCodec.Free;
end;

function TDecoder.GetKey;
begin
  Percentes.AppInterface.cFileName := Header.Name;
  Percentes.AppInterface.cFileSize := Header.Size;
  Percentes.AppInterface.cFileTime := Header.Time;

  Percentes.Synchronize (Percentes.AppInterface.OnKey);
  Result := Percentes.AppInterface.cMsg;
end;

function  TDecoder.DecodeFile;
var
  DstFile: TStream;
  Symbol: Byte;
  I, Crc: Cardinal;
begin
  if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
  if foTable in Header.Flags then PPM.SetTable (Header.Table);
  if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

  case Mode of
    pmSkip: Percentes.AppInterface.cMsg := msgSkipping   + Header.Name;
    pmTest: Percentes.AppInterface.cMsg := msgTesting    + Header.Name;
    pmNorm: Percentes.AppInterface.cMsg := msgExtracting + Header.Name;
    pmQuit: begin Result := True; Exit; end;
  end;
  Percentes.Synchronize (Percentes.AppInterface.OnDisplay);

  Stream.Seek (Header.StartPos, 0); // stream flush
  Crc := Cardinal (-1);

  if Mode = pmNorm then
    try
      DstFile := TFileWriter.Create (Header.Name, fmCreate)
    except
      DstFile := nil;
    end
  else
    DstFile := TNulWriter.Create;

  if (DstFile <> nil) then
  begin
    if foPassword in Header.Flags then TFileReader (Stream).BlowFish.Start (GetKey (Header));

    if foMoved in Header.Flags then
    begin
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Stream.Read (Symbol, 1);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
    end else
    begin
      SecondaryCodec.Start;
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Symbol := PPM.UpdateModel (0);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
      SecondaryCodec.Flush;
    end;
    TFileReader (Stream).BlowFish.Finish;

    if Mode = pmNorm then
    begin
      TFileWriter (DstFile).Flush;
      FileSetDate (TFileWriter (DstFile).Handle, Header.Time);
    end;
    DstFile.Free;

    if Mode = pmNorm then FileSetAttr (Header.Name, Header.Attr);

    Percentes.Synchronize (Percentes.AppInterface.OnClear);
  end;

  Result := Header.Crc = Crc;
  if Result = False then
  begin
    if Crc = Cardinal (-1) then
      Percentes.AppInterface.cMsg := ('Error: can''t open file ' + Header.Name)
    else
      Percentes.AppInterface.cMsg := msgCRCERROR + Header.Name;
    Percentes.Synchronize (Percentes.AppInterface.OnError);
  end;
end;

function  TDecoder.DecodeStrm;
var
  DstFile: TStream;
  I, Crc: Cardinal;
  Symbol: Byte;
begin              
  if foDictionary in Header.Flags then PPM.SetDictionary (Header.Dictionary);
  if foTable in Header.Flags then PPM.SetTable (Header.Table);
  if foTear in Header.Flags then PPM.FreshFlexible else PPM.FreshSolid;

  case Mode of
    pmSkip: Percentes.AppInterface.cMsg := msgSkipping + Header.Name;
    pmTest: Percentes.AppInterface.cMsg := msgTesting  + Header.Name;
    pmNorm: Percentes.AppInterface.cMsg := msgDecoding + Header.Name;
    pmQuit: begin Result := True; Exit; end;
  end;
  Percentes.Synchronize (Percentes.AppInterface.OnDisplay);

  Stream.Seek (Header.StartPos, 0);
  Crc := Cardinal (-1);

  if Mode = pmNorm then
    try
      DstFile         := DstStrm;
      Header.StartPos := DstFile.Seek (0, 1);
    except
      DstFile := nil;
    end
  else
    DstFile := TNulWriter.Create;

  if (DstFile <> nil) then
  begin
    if foPassword in Header.Flags then
    begin
      TFileReader (Stream ).BlowFish.Start (GetKey (Header));
      TFileWriter (DstFile).BlowFish.Start (Percentes.AppInterface.cMsg);
    end;

    if foMoved in Header.Flags then
    begin
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Stream.Read (Symbol, 1);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
    end else
    begin
      SecondaryCodec.Start;
      for I := 1 to Header.Size do
      begin
        Percentes.Tick;
        Symbol := PPM.UpdateModel (0);
        UpdCrc32 (Crc, Symbol);
        DstFile.Write (Symbol, 1);
      end;
      SecondaryCodec.Flush;
    end;
    TFileReader (Stream).BlowFish.Finish;

    if Mode = pmNorm then TFileWriter (DstFile).Flush; // last stream flush
    TFileWriter (DstFile).BlowFish.Finish; // finish after last stream flush

    Percentes.Synchronize (Percentes.AppInterface.OnClear);
  end;

  Result := Header.Crc = Crc;
  if Result = False then
  begin
    if Crc = Cardinal (-1) then
      Percentes.AppInterface.cMsg := ('Error: stream not found')
    else
      Percentes.AppInterface.cMsg := msgCRCERROR + Header.Name;
    Percentes.Synchronize (Percentes.AppInterface.OnError);
  end;
end;

end.
