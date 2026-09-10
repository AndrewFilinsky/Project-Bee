Unit Bee_RangeCoder0;

  { Unit contains classes:
    -- TRangeCoder, range coder (based on Eugeny Shelwien's Shindlet (based on Shindler's rangecoder), MaxFreq = 2^24);
    Created: 
    -- Evgeny Shelwien, 2002 (?);
    Translated:
    -- Andrew Filinsky, Dec 2002;
  }
  {$R-,Q-,S-}

Interface

/// Uses units...

  Uses
    Classes;  /// TStream, ...

// Constants...

  Const
    Top     = 1 shl 24;
    MaxFreq = Top - 1;  /// Top - 1;

// Types...

  Type
    /// TRangeCoder...

    TRangeCoder = Class
      Constructor Create (aStream: TStream);

      Procedure   StartEncode;
      Procedure   StartDecode;
      Procedure   FinishEncode;
      Procedure   FinishDecode;
      Procedure   Encode (CumFreq, Freq, TotFreq: Cardinal);
      Function    GetFreq (TotFreq: Cardinal): Cardinal;
      Procedure   Decode (CumFreq, Freq, TotFreq: Cardinal);

    Private
      Procedure   ShiftLow;
      Procedure   OutTgtByte (Value: Byte);
      Function    InpSrcByte: Byte;

    Private
      Stream: TStream;

      Code, Range, FFNum, Cache: Cardinal;
      Low: Int64;
    End;

Implementation

/// TRangeCoder...

  Constructor TRangeCoder.Create (aStream: TStream);
  Begin
    Inherited Create;
    Stream := aStream;
  End;

  Procedure TRangeCoder.StartEncode;
  Begin
    Range := $FFFFFFFF;
    Low   := 0;
    FFNum := 0;
    Cache := 0;
  End;

  Procedure TRangeCoder.StartDecode;
    Var
      I: Cardinal;
  Begin
    Code := 0;
    Range := $FFFFFFFF;
    For I := 0 to 4 do Code := (Code shl 8) or InpSrcByte;
  End;

  Procedure TRangeCoder.FinishEncode;
    Var
      I: Cardinal;
  Begin
    For I := 0 to 4 do ShiftLow;
  End;

  Procedure TRangeCoder.FinishDecode;
  Begin
    /// Nothing to do...
  End;

  Procedure TRangeCoder.Encode (CumFreq, Freq, TotFreq: Cardinal);
  Begin
    Range := Range div TotFreq;
    Low   := Low + CumFreq * Range;
    Range := Range * Freq;
    While Range < Top do begin ShiftLow; Range := Range shl 8; end;
  End;

  Function TRangeCoder.GetFreq (TotFreq: Cardinal): Cardinal;
  Begin
    Range  := Range div TotFreq;
    Result := Code div Range;
  End;

  Procedure TRangeCoder.Decode (CumFreq, Freq, TotFreq: Cardinal);
  Begin
    Code  := Code - CumFreq * Range;
    Range := Range * Freq;
    While Range < Top do begin Code := (Code shl 8) or InpSrcByte; Range := Range shl 8; end;
  End;

  Procedure TRangeCoder.ShiftLow;
    Var
      C: Cardinal;
  Begin
    if ((Low xor $FF000000) > $FFFFFF) then begin
      OutTgtByte (Cache + Low shr 32);
      C := $FF + (Low shr 32);
      While FFNum <> 0 do begin OutTgtByte (C); dec (FFNum); end;
      Cache := Cardinal (Low) shr 24;
    end else begin
      inc (FFNum);
    end;
    Low := Cardinal (Low) shl 8;
  End;

  Procedure TRangeCoder.OutTgtByte (Value: Byte);
  Begin
    Stream.Write (Value, 1);
  End;

  Function TRangeCoder.InpSrcByte: Byte;
  Begin
    Stream.Read (Result, 1);
  End;

End.
