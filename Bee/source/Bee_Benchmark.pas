unit Bee_Benchmark;

{ When this unit is included in the project,
  when the compiled application is launched, the benchmark is automatically launched.

  (C) 2022, Anfrew Filinsky.
}

interface

{$I Compiler.inc}
{$POINTERMATH ON}

uses
  System.SysUtils,
  System.DateUtils,
  Bee_Assembler;

procedure Benchmark_234786283746;

implementation

const
  Cr = #13#10;

procedure Benchmark_234786283746;
var
  T: Array of cardinal;
  I: Integer;
  TimeStart: TDateTime;
begin
  Write(Cr, 'Benchmark_234786283746 started... ');
  TimeStart := System.SysUtils.Now;

  SetLength(T, 1 shl 24);
  for i := 1 to 1 shl 24 do
    Move(T[Random(Length(T) - 32)], T[Random(Length(T) - 32)], 31 * 4);

  Writeln(Format('%0.3f sec.', [MillisecondsBetween(TimeStart, System.SysUtils.Now)/1000]));
end;

begin
  Benchmark_234786283746;
end.
