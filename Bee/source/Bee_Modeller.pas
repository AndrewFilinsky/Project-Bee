unit Bee_Modeller;

{ Contains:

  TBaseCoder class, PPM modeller;

  (C) 1999-2005 Andrew Filinsky.

  Modifyed:

  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky.
  v0.7.9 build 0301 - 2007/01/23 by Andrew Filinsky.
  v0.7.9 build 0316 - 2007/02/16 by Andrew Filinsky.
}

{$I Compiler.inc}

interface

uses
  Math,                                 // Max (), Min (), ...
  Classes,                              // TStream
  Bee_Assembler,                        // Low-level routines ...
  Bee_Codec,                            // TSecondaryFCodec, ...
  Bee_Configuration,                    // TTable, TTableCol, ...
  Bee_Common;                           // Diag, ...

const
  BitChain  = 4;                        // Size of data portion, bit
  MaxSymbol = 1 shl BitChain - 1;       // Size of source alphabet, symbols
  Increment = 8;                        // Increment of symbol frequency
  Scale     = 128;                      // Scale of Escape coefficient, Escape = Increment * Count(Unique symbol) * q div Scale, where "q" is variable parameter to be selected in range [0..255].
  MaxFreq   = Bee_Codec.MaxFreq;        // Maximum Total Frequency of symbols before encoding.

type
  PNode = ^TNode;                       // Pointer to modeller's node information...
  PPNode = ^PNode;                      // Array of nodes...

  // Modeller's node information...

  TNode = record
    Next, Up: PNode;                    // Next node of this or high level
    A: cardinal;                        // Source address
    K: word;                            // Frequency of this symbol
    C: byte;                            // This symbol itself
    D: byte;                            // Used for incoming data storage
  end;

  /// PPM modeller...

  TBaseCoder = class (TObject)
  public
    constructor Create (aCodec: TSecondaryCodec);
    destructor Destroy; override;

    procedure SetTable (const T: TTableParameters);
    procedure SetDictionary (aDictionaryLevel: cardinal);
    procedure FreshFlexible;
    procedure FreshSolid;
    function  UpdateModel (aSymbol: cardinal): cardinal;

  private
    procedure Add (aSymbol: byte);
    function  Get (Address: cardinal): cardinal;
    function  CreateChild(Parent: PNode): PNode;
    procedure FreeChild (Node: PNode);
    procedure Account;
    function  Tail (Node: PNode; aSymbol: byte): PNode;
    procedure Step;

  private
    procedure ShiftBuffer;
    procedure ShiftNodes(P: PNode; Level: cardinal);

  private
    FDictionaryLevel: cardinal;
    FCodec: TSecondaryCodec;            // Secondary encoder or decoder...

    Symbol: cardinal;
    Pos: cardinal;                      // Position of the last written Symbol in the buffer.

    MaxCounter,                         // Maximal heap size
    SafeCounter,                        // Safe heap size
    Counter: cardinal;                  // Current heap size
    BufferShiftValue: cardinal;         // Size of shift to sliding input frame.
    CuttingLevel: cardinal;             // Current level of nodes cutting.
    R: cardinal;                        // Internal Range to Account frequencyes.

    Heap: array of TNode;
    Tear: PNode;
    Root: TNode;

    ListCount: cardinal;
    List: array [0..15] of PNode;

    Page: ^TTablePage;                  // Page of parameters Table...
    Table: TTable;                      // Parameters Table...
  end;

implementation

/// TBaseCoder...

constructor TBaseCoder.Create (aCodec: TSecondaryCodec);
begin
  FCodec := aCodec;
end;

destructor TBaseCoder.Destroy;
begin
  Heap := nil;
end;

// Expand from [0..FromRange] to [1..ToRange].
function ExpandRange(Value, FromRange, ToRange: cardinal): cardinal;
begin
  Result := Value + Round(IntPower(Power(Double(ToRange - FromRange), Double(1 / FromRange)), Value));
end;

procedure TBaseCoder.SetTable (const T: TTableParameters);
var
  P: PCardinal;
  aPage: ^TTablePage;
begin
  P := @Table; for var I := 0 to SizeOf(T) - 1 do P[I] := T[I];

  Table.Level := Table.Level and $F;

  for var I := 0 to 1 do
  begin
    aPage := @Table.Page[I];

    aPage.Escape[0] := aPage.Escape[0] * Increment; // Weight of the Escape symbol. Must be divided by Scale.

    for var J := 1 to 16 do
      aPage.Escape[J] := aPage.Escape[J] * Increment * J; // Weight of the Escape symbol. Must be divided by Scale.

    aPage.RecencyScaling      := aPage.RecencyScaling + 256; // Recency scaling of symbol, weight scaling factor for the last character is r' = (r + 256) / 256.
    aPage.FrequencyThreshold  := aPage.FrequencyThreshold * Increment * 4; // Frequency scaling threshold.
    aPage.InitialFrequency    := aPage.InitialFrequency + 1; // Initial Frequency of the new symbol.
    aPage.RangeThreshold      := ExpandRange(aPage.RangeThreshold, 255, MaxFreq);
  end;
end;

procedure TBaseCoder.SetDictionary (aDictionaryLevel: cardinal);
begin
  if aDictionaryLevel > 9 then aDictionaryLevel := 9;
  if (aDictionaryLevel = 0) or (FDictionaryLevel <> aDictionaryLevel) then
  begin
    FDictionaryLevel := aDictionaryLevel;
    MaxCounter :=  1024 * 3200 div SizeOf(TNode) shl FDictionaryLevel - 1;
    SafeCounter := MaxCounter - 64;
    Heap := nil;
    SetLength(Heap, MaxCounter + 1);
  end;
  FreshFlexible;
end;

procedure TBaseCoder.FreshFlexible;
var
  P: PNode;
begin
  // Clear and link the Heap ...
  P := @Heap[0];
  for var I := MaxCounter downto 0 do begin P.Next := P + 1; P.Up := nil; Inc(P); end;

  Tear := @Heap[0];
  Counter := 0;
  CuttingLevel := 24;
  ListCount := 0;
  Pos := 1; // Writing to the buffer starts at position 2. Position zero in the buffer is never used. Pity...

  Root.Next := nil;
  Root.Up := nil;
  Root.K := 0; // Does not matter.
  Root.C := 0;
  Root.A := Pos;
end;

procedure TBaseCoder.FreshSolid;
begin
  if Counter > 1 then
  begin
    ListCount := 1;
    List [0] := @Root;
  end else
    ListCount := 0;
end;

procedure TBaseCoder.Add (aSymbol: byte);
var
  P: PByte;
begin
  Inc (Pos);
  P := Addr(Heap [Pos shr 1].D);
  if not Odd(Pos) then
    P^ := P^ and $F0 or aSymbol
  else
    P^ := P^ and $0F or aSymbol shl 4;
end;

function TBaseCoder.Get (Address: cardinal): cardinal;
begin
  Result := Heap [Address shr 1].D;
  if not Odd(Address) then
    Result := Result and $0F
  else
    Result := Result shr 4;
end;

procedure TBaseCoder.FreeChild(Node: PNode);
begin
  var P := Node.Up;
  while P.Next <> nil do
    P := P.Next;
  P.Next := Tear;
  Tear := Node.Up;
  Node.Up := nil;
end;

function TBaseCoder.CreateChild(Parent: PNode): PNode;
begin
  Inc (Counter);

  Result := Tear;
  Tear := Result.Next;

  Result.Next := Parent.Up;
  Parent.Up := Result;
  Result.A := Parent.A + 1;
  Result.K := Page.InitialFrequency;
  Result.C := Get(Result.A);

  if Result.Up <> nil then
    FreeChild(Result);
end;

procedure AddAndShiftCardinal(const Data; Count, Value: Cardinal);
begin
  repeat
    Dec(Count);
    PCardinal(@Data)[Count] := (PCardinal(@Data)[Count] + Value) shr 8;
  until Count = 0;
end;

procedure TBaseCoder.Account;
var
  I, J, K: cardinal;
  P: PNode;
  Freq: array [0..MaxSymbol] of cardinal; // Symbol frequencyes...
begin
  // Prolog.
  FillChar(Freq, SizeOf(Freq), 0);
  R := Cardinal(MaxFreq - MaxSymbol - 1) shl 8;

  I := 0;
  if I < ListCount then
    repeat
      P := List [I];
      if P.Up <> nil then
      begin
        P := P.Up;
        if P.Next <> nil then
        begin
          // Undetermined context ...
          K := P.K * Page.RecencyScaling shr 8;
          P := P.Next;
          J := 1;
          repeat Inc(J); Inc(K, P.K); P := P.Next; until P = nil;
          J := Page.Escape[J] * (ListCount - I) div Scale; // weight of Escape
          J := R div (K + J); // factor.
          Dec(R, K * J);
          // Account:
          P := List[I].Up;
          Inc(Freq[P.C], P.K * Page.RecencyScaling shr 8 * J);
          P := P.Next;
          repeat Inc(Freq[P.C], P.K * J); P := P.Next; until P = nil;
        end else
        begin
          // Determined context ...
          J := Page.Escape[1] * (ListCount - I) div Scale; // weight of Escape
          J := R div (P.K + J); // factor.
          J := P.K * J; // weight of Symbol
          Inc(Freq[P.C], J);
          Dec(R, J);
        end;
      end else if P.A > 0 then
      begin
        // Determined context, encountered at first time ...
        P := CreateChild(P);
        J := Page.Escape[0] * (ListCount - I) div Scale; // weight of Escape
        J := R div (Increment + J); // factor.
        J := Increment * J; // weight of Symbol
        Inc(Freq[P.C], J);
        Dec(R, J);
      end;
      Inc (I);
    until I = ListCount;

  // Epilog. Update aSymbol...
  AddAndShiftCardinal(Freq, Length(Freq), R shr BitChain + 256);
  Symbol := FCodec.UpdateSymbol(@Freq, Symbol, Length(Freq));
  Add(Symbol);
end;

function TBaseCoder.Tail (Node: PNode; aSymbol: byte): PNode;
begin
  Node.A := Pos - 1;
  Result := Node.Up;

  if Result = nil then
    // Nothing to do.
  else if Result.C = aSymbol then
    // Nothing to do.
  else
    repeat
      var P := Result; Result := Result.Next;
      if Result = nil then
      begin
        CreateChild (Node);
        Break;
      end else if Result.C = aSymbol then
      begin
        P.Next := Result.Next; Result.Next := Node.Up; Node.Up := Result;
        Break;
      end;
    until False;
end;

procedure UpdateFrequency (P: PNode; const Threshold: cardinal);
begin
  Inc(P.K, Increment);
  if P.K > Threshold then
    repeat
      P.K := P.K shr 1;
      P := P.Next;
    until P = nil;
end;

procedure TBaseCoder.Step;
var
  I, J: cardinal;
  P: PNode;
  Done: boolean;
begin
  // Calculate probabilities.
  Account;

  if ListCount = 0 then
    Exit; // Nothing to do, so finish it.

  // Update Tree:
  I := 0; J := 0; Done := false;
  repeat
    P := Tail (List [I], Symbol);
    if P <> nil then
    begin
      if not Done then
      begin
        UpdateFrequency (P, Page.FrequencyThreshold);
        if (P.Up <> nil) and (J > 1) then
          Done := true;
      end;
      List [J] := P; Inc (J);
    end;
    Inc (I);
  until I = ListCount;
  ListCount := J;
end;

function TBaseCoder.UpdateModel (aSymbol: cardinal): cardinal;
begin
  Page := @Table.Page[0]; Symbol := aSymbol shr $4; Step; Result := Symbol shl 4;
  Page := @Table.Page[1]; Symbol := aSymbol and $F; Step; Result := Result + Symbol;

  // Shift buffer and reduce tree...
  while (Pos > MaxCounter shl 1) or (Counter > SafeCounter) do
    ShiftBuffer;

  // Update NodeList...
  if not (ListCount > Table.Level) then
    Inc (ListCount)
  else if R > Page.RangeThreshold then
    Move (List[1], List[0], SizeOf(PNode) * (ListCount - 1));
  List [ListCount - 1] := @Root;
end;

{ Helper functions }

function CountNodes(P: PNode): cardinal;
begin
  Result := 0;
  repeat
    Inc(Result);
    if P.Up <> nil then Inc(Result, CountNodes(P.Up));
    P := P.Next;
  until P = nil;
end;

{ Cutting Tree functions }

procedure TBaseCoder.ShiftBuffer;
var
  Shift: cardinal;
  PercentBuffer: cardinal;
  PercentNodes: cardinal;
  LocalCuttingLevel: cardinal;
begin
  // {$IFDEF CONSOLE} Write(#13 + 'Shift buffer ... '); {$ENDIF}

  if Pos > MaxCounter shl 1 then LocalCuttingLevel := 128 else LocalCuttingLevel := CuttingLevel;

  Shift := Pos div 16 shl 1;
  BufferShiftValue := Shift;

  for var I := 0 to Pos shr 1 - Shift shr 1 do
    Heap[I].D := Heap[I + Shift shr 1].D;
  Dec(Pos, Shift);

  // {$IFDEF CONSOLE} Write('Cut nodes ... '); {$ENDIF}

  Counter := 0;
  ShiftNodes (@Root, LocalCuttingLevel);
  ListCount := 0;

  PercentBuffer := MulDiv(Pos, 100, MaxCounter shl 1);
  PercentNodes  := MulDiv(Counter, 100, SafeCounter);

  // {$IFDEF CONSOLE} Writeln('Buffer ', PercentBuffer, '%, Nodes ', PercentNodes, '%, Level ', CuttingLevel); {$ENDIF}

  if (PercentNodes < 75) or (CuttingLevel < LocalCuttingLevel) then Inc(CuttingLevel) else Dec(CuttingLevel);
  if CuttingLevel > 128 then Dec(CuttingLevel);
  if CuttingLevel < 1 then Inc(CuttingLevel);
end;

procedure TBaseCoder.ShiftNodes(P: PNode; Level: cardinal);
begin
  repeat
    Inc(Counter);
    if P.A > BufferShiftValue then P.A := P.A - BufferShiftValue else P.A := 0;
    if P.Up <> nil then
      if (Level > 0) and (P.A > 0) then
        ShiftNodes(P.Up, Level - 1)
      else
        FreeChild(P);
    P := P.Next;
  until P = nil;
end;

end.
