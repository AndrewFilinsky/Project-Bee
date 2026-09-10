unit Bee_Assembler;

{$I Compiler.inc}

interface

procedure FillCardinal(const Data; Count, Value: Cardinal);
procedure AddCardinal(const Data; Count, Value: Cardinal); // inline;
procedure ClearCardinal(var Data; Count: Cardinal); // inline;
procedure MoveCardinal(const Source; var Dest; Count: Cardinal); // inline;

function  MulDiv (A, B, C: Cardinal): Cardinal;
function  MulDecDiv (A, B, C: Cardinal): Cardinal;

implementation

procedure FillCardinal(const Data; Count, Value: Cardinal);
begin
  repeat
    Dec(Count);
    PCardinal(@Data)[Count] := Value;
  until Count = 0;
end;

procedure AddCardinal(const Data; Count, Value: Cardinal);
begin
  repeat
    Dec(Count);
    PCardinal(@Data)[Count] := PCardinal(@Data)[Count] + Value;
  until Count = 0;
end;

procedure ClearCardinal(var Data; Count: Cardinal);
begin
  FillChar(Data, Count * SizeOf(Cardinal), 0);
end;

procedure MoveCardinal(const Source; var Dest; Count: Cardinal);
begin
  Move(Source, Dest, Count * SizeOf(Cardinal));
end;

{$if not defined(CPUX64)}

function MulDiv (A, B, C: Cardinal): Cardinal;
asm
  mul  B
  div  C
end;

function MulDecDiv (A, B, C: Cardinal): Cardinal;
asm
  mul  B
  sub  eax, 1
  sbb  edx, 0
  div  C
end;

{$else}

function MulDiv (A, B, C: Cardinal): Cardinal;
begin
  Result := UInt64(A) * B div C;
end;

function MulDecDiv (A, B, C: Cardinal): Cardinal;
begin
  Result := (UInt64(A) * B - 1) div C;
end;

{$endif}

end.
