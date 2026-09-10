Unit Bee_RangeCoder1;

  { Unit contains classes:
    -- TRangeCoder, range coder (based on Eugeny Shelwien's shindler_var1 (based on Shindler's rangecoder), MaxFreq = 2^24 (?));
    Created:
    -- Evgeny Shelwien, Feb 2003.
    Translated:
    -- Andrew Filinsky, Mar 2003.
  }
  {$R-,Q-,S-}

Interface

/// Uses units...

  Uses
    Classes;  /// TStream, ...

// Constants...

  Const
    TOP     = 1 shl 24;
    NUM     = 4;
    Thres   = 255 * Cardinal (TOP);
    MaxFreq = TOP - 1; 

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

      Range:  Cardinal;
      Low:    Cardinal;  
      Code:   Cardinal;
      Carry:  Cardinal;
      Cache:  Cardinal;
      FFNum:  Cardinal;
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
    Carry := 0;    
  End;

  Procedure TRangeCoder.StartDecode;
    Var
      I: Integer;
  Begin
    StartEncode; 
    For I := 0 to NUM do code := code shl 8 + InpSrcByte; 
  End;

  Procedure TRangeCoder.FinishEncode;
    Var
      I: Integer;
  Begin
    For I := 0 to NUM do ShiftLow; 
  End;

  Procedure TRangeCoder.FinishDecode;
  Begin
    /// Nothing to do...
  End;

  Procedure TRangeCoder.Encode (cumFreq, freq, totFreq: Cardinal);
    Var
      tmp: Cardinal;
  Begin
    tmp   := low;
    range := range div totFreq;
    low   := low + cumFreq * range;
    Carry := Carry + Cardinal (low < tmp);
    range := range * freq;
    While Range < TOP do begin Range := Range shl 8; ShiftLow; end;
  End;

  Function  TRangeCoder.GetFreq (totFreq: Cardinal): Cardinal;
  Begin
    range  := range div totFreq;
    Result := code div range;
  End;

  Procedure TRangeCoder.Decode (CumFreq, Freq, TotFreq: Cardinal);
  Begin
    Code  := Code - CumFreq * Range;
    Range := Range * Freq;
    While Range < TOP do begin Code := Code shl 8 + InpSrcByte; Range := Range shl 8; end;
  End;

  Procedure TRangeCoder.ShiftLow;
  Begin
    If ((Low < Thres) or (Carry <> 0)) then begin
      OutTgtByte (Cache + Carry);
      While FFNum <> 0 do begin OutTgtByte (Carry - 1); Dec (FFNum); end;
      Cache := Low shr 24;
      Carry := 0;
    End else
      Inc (FFNum);
    Low := Low shl 8;
  End;

  Procedure  TRangeCoder.OutTgtByte (Value: Byte);
  Begin
    Stream.Write (Value, 1);
  End;

  Function  TRangeCoder.InpSrcByte: Byte;
  Begin
    Stream.Read (Result, 1);
  End;

End.
