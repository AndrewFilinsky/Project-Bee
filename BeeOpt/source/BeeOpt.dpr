program BeeOpt;

uses
  Forms,
  Bee_Assembler in '..\..\Bee\source\Bee_Assembler.pas',
  Bee_BlowFish in '..\..\Bee\source\Bee_BlowFish.pas',
  Bee_Codec in '..\..\Bee\source\Bee_Codec.pas',
  Bee_Common in '..\..\Bee\source\Bee_Common.pas',
  Bee_Configuration in '..\..\Bee\source\Bee_Configuration.pas',
  Bee_Files in '..\..\Bee\source\Bee_Files.pas',
  Bee_Headers in '..\..\Bee\source\Bee_Headers.pas',
  Bee_Modeller in '..\..\Bee\source\Bee_Modeller.pas',
  Bee_RangeCoder in '..\..\Bee\source\Bee_RangeCoder.pas',
  UFormMain in 'Forms\UFormMain.pas' {MainForm},
  UTrayIcon in 'Units\UTrayIcon.pas',
  UOptimizer in 'Units\UOptimizer.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm (TMainForm, MainForm);
  if MainForm.App <> nil then MainForm.App.Evolution;
  Application.Run;
end.
