program Bee;

{ Contains:

  The data compression utility.

  Features:

  1. Uses context modelling and some variant of arithmetic encoding.
  2. Uses integer arithmetic only.
  3. Uses half-byte alphabet.

  (C) 1999-2007 Andrew Filinsky and Melchiorre Caruso.

  Modifyed:

  v0.7.8 build 0150 - 2005/06/27 by Melchiorre Caruso;
  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky;
  v0.7.8 build 0154 - 2005/07/23 by Melchiorre Caruso;
  v0.7.9 build 0298 - 2006/01/05 by Melchiorre Caruso;
  v0.7.9 build 0301 - 2007/01/23 by Andrew Filinsky.
}

{$I Compiler.inc} {*$APPTYPE CONSOLE}

uses
  Classes,
  Windows,
  SysUtils,
  Bee_Assembler in 'Bee_Assembler.pas',
  Bee_Common in 'Bee_Common.pas',
  Bee_App in 'Bee_App.pas',
  Bee_BlowFish in 'Bee_BlowFish.pas',
  Bee_RangeCoder in 'Bee_RangeCoder.pas',
  Bee_Codec in 'Bee_Codec.pas',
  Bee_Modeller in 'Bee_Modeller.pas',
  Bee_MainPacker in 'Bee_MainPacker.pas',
  Bee_Configuration in 'Bee_Configuration.pas',
  Bee_Crc in 'Bee_Crc.pas',
  Bee_Files in 'Bee_Files.pas',
  Bee_Headers in 'Bee_Headers.pas',
  Bee_Interface in 'Bee_Interface.pas';

type
  TConsole = class
  private
    App: TBeeApp;
    AppKey: string;
    AppInterface: TAppInterface;
    AppParams: TStringList;
    procedure OnOverWrite;
    procedure OnWarning;
    procedure OnDisplay;
    procedure OnRename;
    procedure OnError;
    procedure OnClear;
    procedure OnList;
    procedure OnTick;
    procedure OnKey;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute;
  end;

  /// implementation ///

  // TConsole

  constructor TConsole.Create;
  var
    I: integer;
  begin
    AppInterface := TAppInterface.Create;
    AppInterface.OnOverWrite := OnOverWrite;
    AppInterface.OnWarning := OnWarning;
    AppInterface.OnDisplay := OnDisplay;
    AppInterface.OnRename :=  OnRename;
    AppInterface.OnClear := OnClear;
    AppInterface.OnError := OnError;
    AppInterface.OnList := OnList;
    AppInterface.OnTick := OnTick;
    AppInterface.OnKey := OnKey;

    AppKey := '';
    AppParams := TStringList.Create;
    for I := 1 to ParamCount do AppParams.Add (ParamStr (I));
    App := TBeeApp.Create (AppInterface, AppParams);
  end;

  destructor TConsole.Destroy;
  begin
    AppInterface.Free;
    AppParams.Free;
    AppKey := '';
  end;

  procedure TConsole.Execute;
  begin
    App.Execute;
  end;

  procedure TConsole.OnOverWrite;
  begin
    Writeln;
    Writeln ('"' + ParamToOem (AppInterface.cFileName) + '" already exists.');
    Write ('Overwrite it?  [Yes/No/Rename/All/Skip/Quit]: ');
    Readln (AppInterface.cMsg);
    Writeln;
    // convert oem to param
    AppInterface.cMsg := UpperCase (OemToParam (AppInterface.cMsg));
  end;

  procedure TConsole.OnKey;
  begin
    if Length (AppKey) = 0 then
    begin
      Writeln;
      Write ('Insert a key (min length 4 char): ');
      Readln (AppKey);
      Writeln;
      // convert oem to param
      AppKey := OemToParam (AppKey);
    end;
    AppInterface.cMsg := AppKey;
  end;

  procedure TConsole.OnRename;
  begin
    Writeln;
    Write ('Rename file "' + ParamToOem (AppInterface.cFileName) + '" as (empty to skip):');
    Readln (AppInterface.cMsg);
    Writeln;
    // convert oem to param
    AppInterface.cMsg := OemToParam (AppInterface.cMsg);
  end;

  procedure TConsole.OnWarning;
  begin
    Writeln (ParamToOem (AppInterface.cMsg));
  end;

  procedure TConsole.OnDisplay;
  begin
    Writeln (ParamToOem (AppInterface.cMsg));
  end;

  procedure TConsole.OnError;
  begin
    Writeln (ParamToOem (AppInterface.cMsg));
  end;

  procedure TConsole.OnList;
  begin
    AppInterface.cList := nil;
  end;

  procedure TConsole.OnTick;
  begin
    // not convert oem to param
    Write (Format (#8#8#8#8 + '%d%%', [AppInterface.cPercentage]));
  end;

  procedure TConsole.OnClear;
  begin
    Write (#13'    '#13);
  end;

  /// main block ///

var
  Console: TConsole;

begin
  Console := TConsole.Create;
  Console.Execute;
  //Console.Free;
end.
