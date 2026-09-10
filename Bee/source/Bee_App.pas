unit Bee_App;

{ Contains:

  Bee archiver shell.

  (C) 2003-2006 Andrew Filinsky and Melchiorre Caruso.

  Modifyed:

  v0.7.8 build 0150 - 2005/06/27 by Melchiorre Caruso;
  v0.7.8 build 0153 - 2005/07/08 by Andrew Filinsky;
  v0.7.8 build 0154 - 2005/07/23 by Melchiorre Caruso;
  v0.7.9 build 0298 - 2006/01/05 by Melchiorre Caruso;
  v0.7.9 build 0301 - 2007/01/23 by Andrew Filinsky;
  
  v0.7.9 build 0316 - 2007/02/16 by Andrew Filinsky.
}

{$I Compiler.inc}

interface

uses
  Math,          // Max (), Min (), ...
  Windows,
  Classes,       // TStringList, ...
  SysUtils,      // faReadOnly, ...

  Bee_Files,
  Bee_Codec,
  Bee_Common,                   // Various helper routines
  Bee_Headers,
  Bee_Interface,
  Bee_MainPacker,               // TEncoder...
  Bee_Configuration;            // TConfiguration, TTable

type
  TBeeApp = class (TApp)
  public
    constructor Create (aAppInterface: TAppInterface; aParams: TStringList);
    destructor  Destroy; override;
    procedure   Execute; override;
  private
    function    OpenArchive (Headers: THeaders; Default: THeaderAction):boolean;

    procedure   ProcessOptions;
    procedure   ProcessFileMasks;

    function    ProcessFilesToSwap (Headers: THeaders): boolean; // decode solid sequences using a swapfile
    procedure   ProcessFilesToFresh (Headers: THeaders); // find and prepare sequences
    procedure   ProcessFilesToDelete (Headers: THeaders); // find and prepare sequences
    procedure   ProcessFilesDeleted (Headers: THeaders);
    procedure   ProcessFilesToDecode (Headers: THeaders; Action : THeaderAction);
    procedure   ProcessFilesToExtract (Headers: THeaders);
    procedure   ProcessFilesToOverWrite (Headers: THeaders);
    /// OverWrite sub-routines
    procedure   ProcessFilesToOverWriteDefault (Headers: THeaders);
    procedure   ProcessFilesToOverWriteAdvanced (Headers: THeaders);
    procedure   ProcessFileToOverWrite (Headers: THeaders; FileIndex: integer);
    function    AlreadyFileExists (Headers: THeaders; FileIndex: integer; const FileName: string): integer;
    ///
    procedure   ProcesstOption;
    ///
    procedure   DisplayUsage;
    procedure   EncodeShell;
    procedure   DecodeShell (Action: THeaderAction);
    procedure   RenameShell;
    procedure   DeleteShell;
    procedure   ListShell;
    ///
    function    MethodToStr (P: THeader; Method, Dictionary: integer): string;
    function    SizeToStr (Size: integer): string;
    function    RatioToStr (PackedSize, Size: integer): string;
    function    AttrToStr (Attr: integer): string;
    function    VersionToStr (VersionId: cardinal): string;
    procedure   MySynchronize (AMethod: TThreadMethod);
  private
    SelfName:   string;

    ArcName:    string; // archive file name
    ArcFile:    TStream;
    SwapName:   string; // swap file name
    SwapFile:   TStream;

    CfgName:    string;
    Cfg:        TConfiguration;

    Command:    char; // command
    aOption:    string;
    cOption:    string;
    eOption:    string; // forced file extension
    fOption:    boolean;
    kOption:    boolean;
    oOption:    char;
    rOption:    boolean;
    sOption:    boolean;
    tOption:    boolean;
    uOption:    boolean;
    xOption:    TStringList;
    yOption:    string;

    FileMasks:  TStringList; // file masks
    Percentes:  TPercentes; // global process percentage
  end;

implementation

/// TBeeApp ...

  constructor TBeeApp.Create;
  begin
    inherited Create (aAppInterface, aParams);
    Randomize; // randomize, uses for unique filename generation...

    SelfName :=
      Cr + 'The Bee 1.0.36 archiver utility, freeware version, 10 Sep 2026.' +
      Cr + '(C) 1999-2007, 2009, 2022, 2025, 2026 Andrew Filinsky.';

    ArcName  :=  '';
    ArcFile  := nil;
    SwapName :=  '';
    SwapFile := nil;

    CfgName := SelfPath + 'Bee.ini';
    Cfg := TConfiguration.Create;

    Command := ' ';
    aOption :=  '';
    cOption :=  '';
    eOption :=  ''; // forced file extension
    fOption := False;
    kOption := False;
    oOption := 'Y';
    rOption := False;
    sOption := False;
    tOption := False;
    uOption := False;
    xOption := TStringList.Create;
    yOption := '';

    FileMasks := TStringList.Create;
    Percentes := TPercentes.Create (MySynchronize, AppInterface); // create global percentes

    ProcessOptions; // process options
  end;

  destructor TBeeApp.Destroy;
  begin
    Cfg.Free;
    xOption.Free;
    FileMasks.Free;
    Percentes.Free;
  end;

  procedure TBeeApp.DisplayUsage;
  begin
    AppInterface.cMsg := (Cr + 'Usage:' + Cr + Cr + '  Bee <Command> -<Option 1> -<Option N> <ArchiveName> <FileNames...>'); Synchronize (AppInterface.OnDisplay);

    AppInterface.cMsg := (Cr + 'Commands:' + Cr); Synchronize (AppInterface.OnDisplay);

    AppInterface.cMsg := ('  a   Add files to archive'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  d   Delete files from archive'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  e   Extract files from archive'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  x   eXtract files from archive with path name'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  l   List archive'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  t   Test archive files'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  r   Rename files in archive'); Synchronize (AppInterface.OnDisplay);

    AppInterface.cMsg := (Cr + 'Options:' + Cr); Synchronize (AppInterface.OnDisplay);

    AppInterface.cMsg := ('  r       Recurse subdirectories'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  u       Update files'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  f       Freshen files'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  e       force file Extention'); Synchronize ( AppInterface.OnDisplay);
    AppInterface.cMsg := ('  s       create Solid archive'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  a       add self-extrActor module'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  o<M>    set overwrite file Mode (Q-Query (default), A-All, S-Skip all)'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  m<0..3> set compression Method (0-store...1-default...3-maximal)'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  d<0..9> set Dictionary size (d1 uses < 5M, d2 (default) < 10M, d3 < 20M...)' + Cr); Synchronize (AppInterface.OnDisplay);

    AppInterface.cMsg := ('  x       eXclude filenames'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  t       Test archive after process'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  y       set temporary directory'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  k       use blowfish crypter/decrypter (min key-length 4 bytes)'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  c<DIR>  insert (with ''a'' cmd) or delete (with ''x'' cmd) part of file path'); Synchronize (AppInterface.OnDisplay);
    AppInterface.cMsg := ('  pri<P>  set process Priority (0-Idle, 1-Normal, 2-High, 3-RealTime)' + Cr); Synchronize (AppInterface.OnDisplay);

    AppInterface.cMsg := ('Use BeeOpt to make most optimal parameters.'); Synchronize (AppInterface.OnDisplay);
  end;

  procedure TBeeApp.Execute;
  const
    SetOfCommands = ['A', 'D', 'E', 'L', 'R', 'T', 'X'];
  begin
    AppInterface.cMsg := SelfName;
    Synchronize (AppInterface.OnDisplay);

    /// process command
    if ((Command in SetOfCommands) and (ArcName > '')) or (Command = '?') then 
      case Command of
        'A': EncodeShell;
        'D': DeleteShell;
        'E': DecodeShell (toExtract);
        'L': ListShell;
        'R': RenameShell;
        'T': DecodeShell (toTest);
        'X': DecodeShell (toExtract);
        '?': DisplayUsage;
      end
    else DisplayUsage;  
  end;

  function TBeeApp.OpenArchive;
  begin
    Result := True;

    if FileExists (ArcName) then
      try
        ArcFile := TFileReader.Create (ArcName, fmOpenRead + fmShareDenyWrite);
        Headers.ReadItems (ArcFile, Default);

        if Headers.Count = 0 then
        begin
          AppInterface.cMsg := ('Warning: archive is empty or damaged');
          Synchronize (AppInterface.OnWarning);
        end;

      except
        AppInterface.cMsg := ('Error: can''t open archive');
        Synchronize (AppInterface.OnError);

        Result := False;
      end;

  end;

/// Options processing

  procedure TBeeApp.ProcessOptions;
  var
    I: integer;
    S: string;
  begin
    // default configuration
    Cfg.Selector ('\main');
    Cfg.CurrentSection.Values ['Method'] := '1';
    Cfg.CurrentSection.Values ['Dictionary'] := '2';

    // process configuration
    if not FileExists (CfgName) then
    begin
      AppInterface.cMsg := (Cr + 'Configuration file ' + CfgName + ' not found, using default settings' + Cr);
      Synchronize (AppInterface.OnWarning);
    end else
      Cfg.LoadFromFile (CfgName);

    // catch options, command, archive name and name of files
    for I := 0 to AppParams.Count - 1 do
    begin
      S := AppParams.Strings [I];
      if (Length (S) > 1) and (S [1] = '-') then
        // options...
        case UpCase (S [2]) of
          'S': sOption := True;
          'U': uOption := True;
          'F': fOption := True;
          'T': tOption := True;
          'R':
            begin
              Delete (S, 1, 2);
              if (S = '+') or (Length (S) = 0) then
                rOption := True
              else
                if (S = '-') then
                  rOption := False;
            end;
          'K':
            begin
              Delete (S, 1, 2);
              kOption := True;
            end;
          'Y':
            begin
              Delete (S, 1, 2);
              yOption := ExcludeTrailingBackslash (S);
            end;
          'A':
            begin
              Delete (S, 1, 2);
              if (S = '+') or (Length (S) = 0) then
                aOption := 'BeeSfx.bin'
              else
                if (S = '-') then
                  aOption := 'BeeSfx.empty'
                else
                  aOption := S
            end;
          'M':
            begin
              Delete (S, 1, 2);
              Cfg.Selector ('\main');
              Cfg.CurrentSection.Values ['Method'] := IntToStr (Max (0, Min (StrToInt (S), 3)));
            end;
          'O':
            begin
              Delete (S, 1, 2);
              if (Length (S) = 1) and (UpCase (S [1]) in ['A','S','Q']) then oOption := UpCase (S [1]);
            end;
          'D':
            begin
              Delete (S, 1, 2);
              Cfg.Selector ('\main');
              Cfg.CurrentSection.Values ['Dictionary'] := IntToStr (Max (0, Min (StrToInt (S), 9)));
            end;
          'E':
            begin
              Delete (S, 1, 2);
              if not (ExtractFileExt ('.' + S) = '.') then
                eOption := ExtractFileExt ('.' + S);
            end;
          'X':
            begin
              Delete (S, 1, 2);
              xOption.Add (S);
            end;
          'C':
            begin
              Delete (S, 1, 2);
              cOption := IncludeDelimiter (DeleteFileDrive (S));
            end;
          else
            if PosText ('-PRI', S) = 1 then
            begin
              Delete (S, 1, 4);
              if (Length (S) = 1) and (S [1] in ['0'.. '3']) then
                {$IFDEF CONSOLE}
                Bee_Common.SetPriority (StrToInt (S [1]));
                {$ELSE}
                Self.SetPriority (StrToInt (S [1]));
                {$ENDIF}
            end;
        end
      else
        // command or filenames...
        if Command = ' ' then
        begin
          if Length (S) = 1 then
            Command := UpCase (S [1])
          else
            Command := '?';
        end else
          if ArcName = '' then
          begin
            ArcName := S;
            if ExtractFileExt (ArcName) = '' then
              ArcName := ChangeFileExt (ArcName, '.bee');
          end else
            FileMasks.Add (S);
    end; // end for loop

    ProcessFileMasks;
  end;

/// File masks processing

  procedure TBeeApp.ProcessFileMasks;
  var
    I: integer;
  begin
    if rOption then
    begin
      for I := 0 to FileMasks.Count - 1 do
        if (not DirectoryExists (FileMasks [I])) and (not (Pos (RecursiveSign, FileMasks [I]) = Length (ExtractFilePath (FileMasks [I])) - 1)) then
          FileMasks [I] := ExtractFilePath (FileMasks [I]) + RecursiveSign + ExtractFileName (FileMasks [I]);

      for I := 0 to xOption.Count - 1 do
        if (not DirectoryExists (xOption [I])) and (not (Pos (RecursiveSign, xOption [I]) = Length (ExtractFilePath (xOption [I])) - 1)) then
          xOption [I] := ExtractFilePath (xOption [I]) + RecursiveSign + ExtractFileName (xOption [I]);
    end;
    {$IFDEF CONSOLE} if (FileMasks.Count = 0) then FileMasks.Add (RecursiveSign + '*.*'); {$ENDIF}
  end;

  procedure TBeeApp.ProcessFilesToExtract;
  var I: integer;
  begin
    if Command = 'E' then
    begin
      for I := 0 to Headers.Count - 1 do
        with THeader (Headers.Items [I]) do
          Name := ExtractFileName (Name)
    end else
      if Length (cOption) > 0 then
      begin
        for I := 0 to Headers.Count - 1 do
          with THeader (Headers.Items [I]) do
            Name := DeleteText (cOption, Name);
      end;
  end;

/// OvewWrite file processing

  procedure TBeeApp.ProcessFilesToOverWrite;
  begin
    if (uOption = False) and (fOption = False) then
      ProcessFilesToOverWriteDefault (Headers)
    else
      ProcessFilesToOverWriteAdvanced (Headers);
  end;

  // ProcessOverWrite sub-routines

  procedure TBeeApp.ProcessFilesToOverWriteDefault (Headers: THeaders);
  var
    I, J: integer;
    NewFileName: string;
  begin
    I := 0;
    while I < Headers.Count do
    begin
      if (THeader (Headers.Items [I]).Action = toExtract) and
         (  (FileExists (THeader (Headers.Items [I]).Name) = True) or
            (AlreadyFileExists (Headers, I, THeader (Headers.Items [I]).Name) > - 1)  ) then
      begin
        if (oOption in ['A','Q','S']) = False then
        begin
          repeat
            AppInterface.cFileName := THeader (Headers.Items [I]).Name;
            AppInterface.cFileSize := THeader (Headers.Items [I]).Size;
            AppInterface.cFileTime := THeader (Headers.Items [I]).Time;
            AppInterface.cMsg      := 'A';

            Synchronize (AppInterface.OnOverWrite);
          until (Length (AppInterface.cMsg) = 1) and (AppInterface.cMsg [1] in ['A','N','R','S','Q','Y']);

          oOption := AppInterface.cMsg [1];
        end;

        case UpCase (oOption) of
          'A': Break;
          'N': THeader (Headers.Items [I]).Action := toNone;
          'R': begin
                 while True do
                 begin
                   AppInterface.cFileName := THeader (Headers.Items [I]).Name;
                   AppInterface.cFileSize := THeader (Headers.Items [I]).Size;
                   AppInterface.cFileTime := THeader (Headers.Items [I]).Time;
                   AppInterface.cMsg      := '';

                   Synchronize (AppInterface.OnRename);

                   NewFileName := DeleteFileDrive (FixFileName (AppInterface.cMsg));
                   if (FileExists (NewFileName) = True) or (AlreadyFileExists (Headers, I, NewFileName) > -1) then
                   begin
                     AppInterface.cMsg := ('File "' + NewFileName + '" already exists!');
                     Synchronize (AppInterface.OnWarning);
                   end else
                     Break;
                 end; 

                 if Length (NewFileName) = 0 then
                   THeader (Headers.Items [I]).Action := toNone
                 else
                   THeader (Headers.Items [I]).Name := NewFileName;
               end;

          'S': for J := I to Headers.Count -1 do
               begin
                 THeader (Headers.Items [J]).Action := toNone;
                 I := J;
               end;

          'Q': for J := 0 to Headers.Count -1 do
               begin
                 THeader (Headers.Items [J]).Action := toNone;
                 I := J;
               end;
        end;
      end;
      Inc (I);
    end;

    /// 

    for I := 0 to Headers.Count - 1 do
      if (THeader (Headers.Items [I]).Action = toExtract) then
      begin
        J := Headers.GetBack (I - 1, toExtract, THeader (Headers.Items [I]).Name);

        if J > -1 then
          THeader (Headers.Items [J]).Action := toNone;
      end;
  end;

  procedure TBeeApp.ProcessFilesToOverWriteAdvanced (Headers: THeaders);
  var
    I: integer;
  begin
    if (uOption xor fOption) then
    begin
      
      if uOption then
      begin
        for I := 0 to Headers.Count - 1 do
          if (THeader (Headers.Items [I]).Action = toExtract)  then
          begin
            if (FileExists (THeader (Headers.Items [I]).Name) = True) then
              THeader (Headers.Items [I]).Action := toNone
            else
              ProcessFileToOverWrite (Headers, I);
          end;
      end else
        for I := 0 to Headers.Count - 1 do
          if (THeader (Headers.Items [I]).Action = toExtract) then
          begin
            if (FileExists (THeader (Headers.Items [I]).Name) = False) then
              THeader (Headers.Items [I]).Action := toNone
            else
            begin
              if FileAge (THeader (Headers.Items [I]).Name) >= THeader (Headers.Items [I]).Time then
                THeader (Headers.Items [I]).Action := toNone
              else
                ProcessFileToOverWrite (Headers, I);
            end;
          end;

    end else

      if (uOption and fOption) then
      begin
        for I := 0 to Headers.Count - 1 do
          if FileExists (THeader (Headers.Items [I]).Name) = True then
          begin
            if FileAge (THeader (Headers.Items [I]).Name) >= THeader (Headers.Items [I]).Time then
              THeader (Headers.Items [I]).Action := toNone
            else
              ProcessFileToOverWrite (Headers, I);
          end else
            ProcessFileToOverWrite (Headers, I);
      end;

  end;

  function TBeeApp.AlreadyFileExists (Headers: THeaders; FileIndex: integer; const FileName: string): integer;
  begin
    if Length (FileName) = 0 then
      Result := -1
    else
      Result := Headers.GetBack (FileIndex - 1, toExtract, FileName);
  end;

  procedure TBeeApp.ProcessFileToOverWrite (Headers: THeaders; FileIndex: integer);
  var
    J: integer;
  begin
    J := Headers.GetBack (FileIndex - 1, toExtract, THeader (Headers.Items [FileIndex]).Name);

    if J > - 1 then
    begin
      if (THeader (Headers.Items [FileIndex]).Time > THeader (Headers.Items [J]).Time) then
        THeader (Headers.Items [J]).Action := toNone
      else
        THeader (Headers.Items [FileIndex]).Action := toNone;
    end;
  end;

/// Sequences processing

  procedure TBeeApp.ProcessFilesToFresh;
  var
    I, J, BackTear, NextTear: integer;
  begin
    I := Headers.GetBack (Headers.Count - 1, toFresh);
    while I > -1 do // find sequences and mark as toSwap files that not toFresh
    begin
      BackTear := Headers.GetBack (I, foTear);
      NextTear := Headers.GetNext (I + 1, foTear);
      if NextTear = -1 then NextTear := Headers.Count;

      if ((NextTear - BackTear) > 1) then // if is solid header
      begin
        NextTear := Headers.GetBack (NextTear - 1, toCopy);
        for J := BackTear to NextTear do
          case THeader (Headers.Items [J]).Action of
            toCopy   : begin
                         THeader (Headers.Items [J]).Action := toSwap;
                         Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size * 2); // decoding  and Encoding size
                       end;
            toFresh  : Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size); // decoding size
          end;
        I := BackTear;
      end;
      I := Headers.GetBack (I - 1, toFresh);
    end;
    Inc (Percentes.GeneralSize, Headers.GetPackedSize (toCopy));
  end;

  procedure TBeeApp.ProcessFilesToDelete;
  var
    I, J, BackTear, NextTear: integer;
  begin
    I := Headers.GetBack (Headers.Count - 1, toDelete);
    while I > -1 do // find sequences and ...
    begin
      BackTear := Headers.GetBack (I, foTear);
      NextTear := Headers.GetNext (I + 1, foTear);
      if NextTear = -1 then NextTear := Headers.Count;

      if ((NextTear - BackTear) > 1) then // if is solid header
      begin
        NextTear := Headers.GetBack (NextTear - 1, toCopy);
        if Headers.GetBack (NextTear , toDelete) > (BackTear - 1) then // if exists an header toDelete
          for J := BackTear to NextTear do
            case THeader (Headers.Items [J]).Action of
              toCopy:   begin
                          THeader (Headers.Items [J]).Action := toSwap;
                          Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size * 2);
                        end;
              toDelete: Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size);
            end;
        I := BackTear;
      end;
      I := Headers.GetBack (I - 1, toDelete);
    end;
    Inc (Percentes.GeneralSize, Headers.GetPackedSize (toCopy));
  end;

  function TBeeApp.ProcessFilesToSwap;
    var
      I, J: integer;
      Decoder: TDecoder;
      iDictionary, iTable, iTear: integer;
      CurrDictionary, CurrTable: integer;
  begin
    Result := True;
    I := Headers.GetBack (Headers.Count - 1, toSwap);
    if I > - 1 then
    begin
      SwapName := GenerateFileName (yOption);
      SwapFile := TFileWriter.Create (SwapName, fmCreate);

      CurrDictionary := Headers.Count;
      CurrTable      := Headers.Count;

      Decoder := TDecoder.Create (ArcFile, Percentes);    // get GeneralSize
      while I > - 1 do
      begin
        iDictionary := Headers.GetBack (I, foDictionary); // find dictionary info
        iTable      := Headers.GetBack (I, foTable);      // find table info
        iTear       := Headers.GetBack (I, foTear);       // find tear info

        if (iDictionary > -1) and (iDictionary <> CurrDictionary) and (iDictionary <> iTear) then
        begin
          CurrDictionary := iDictionary;
          Decoder.DecodeStrm (THeader (Headers.Items [iDictionary]), pmQuit, SwapFile);
        end;

        if (iTable > -1) and (iTable <> CurrTable) and (iTable <> iTear) then
        begin
          CurrTable := iTable;
          Decoder.DecodeStrm (THeader (Headers.Items [iTable]), pmQuit, SwapFile);
        end;

        for J := iTear to I do
        begin
          if THeader (Headers.Items [J]).Action = toSwap then
            Result := Decoder.DecodeStrm (Headers.Items [J], pmNorm, SwapFile)
          else
            Result := Decoder.DecodeStrm (Headers.Items [J], pmSkip, SwapFile);
          
          if Result = False then Break;
        end;
        if Result = False then Break;

        I := Headers.GetBack (iTear - 1, toSwap);
      end;
      Decoder.Destroy;
      FreeAndNil (SwapFile);
    end;
  end;
                                                                                         
  procedure TBeeApp.ProcessFilesDeleted;
  var
    I: integer;
  begin
    with Headers do // rescue header informatios
      for I := 0 to Count - 2 do
        if THeader (Items [I]).Action = toDelete then
        begin
          if (foVersion in THeader (Items [I]).Flags) and (not (foVersion in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foVersion);
            THeader (Items [I + 1]).Version := THeader (Items [I]).Version;
          end;

          if (foMethod in THeader (Items [I]).Flags) and (not (foMethod in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foMethod);
            THeader (Items [I + 1]).Method := THeader (Items [I]).Method;
          end;

          if (foDictionary in THeader (Items [I]).Flags) and (not (foDictionary in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foDictionary);
            THeader (Items [I + 1]).Dictionary := THeader (Items [I]).Dictionary;
          end;

          if (foTable in THeader (Items [I]).Flags) and (not (foTable in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foTable);
            THeader (Items [I + 1]).Table := THeader (Items [I]).Table;
          end;

          if (foTear in THeader (Items [I]).Flags) and (not (foTear in THeader (Items [I + 1]).Flags)) then
          begin
            Include (THeader (Items [I + 1]).Flags, foTear);
          end;
        end;
  end;

  procedure TBeeApp.ProcessFilesToDecode;
  var
    I, J: integer;
    iDictionary, iTable, iTear: integer;
  begin
    I := Headers.GetBack (Headers.Count - 1, Action);   // last header
    while I > -1 do
    begin
      iDictionary := Headers.GetBack (I, foDictionary); // find dictionary info
      iTable      := Headers.GetBack (I, foTable);      // find table info
      iTear       := Headers.GetBack (I, foTear);       // find tear info

      for J := iTear to (I - 1) do
        if THeader (Headers.Items [J]).Action in [toNone, toQuit] then 
        begin
          THeader (Headers.Items [J]).Action := toSkip;
          Inc (Percentes.GeneralSize, THeader (Headers.Items [J]).Size);
        end;

      if (iDictionary > -1) and (THeader (Headers.Items [iDictionary]).Action = toNone) then THeader (Headers.Items [iDictionary]).Action := toQuit;
      if (iTable      > -1) and (THeader (Headers.Items [iTable     ]).Action = toNone) then THeader (Headers.Items [iTable     ]).Action := toQuit;

      I := Headers.GetBack  (iTear - 1, Action); 
    end;
  end;

/// Option processing

  procedure TBeeApp.ProcesstOption;
  begin
    if tOption then
    begin
      xOption.Clear; // clear xOption

      FileMasks.Clear; // clear FileMasks
      FileMasks.Add (RecursiveSign + '*.*');

      Percentes.GeneralSize := 0;
      Percentes.RemainSize  := 0;

      DecodeShell (toTest);
    end;
  end;
  
/// Shell procedures

  procedure TBeeApp.EncodeShell;
  var
    I: integer;
    Encoder: TEncoder;
    TmpFileName: string;
    TmpFile: TFileWriter;
    Headers: THeaders;
    Time: double;
  begin
    Headers := THeaders.Create;

    AppInterface.cMsg := (Cr + msgOpening + 'archive ' + ArcName);
    Synchronize (AppInterface.OnDisplay);

    if OpenArchive (Headers, toCopy) then
    begin
      Headers.cOption := cOption;
      Headers.fOption := fOption;
      Headers.uOption := uOption;
      Headers.xOption := xOption;

      // [AF] deleted at 2023-03-09
      (*
      AppInterface.cMsg := (msgScanning + '...');
      Synchronize (AppInterface.OnDisplay);
      *)

      for I := 0 to FileMasks.Count - 1 do // process FileMasks and xFileMasks
        Inc (Percentes.GeneralSize, Headers.AddNews (FileMasks [I]));

      if (Headers.GetCount ([toUpdate, toFresh]) > 0) or ( (Length (aOption) > 0) and (Headers.GetNext (0, toCopy) > -1) ) then
      begin
        Time        := Now;
        TmpFileName := GenerateFileName (yOption);
        TmpFile     := TFileWriter.Create (TmpFileName, fmCreate);

        ProcessFilesToFresh (Headers);  // find sequences and...

        if ProcessFilesToSwap (Headers) then // decode solid header modified in a swap file
        begin
          Headers.SortNews (Cfg, sOption, kOption,  eOption); // sort headers (only toUpdate headers)

          if Length (SwapName) > 0 then // if exists a modified solid sequence
            SwapFile := TFileReader.Create (SwapName, fmOpenRead + fmShareDenyWrite); // open Swap file

          if Length (aOption) > 0 then Headers.SetModule (aOption); // set sfx module

          Headers.WriteItems (TmpFile); // write Headers
          Encoder := TEncoder.Create (TmpFile, Percentes); // global GeneralSize
          for I := 0 to Headers.Count - 1 do
            case THeader (Headers.Items [I]).Action of
              toCopy:   Encoder.CopyStrm   (Headers.Items [I], emNorm, ArcFile);
              toSwap:   Encoder.EncodeStrm (Headers.Items [I], emNorm, SwapFile);
              toFresh:  Encoder.EncodeFile (Headers.Items [I], emNorm);
              toUpdate: Encoder.EncodeFile (Headers.Items [I], emNorm);
            end;
          Encoder.Destroy;
          Headers.WriteItems (TmpFile); // rewrite Headers

          AppInterface.cMsg := (Cr + 'Archive size ' + SizeToStr (TmpFile.Size) + ' bytes - ' + TimeDifference (Time) + ' seconds');
          Synchronize (AppInterface.OnDisplay);

          if Assigned (SwapFile) then FreeAndNil (SwapFile);
          if Assigned (ArcFile) then FreeAndNil (ArcFile);
          FreeAndNil (TmpFile);

          SysUtils.DeleteFile (SwapName);
          SysUtils.DeleteFile (ArcName);
          if not RenameFile (TmpFileName, ArcName) then
          begin
            SysUtils.DeleteFile (TmpFileName);

            AppInterface.cMsg := ('Error: can''t rename TempFile to ' + ArcName);
            Synchronize (AppInterface.OnError);
          end else
            ProcesstOption; // process tOption

        end else
        begin
          if Assigned (SwapFile) then FreeAndNil (SwapFile);
          if Assigned (ArcFile) then FreeAndNil (ArcFile);
          FreeAndNil (TmpFile);

          SysUtils.DeleteFile (SwapName);
          SysUtils.DeleteFile (TmpFileName);

          AppInterface.cMsg := ('Error: can''t decode solid sequences');
          Synchronize (AppInterface.OnError);
        end;

      end else
      begin
        AppInterface.cMsg := ('Warning: no files to process');
        Synchronize (AppInterface.OnWarning);
      end;
    end;

    Headers.Free;
    if Assigned (ArcFile) then FreeAndNil (ArcFile);
    {$IFNDEF CONSOLE} ListShell; {$ENDIF}
  end;

  procedure TBeeApp.DecodeShell (Action: THeaderAction);
  var
    Decoder: TDecoder;
    Headers: THeaders;
    Return: boolean;
    Time: double;
    I: integer;
  begin
    Headers := THeaders.Create;

    AppInterface.cMsg := (Cr + msgOpening + 'archive ' + ArcName);
    Synchronize (AppInterface.OnDisplay);

    if OpenArchive (Headers, toNone) then
    begin
      // [AF] deleted at 2023-03-09
      (*
      AppInterface.cMsg := (msgScanning + '...');
      Synchronize (AppInterface.OnDisplay);
      *)

      Headers.MarkItems (FileMasks, toNone, Action);
      Headers.MarkItems (xOption  , Action, toNone);

      if (Action = toExtract) then
      begin
        ProcessFilesToExtract (Headers);
        ProcessFilesToOverWrite (Headers);
      end;

      Percentes.GeneralSize := Headers.GetSize (Action);
      if (Headers.GetNext (0, Action) > - 1) then // action = toTest or toExtract
      begin
        Time := Now;
        ProcessFilesToDecode (Headers, Action);

        Return := True;
        Decoder := TDecoder.Create (ArcFile, Percentes); // set GeneralSize
        for I := 0 to Headers.Count - 1 do
        begin
          case THeader (Headers.Items [I]).Action of
            toExtract: Return := Decoder.DecodeFile (Headers.Items [I], pmNorm);
            toTest:    Return := Decoder.DecodeFile (Headers.Items [I], pmTest);
            toSkip:    Return := Decoder.DecodeFile (Headers.Items [I], pmSkip);
            toQuit:    Return := Decoder.Decodefile (Headers.Items [I], pmQuit);
          end;
          if Return = False then Break;
        end;
        Decoder.Destroy;
        
        if Return = True then
          AppInterface.cMsg := (Cr + 'Everything went ok - ' + TimeDifference (Time) + ' seconds')
        else
          AppInterface.cMsg := (Cr + 'Process aborted, a fatal error occurred - ' + TimeDifference (Time) + ' seconds');

        Synchronize (AppInterface.OnDisplay);
      end else
      begin
        AppInterface.cMsg := ('Warning: no files to decode');
        Synchronize (AppInterface.OnWarning);
      end;
    end;

    Headers.Free;
    if Assigned (ArcFile) then FreeAndNil (ArcFile);
  end;

  procedure TBeeApp.DeleteShell;
  var
    TmpFileName: string;
    TmpFile: TFileWriter;
    I: integer;
    Time: double;
    Headers: THeaders;
    Encoder: TEncoder;
  begin
    Headers := THeaders.Create;

    AppInterface.cMsg := (Cr + msgOpening + 'archive ' + ArcName);
    Synchronize (AppInterface.OnDisplay);

    if OpenArchive (Headers, toCopy) then
    begin
      // [AF] deleted at 2023-03-09
      (*
      AppInterface.cMsg := (msgScanning + '...');
      Synchronize (AppInterface.OnDisplay);
      *)

      Headers.MarkItems (FileMasks, toCopy, toDelete);
      Headers.MarkItems (xOption  , toDelete, toCopy);

      if (Headers.GetNext (0, toDelete) > -1) or ( (Length (aOption) > 0) and (Headers.GetNext (0, toCopy) > -1) ) then
      begin
        Time        := Now;
        TmpFileName := GenerateFileName (yOption);
        TmpFile     := TFileWriter.Create (TmpFileName, fmCreate);

        ProcessFilesToDelete (Headers); // find sequences

        if ProcessFilesToSwap (Headers) then
        begin
          ProcessFilesDeleted (Headers); // rescue headers information

          if Length (SwapName) > 0 then // if SwapSequences has found a modified sequence
            SwapFile := TFileReader.Create (SwapName, fmOpenRead + fmShareDenyWrite); // open Swap file

          if Length (aOption) > 0 then Headers.SetModule (aOption); // set sfx module

          Headers.WriteItems (TmpFile); // write Headers
          Encoder := TEncoder.Create  (TmpFile, Percentes); // GeneralSize
          for I := 0 to Headers.Count - 1 do
            case THeader (Headers.Items [I]).Action of
              toCopy:   Encoder.CopyStrm   (Headers.Items [I], emNorm, ArcFile);
              toSwap:   Encoder.EncodeStrm (Headers.Items [I], emNorm, SwapFile);
              toDelete: begin
                          AppInterface.cMsg := (msgDeleting + THeader (Headers.Items [I]).Name);
                          Synchronize (AppInterface.OnDisplay);
                        end;
            end;
          Encoder.Destroy;
          Headers.WriteItems (TmpFile);

          AppInterface.cMsg := (Cr + 'Archive size ' + SizeToStr (TmpFile.Size) + ' bytes - ' + TimeDifference (Time) + ' seconds');
          Synchronize (AppInterface.OnDisplay);

          if Assigned (SwapFile) then FreeAndNil (SwapFile);
          if Assigned (ArcFile) then FreeAndNil (ArcFile);
          FreeAndNil (TmpFile);

          SysUtils.DeleteFile (SwapName);
          SysUtils.DeleteFile (ArcName);
          if not RenameFile (TmpFileName, ArcName) then
          begin
            AppInterface.cMsg := ('Error: can''t rename TempFile to ' + ArcName);
            Synchronize (AppInterface.OnError);
          end else
            ProcesstOption; // process tOption

        end else
        begin
          if Assigned (SwapFile) then FreeAndNil (SwapFile);
          if Assigned (ArcFile) then FreeAndNil (ArcFile);
          FreeAndNil (TmpFile);

          SysUtils.DeleteFile (SwapName);
          SysUtils.DeleteFile (TmpFileName);

          AppInterface.cMsg := ('Error: can''t decode solid sequences');
          Synchronize (AppInterface.OnError);
        end;

      end else
      begin
        AppInterface.cMsg := ('Warning: no files to delete');
        Synchronize (AppInterface.OnWarning);
      end;
    end;

    Headers.Free;
    if Assigned (ArcFile) then FreeAndNil (ArcFile);
    {$IFNDEF CONSOLE} ListShell; {$ENDIF}
  end;

  procedure TBeeApp.RenameShell;
  var
    TmpFile: TFileWriter;
    TmpFileName: string;
    NewFileName: string;
    Headers: THeaders;
    Encoder: TEncoder;
    Time: double;
    I: integer;
  begin
    Headers := THeaders.Create;

    AppInterface.cMsg := (Cr + msgOpening + 'archive ' + ArcName);
    Synchronize (AppInterface.OnDisplay);

    if OpenArchive (Headers, toCopy) then
    begin
      // [AF] deleted at 2023-03-09
      (*
      AppInterface.cMsg := (msgScanning + '...');
      Synchronize (AppInterface.OnDisplay);
      *)

      Headers.MarkItems (FileMasks, toCopy, toRename);
      Headers.MarkItems (xOption  , toRename, toCopy);

      Percentes.GeneralSize := Headers.GetPackedSize ([toCopy, toRename]);

      if (Headers.GetNext (0, toRename) > -1) or ( (Length (aOption) > 0) and (Headers.GetNext (0, toCopy) > -1) ) then
      begin
        Time        := Now;
        TmpFileName := GenerateFileName (yOption);
        TmpFile     := TFileWriter.Create (TmpFileName, fmCreate);

        for I := 0 to Headers.Count - 1 do
        begin
          if (THeader (Headers.Items [I]).Action = toRename) then
          begin
            while True do
            begin
              AppInterface.cFileName := THeader (Headers.Items [I]).Name;
              AppInterface.cFileSize := THeader (Headers.Items [I]).Size;
              AppInterface.cFileTime := THeader (Headers.Items [I]).Time;
              AppInterface.cMsg      := '';

              Synchronize (AppInterface.OnRename);

              NewFileName := DeleteFileDrive (FixFileName (AppInterface.cMsg));
              if (Headers.GetPointer (NewFileName, [toCopy, toRename]) <> nil) then
              begin
                AppInterface.cMsg := ('File "' + NewFileName + '" already existing in archive!');
                Synchronize (AppInterface.OnWarning);
              end else
                Break;
            end;

            if Length (NewFileName) > 0 then
              THeader (Headers.Items [I]).Name := NewFileName;
          end;
        end;

        if Length (aOption) > 0 then Headers.SetModule (aOption); // set sfx module

        Headers.WriteItems (TmpFile);
        Encoder := TEncoder.Create (TmpFile, Percentes);
        for I := 0 to Headers.Count - 1 do
        begin
          Encoder.CopyStrm (Headers.Items [I], emNorm, ArcFile);
        end;
        Encoder.Destroy;
        Headers.WriteItems (TmpFile);

        AppInterface.cMsg := (Cr + 'Archive size ' + SizeToStr (TmpFile.Size) + ' bytes - ' + TimeDifference (Time) + ' seconds');
        Synchronize (AppInterface.OnDisplay);

        if Assigned (ArcFile) then FreeAndNil (ArcFile);
        FreeAndNil (TmpFile);

        SysUtils.DeleteFile (ArcName);
        if not RenameFile (TmpFileName, ArcName) then
        begin
          AppInterface.cMsg := ('Error: can''t rename TempFile to ' + ArcName);
          Synchronize (AppInterface.OnError);
        end else
          ProcesstOption; // process tOption

      end else
      begin
        AppInterface.cMsg := ('Warning: no files to rename');
        Synchronize (AppInterface.OnWarning);
      end;
    end;

    Headers.Free;
    if Assigned (ArcFile) then FreeAndNil (ArcFile);
    {$IFNDEF CONSOLE} ListShell; {$ENDIF}
  end;

  procedure TBeeApp.ListShell;
  var
    P: THeader;
    I: integer;
    Info: THeaders;
    Version, Method, Dictionary: integer;
    {$IFDEF CONSOLE}
    TotalPacked, TotalSize: integer;
    CountFiles: integer;
    {$ELSE}
    Node: TAppListNode;
    {$ENDIF}
  begin
    Info := THeaders.Create;

    {$IFNDEF DEBUG}
    AppInterface.cMsg := (Cr + msgOpening + 'archive ' + ArcName);
    Synchronize (AppInterface.OnDisplay);
    {$ENDIF}

    if OpenArchive (Info, toNone) then
    begin
      {$IFDEF CONSOLE}
      TotalSize   :=  0;
      TotalPacked :=  0;
      CountFiles  :=  0;
      {$ENDIF}

      // [AF] deleted at 2023-03-09
      (*
      {$IFNDEF DEBUG}
      AppInterface.cMsg := (msgScanning + '...');
      Synchronize (AppInterface.OnDisplay);
      {$ENDIF}
      *)

      {$IFDEF CONSOLE}
      Info.MarkItems (FileMasks, toNone, toList);
      Info.MarkItems (xOption  , toList, toNone);

      if (Info.GetNext (0, toList) > -1) then
      begin
        AppInterface.cMsg := (Cr + 'Name                  Size     Packed Ratio     Date  Time   Attr      CRC Meth');
        Synchronize (AppInterface.OnDisplay);

        AppInterface.cMsg := StringOfChar ('-', 79);
        Synchronize (AppInterface.OnDisplay);

        for I := 0 to Info.Count - 1 do
          if THeader (Info.Items [I]).Action = toList then
          begin
            P := Info.Items [I];

            Version := Info.GetBack (I, foVersion);
            if (Version > -1) and (Version < Info.Count) then
              Version := THeader (Info.Items [Version]).Version;

            Method := Info.GetBack (I, foMethod);
            if (Method > -1) and (Method < Info.Count) then
              Method := THeader (Info.Items [Method]).Method;

            Dictionary := Info.GetBack (I, foDictionary);
            if (Dictionary > -1) and (Dictionary < Info.Count) then
              Dictionary := THeader (Info.Items [Dictionary]).Dictionary;

            if (Length(P.Name) + Length(SizeToStr(P.Size))) < 26 then
            begin
              AppInterface.cMsg := (Format ('%s%s%s %10s %5s %14s %6s %8.8x %4s', [
                P.Name,
                StringOfChar(' ', 26 - Length(P.Name) - Length(SizeToStr(P.Size))),
                SizeToStr   (P.Size                     ),
                SizeToStr   (P.PackedSize               ),
                RatioToStr  (P.PackedSize, P.Size       ),
                DateTime    (FileDateToDateTime (P.Time)),
                AttrToStr   (P.Attr                     ),
                P.Crc,
                MethodToStr (P, Method, Dictionary)])   );
            end else
            begin
              AppInterface.cMsg := (Format ('%s' + Cr + '%26s %10s %5s %14s %6s %8.8x %4s', [
                P.Name,
                SizeToStr   (P.Size                     ),
                SizeToStr   (P.PackedSize               ),
                RatioToStr  (P.PackedSize, P.Size       ),
                DateTime    (FileDateToDateTime (P.Time)),
                AttrToStr   (P.Attr                     ),
                P.Crc,
                MethodToStr (P, Method, Dictionary)])   );
            end;
            Synchronize (AppInterface.OnDisplay);

            Inc (TotalSize  , P.Size      );
            Inc (TotalPacked, P.PackedSize);
            Inc (CountFiles);
          end;

        AppInterface.cMsg := StringOfChar ('-', 79);
        Synchronize (AppInterface.OnDisplay);

        AppInterface.cMsg :=
          (Format ('%d files %*s %10s %5s' + Cr, [
            CountFiles,
            25 - Length (Format ('%d files', [CountFiles])), SizeToStr (TotalSize),
            SizeToStr (TotalPacked),
            RatioToStr (TotalPacked, TotalSize)]));
        Synchronize (AppInterface.OnDisplay);

        // self-extractor module size
        if Info.GetModuleSize > 0 then
        begin
          AppInterface.cMsg := ('Note: Bee Self-Extractor module found' + Cr);
          Synchronize (AppInterface.OnDisplay);
        end;

      end else
      begin
        AppInterface.cMsg := ('Warning: no files to list');
        Synchronize (AppInterface.OnWarning);
      end;

      {$ELSE}

      Synchronize (AppInterface.OnList);
      AppInterface.cList.Clear;

      Version     := -1;
      Method      := -1;
      Dictionary  := -1;

      for I := 0 to Info.Count - 1 do
      begin
        AppInterface.cPercentage := MulDiv (I, 100, Info.Count);
        Synchronize (AppInterface.OnTick);

        P := Info.Items [I];

        if foVersion    in P.Flags then Version    := P.Version;
        if foMethod     in P.Flags then Method     := P.Method;
        if foDictionary in P.Flags then Dictionary := P.Dictionary;

        Node             := TAppListNode.Create;
        Node.FileName    := ExtractFileName (P.Name);
        Node.FilePath    := ExtractFilePath (P.Name);
        Node.FileSize    := P.Size;
        Node.FilePacked  := P.PackedSize;

        if Node.FileSize = 0 then
          Node.FileRatio := 0
        else
          Node.FileRatio := MulDiv (Node.FilePacked, 100, Node.FileSize);

        Node.FileAttr    := P.Attr;
        Node.FileTime    := P.Time;
        Node.FileComm    := '';
        Node.FileCrc     := P.Crc;
        Node.FileMethod  := MethodToStr (P, Method, Dictionary);
        Node.FileVersion := VersionToStr (Version);

        if foPassword in P.Flags then
          Node.FilePassword := 'Yes'
        else
          Node.FilePassword := 'No';

        Node.FilePosition := I;
        Node.FileIcon := -1;

        AppInterface.cList.Add (Node);
      end;

      {$IFNDEF DEBUG}
        AppInterface.cMsg := (Format (Cr + '%d item(s) found', [Info.Count]));
        Synchronize (AppInterface.OnDisplay);
      {$ENDIF}

      {$ENDIF}
    end;

    Info.Free;
    if Assigned (ArcFile) then FreeAndNil (ArcFile);
  end;

/// string functions

  function TBeeApp.SizeToStr (Size: integer): string;
  begin
    Result := Format ('%u', [Size]);
  end;

  function TBeeApp.RatioToStr (PackedSize, Size: integer): string;
  begin
    Result := Format ('%3d%%', [MulDiv (PackedSize, 100, Max (1, Size))]);
  end;

  function TBeeApp.AttrToStr (Attr: integer): string;
  begin
    Result := '..RHSA';
    if Attr and faReadOnly = 0 then Result [3] := '.';
    if Attr and faHidden   = 0 then Result [4] := '.';
    if Attr and faSysFile  = 0 then Result [5] := '.';
    if Attr and faArchive  = 0 then Result [6] := '.';
  end;

  function TBeeApp.MethodToStr (P: THeader; Method, Dictionary: integer): string;
  begin
    Result := 'm?d?';

    if not (foTear in P.Flags) then
      Result [1] := 's';

    if Method in [0..3] then
      Result [2] := char (byte ('0') + Method);

    if Dictionary in [0..9] then
      Result [4] := char (byte ('0') + Dictionary);
  end;

  function TBeeApp.VersionToStr (VersionId: cardinal): string;
  const
    DecimalSeparator = '.';
  begin
    case VersionId of
      0: Result := ' 0' + DecimalSeparator + '2';
      1: Result := ' 0' + DecimalSeparator + '3';
      else
         Result := ' 0' + DecimalSeparator + '0';
    end;
  end;

  procedure TBeeApp.MySynchronize (AMethod: TThreadMethod);
  begin
    Synchronize (AMethod);
  end;
  
end.





