unit Bee_Codec;

{ Contains:

  -- TSecondaryCodec class,   abstract secondary codec, similar to RangeCoder or Arithmetic Coder;
  -- TSecondaryEncoder class, implementation of secondary encoder;
  -- TSecondaryDecoder class, implementation of secondary decoder;

  (C) 2003-2005 Andrew Filinsky

  Modifyed:

  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky
  v0.7.9 build 0301 - 2007/01/23 by Andrew Filinsky.
}

{$I Compiler.inc}

interface

uses
  Bee_RangeCoder;       // TRangeCoder, ...

const
  MaxFreq = Bee_RangeCoder.MaxFreq;

type
  /// Abstract secondary codec, like a RangeCoder or Arithmetic Coder...

  TSecondaryCodec = class (TRangeCoder)
    procedure   Start; virtual; abstract;
    procedure   Flush; virtual; abstract;
    function    UpdateSymbol (Freq0, Freq1, Bit: cardinal): cardinal; overload; virtual; abstract;
    function    UpdateSymbol (const Freq: PCardinal; aSymbol, Count: cardinal): cardinal; overload; virtual; abstract;
  end;

  /// Range Encoder...

  TSecondaryEncoder = class (TSecondaryCodec)
    procedure   Start; override;
    procedure   Flush; override;
    function    UpdateSymbol (Freq0, Freq1, Bit: cardinal): cardinal; override;
    function    UpdateSymbol (const Freq: PCardinal; aSymbol, Count: cardinal): cardinal; override;
  end;

  /// Range Decoder...

  TSecondaryDecoder = class (TSecondaryCodec)
    procedure   Start; override;
    procedure   Flush; override;
    function    UpdateSymbol (Freq0, Freq1, Bit: cardinal): cardinal; override;
    function    UpdateSymbol (const Freq: PCardinal; aSymbol, Count: cardinal): cardinal; override;
  end;

implementation

{ Class TSecondaryEncoder }

procedure TSecondaryEncoder.Start;
begin
  StartEncode;
end;

procedure TSecondaryEncoder.Flush;
begin
  FinishEncode;
end;

function TSecondaryEncoder.UpdateSymbol(Freq0, Freq1, Bit: cardinal): cardinal;
begin
  EncodeBit(Freq0, Freq1, Bit);
  Result := Bit;
end;

function TSecondaryEncoder.UpdateSymbol(const Freq: PCardinal; aSymbol, Count: cardinal): cardinal;
var
  CumFreq, TotFreq, I: cardinal;
begin
  /// Count CumFreq...
  CumFreq := 0; I := 0; while I < aSymbol do begin Inc(CumFreq, Freq[I]); Inc(I); end;
  /// Count TotFreq...
  TotFreq := CumFreq;
  repeat Inc(TotFreq, Freq[I]); Inc(I); until I = Count;
  /// Encode...
  Encode(CumFreq, Freq[aSymbol], TotFreq);
  /// Return Result...
  Result := aSymbol;
end;

{ Class TSecondaryDecoder }

procedure TSecondaryDecoder.Start;
begin
  StartDecode;
end;

procedure TSecondaryDecoder.Flush;
begin
  FinishDecode;
end;

function TSecondaryDecoder.UpdateSymbol(Freq0, Freq1, Bit: cardinal): cardinal;
begin
  Result := DecodeBit(Freq0, Freq1);
end;

function TSecondaryDecoder.UpdateSymbol(const Freq: PCardinal; aSymbol, Count: cardinal): cardinal;
var
  CumFreq, TotFreq, SumFreq: cardinal;
begin
  /// Count TotFreq...
  TotFreq := 0;
  Result := Count;
  repeat Dec(Result); Inc(TotFreq, Freq[Result]); until Result = 0;
  /// Count CumFreq ...
  CumFreq := GetFreq(TotFreq);
  /// Search Result ...
  SumFreq := 0;
  while SumFreq + Freq[Result] <= CumFreq do begin Inc(SumFreq, Freq[Result]); Inc(Result); end;
  /// Finish Decode...
  Decode(SumFreq, Freq[Result], TotFreq);
end;

end.
