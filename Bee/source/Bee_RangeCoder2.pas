unit Bee_RangeCoder2;

{ Contains:

  TRangeCoder class,

    kind of RangeCoder
      (based on Eugeny Shelwien's shindler_var1
        (based on Shindler's rangecoder), MaxFreq = 2^24);
    It uses MulDiv opcode extension.

  (C) 2003 Evgeny Shelwien;
  (C) 2003-2007 Andrew Filinsky.

  Created:

  v0.1.0 build 0001 - 2003/02/01 by Evgeny Shelwien.

  Translated:

  v0.1.1 build 0002 - 2003/03/01 by Andrew Filinsky.

  Modifyed:

  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky;
  v0.7.9 build 0301 - 2007/01/23 by Andrew Filinsky.
  v0.7.9 build 0316 - 2007/02/16 by Andrew Filinsky.
}

{$R-,Q-,S-,O+}

interface

uses
  Classes,          /// TStream, ...
  Bee_Assembler;    /// Low-level routines ...

const
  TOP     = 1 shl 24;
  NUM     = 4;
  Thres   = 255 * cardinal (TOP);
  MaxFreq = TOP - 1;

type
  TRangeCoder = class
    constructor Create (aStream: TStream);

    procedure   StartEncode;
    procedure   StartDecode;
    procedure   FinishEncode;
    procedure   FinishDecode;
    procedure   Encode  (CumFreq, Freq, TotFreq: cardinal);
    function    GetFreq (TotFreq: cardinal): cardinal;
    procedure   Decode  (CumFreq, Freq, TotFreq: cardinal);

  private
    procedure   ShiftLow;
    function    InputByte: byte;
    procedure   OutputByte (aValue: byte);

  private
    FStream: TStream;

    Range:  cardinal;
    Low:    cardinal;
    Code:   cardinal;
    Carry:  cardinal;
    Cache:  cardinal;
    FFNum:  cardinal;
  end;

implementation

(**************************************************************************
(* Class TRangeCoder
(**************************************************************************)

// Public routines ...

constructor TRangeCoder.Create (aStream: TStream);
begin
  inherited Create;
  FStream := aStream;
end;

procedure TRangeCoder.StartEncode;
begin
  Range := $FFFFFFFF;
  Low   := 0;
  FFNum := 0;
  Carry := 0;
end;

procedure TRangeCoder.StartDecode;
var
  I: Integer;
begin
  StartEncode;
  for I := 0 to NUM do
    Code := Code shl 8 + InputByte;
end;

procedure TRangeCoder.FinishEncode;
var
  I: Integer;
begin
  for I := 0 to NUM do ShiftLow;
end;

procedure TRangeCoder.FinishDecode;
begin
  /// Nothing to do...
end;

procedure TRangeCoder.Encode (CumFreq, Freq, TotFreq: cardinal);
var
  Tmp: cardinal;
begin
  Tmp   := Low;
  Low   := Low + MulDiv (Range, CumFreq, TotFreq);
  Carry := Carry + cardinal (Low < Tmp);
  Range := MulDiv (Range, Freq, TotFreq);
  while Range < TOP do
  begin
    Range := Range shl 8;
    ShiftLow;
  end;
end;

function TRangeCoder.GetFreq (TotFreq: cardinal): cardinal;
begin
  Result := MulDecDiv (Code + 1, TotFreq, Range);
end;

procedure TRangeCoder.Decode (CumFreq, Freq, TotFreq: cardinal);
begin
  Code  := Code - MulDiv (Range, CumFreq, TotFreq);
  Range := MulDiv (Range, Freq, TotFreq);
  while Range < TOP do
  begin
    Code := Code shl 8 + InputByte;
    Range := Range shl 8;
  end;
end;

// Private routines ...

procedure TRangeCoder.ShiftLow;
begin
  if (Low < Thres) or (Carry <> 0) then
  begin
    OutputByte (Cache + Carry);
    while FFNum <> 0 do
    begin
      OutputByte (Carry - 1);
      Dec (FFNum);
    end;
    Cache := Low shr 24;
    Carry := 0;
  end else
    Inc (FFNum);
  Low := Low shl 8;
end;

function TRangeCoder.InputByte: byte;
begin
  FStream.Read (Result, 1);
end;

procedure TRangeCoder.OutputByte (aValue: byte);
begin
  FStream.Write (aValue, 1);
end;

end.
