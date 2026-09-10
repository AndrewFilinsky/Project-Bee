unit Bee_Headers;

{ Contains:

  Archive headers processing.

  (C) 1999-2006 Andrew Filinsky and Melchiorre Caruso.

  Modifyed:

  v0.7.8 build 0150 - 2005/06/27 by Melchiorre Caruso;
  v0.7.8 build 0154 - 2005/07/23 by Melchiorre Caruso;

  v0.7.9 build 0298 - 2006/01/05 by Melchiorre Caruso.
}

{$I Compiler.inc}

interface

uses
  Math,
  Classes, // TList
  SysUtils, // TSearchRec

  Bee_Files,
  Bee_Common, // FSplit, DirectoryExists, ...
  Bee_Configuration;

const

  // Id marker
  
  Marker: integer = 442852674;
  
type

  // Header flags

  THeaderFlag  =
  (foVersion , foMethod  , foDictionary, foTable   , foTear    , foMoved   , foLast,
   foPassword, fo09Unused, fo10Unused  , fo11Unused, fo12Unused, fo13Unused, fo14Unused,
   fo15Unused, fo16Unused, fo17Unused  , fo18Unused, fo19Unused, fo20Unused, fo21Unused,
   fo22Unused, fo23Unused, fo24Unused  , fo25Unused, fo26Unused, fo27Unused, fo28Unused,
   fo29Unused, fo30Unused, fo31Unused  , fo32Unused);

  THeaderFlags = set of THeaderFlag;

type

  // Header action

  THeaderAction = ( toUpdate, toFresh, toCopy, toSwap, toExtract, toTest, toSkip, toQuit, toDelete, toRename, toList, toNone );

  // Headers actions

  THeaderActions = set of THeaderAction;

type

  // Header structure, order of fields is significant

  THeader = class
  public
    // start file header

    Flags:      THeaderFlags;
    Version:    byte;
    Method:     byte;
    Dictionary: byte;
    Table:      TTableParameters;
    Size:       integer;
    Time:       integer;
    Attr:       integer;
    Crc:        cardinal;
    PackedSize: integer;
    StartPos:   integer;
    Name:       string;

    // end file header

    Action:     THeaderAction;
    Option:     string;
    TSize:      integer;
    constructor Create (const cOption: string; const Path: string; const T: TSearchRec);
    constructor Read (Stream: TStream; Default: THeaderAction);
    destructor  Destroy; override;

    function    Fresh (const cOption: string; const Path: string; const T: TSearchRec): integer;
    function    SetTable (Config: TConfiguration): boolean;
    procedure   Write (Stream: TStream);
    function    GetName: string;
  end;

type

  // Tidy List

  TTidyList = class (TList)
  public
    function    InsertItem (Item: pointer): integer;
    function    SearchItem (const FileName: string): pointer;
  end;

type

  // Headers list

  THeaders = class (TList)
  public
    cOption:    string;
    fOption:    boolean;
    uOption:    boolean;
    xOption:    TStringList;

    constructor Create;
    destructor  Destroy; override;

    function    AddNews (const aMask: string): integer;
    procedure   MarkItems (Masks: TStringList; MaskAct, Action: THeaderAction);
    procedure   MarkItem (Index: integer; Action: THeaderAction);
    procedure   MarkAll (Action: THeaderAction);

    procedure   SortNews (Config: TConfiguration; sOption: boolean; kOption: boolean; const eOption: string);

    procedure   ReadItemsB4b (Stream: TStream; Default: THeaderAction);
    procedure   ReadItems (Stream: TStream; Default: THeaderAction);
    procedure   WriteItems (Stream: TStream);

    function    GetBack (Child: integer; Action: THeaderAction): integer; overload;
    function    GetNext (Child: integer; Action: THeaderAction): integer; overload;
    function    GetBack (Child: integer; Flag: THeaderFlag): integer; overload;
    function    GetNext (Child: integer; Flag: THeaderFlag): integer; overload;
    function    GetBack (Child: integer; Action: THeaderAction; const Name: string): integer; overload;
    function    GetNext (Child: integer; Action: THeaderAction; const Name: string): integer; overload;

    function    GetSize (Action: THeaderAction): integer; overload;
    function    GetPackedSize (Action: THeaderAction): integer; overload;
    function    GetSize (Actions: THeaderActions): integer; overload;
    function    GetPackedSize (Actions: THeaderActions): integer; overload;

    function    GetCount (Actions: THeaderActions): integer;
    function    GetPointer (const FileName: string; Actions: THeaderActions): pointer;

    function    SetModule (const Module: string): boolean;
    function    GetModuleSize: integer;
  private
    SfxStrm:    TStream;
    TidyList:   TTidyList;

    procedure   AddItem (Item: pointer);
    procedure   QuickSort (L, R: integer);
    function    FindFirstMarker (Stream: TStream): integer;
    procedure   SearchNews (const aMask: string; var Size: integer);

    procedure   MarkLast (Last: THeaderAction);
    function    MaskInMasks (const Mask: string; Masks: TStringList): boolean;
  end;

implementation

/// Compare header function

  function CompareFn (L: TList; Index1, Index2: integer): integer;
  var
    bool1, bool2 : boolean;
  begin
    with THeader (L.Items [Index1]) do bool1 := (Action = toUpdate);
    with THeader (L.Items [Index2]) do bool2 := (Action = toUpdate);

    if ( bool1 and bool2 ) then
    begin
      Result := Bee_Common.CompareText (ExtractFileExt  (THeader (L.Items [Index1]).Name), ExtractFileExt  (THeader (L.Items [Index2]).Name));
      if Result = 0 then Result := Bee_Common.CompareText (ExtractFileName (THeader (L.Items [Index1]).Name), ExtractFileName (THeader (L.Items [Index2]).Name));
      if Result = 0 then Result := Bee_Common.CompareText (THeader (L.Items [Index1]).Name ,                  THeader (L.Items [Index2]).Name );
    end else
      if bool1 then
        Result := 1
      else
        if bool2 then
          Result := -1
        else
          Result := Index1 - Index2;
  end;

/// THeader

  constructor THeader.Create;
  begin
    Action     := toUpdate;
    Option     := cOption;
    TSize      := T.Size;
    // --
    Flags      := [foTear, foTable];
    Version    := 1; // Bee 0.3.x
    Method     := 1;
    Dictionary := 2;
    Time       := T.Time;
    Crc        := cardinal (-1);
    Name       := Path + T.Name;
  end;

  function THeader.Fresh;
  begin
    Time       := T.Time;
    Name       := Path + T.Name;
    Result     := T.Size - TSize;
    // --
    Option     := cOption;
    TSize      := T.Size;

    if Action = toCopy then
      Action := toFresh;
  end;

  constructor THeader.Read;
  var
    J: integer;
    AnsiName: AnsiString;
  const
    sSecondPart = SizeOf (Size) + SizeOf (Time) + SizeOf (Attr) + SizeOf (Crc) + SizeOf (PackedSize) + SizeOf (StartPos);
  begin
    Action  := Default;
    Option  := '';
    TSize   :=  0;

    if Stream.Read (Flags, SizeOf (Flags))                                         <> SizeOf (Flags)      then raise ERangeError.Create('THeader.Read');
    if foVersion    in Flags then if Stream.Read (Version, SizeOf (Version))       <> SizeOf (Version)    then raise ERangeError.Create('THeader.Read');
    if foMethod     in Flags then if Stream.Read (Method, SizeOf (Method))         <> SizeOf (Method)     then raise ERangeError.Create('THeader.Read');
    if foDictionary in Flags then if Stream.Read (Dictionary, SizeOf (Dictionary)) <> SizeOf (Dictionary) then raise ERangeError.Create('THeader.Read');
    if foTable      in Flags then if Stream.Read (Table, SizeOf (Table))           <> SizeOf (Table)      then raise ERangeError.Create('THeader.Read');
    if Stream.Read (Size, sSecondPart)                                             <> sSecondPart         then raise ERangeError.Create('THeader.Read');

    if Stream.Read (J, SizeOf(integer))                                            <> SizeOf (J)          then raise ERangeError.Create('THeader.Read');
    // The file contains the name in Ansi format, so read it by local variable
    SetLength(AnsiName, J);
    if Stream.Read(AnsiName[1], J)                                                 <> J                   then raise ERangeError.Create('THeader.Read');
    Name := AnsiName;

    DoDirSeparators(Name);
  end;

  destructor THeader.Destroy;
  begin
    SetLength (Name, 0);
    SetLength (Option, 0);
  end;

  procedure THeader.Write;
  var
    AnsiName: AnsiString;
    AnsiNameLength: integer;
  const
    sSecondPart = SizeOf (Size) + SizeOf (Time) + SizeOf (Attr) + SizeOf (Crc) + SizeOf (PackedSize) + SizeOf (StartPos);
  begin
    Stream.Write (Flags, SizeOf (Flags));

    if foVersion    in Flags then Stream.Write (Version,    SizeOf (Version   ));
    if foMethod     in Flags then Stream.Write (Method,     SizeOf (Method    ));
    if foDictionary in Flags then Stream.Write (Dictionary, SizeOf (Dictionary));
    if foTable      in Flags then Stream.Write (Table,      SizeOf (Table     ));

    Stream.Write (Size, sSecondPart);

    // The file contains the name in Ansi format, so write it by local variable
    AnsiName := GetName;
    AnsiNameLength := Length(AnsiName);
    Stream.Write(AnsiNameLength, SizeOf (integer));
    Stream.Write(AnsiName[1], AnsiNameLength);
  end;

  function  THeader.SetTable (Config: TConfiguration): boolean;
  begin
    Result := Config.GetTable (ExtractFileExt (Name), Table);
  end;

  function THeader.GetName;
  begin
    Result := Option + DeleteFileDrive (Name);
  end;

/// TidyList

  function TTidyList.SearchItem;
  var
    L, M, H: integer;
  begin
    L :=   0;
    M := - 1;
    H := Count - 1;

    while H >= L do
    begin
      M := (L + H) div 2;
      if Bee_Common.CompareText (FileName, THeader (Items [M]).GetName) > 0 then
        L := M + 1
      else
        if Bee_Common.CompareText (FileName, THeader (Items [M]).GetName) < 0 then
          H := M - 1
        else
          H := - 2;
    end;

    if not (H = - 2) then
      Result := nil
    else
      Result := Items [M];
  end;

  function TTidyList.InsertItem;
  var
    L, M, H: integer;
    FName: string;
  begin
    L :=   0;
    M := - 1;
    H := Count - 1;

    FName := THeader (Item).GetName;
    while H >= L do
    begin
      M := (L + H) div 2;
      if Bee_Common.CompareText (FName, THeader (Items [M]).GetName) > 0 then
        L := M + 1
      else
        if Bee_Common.CompareText (FName, THeader (Items [M]).GetName) < 0 then
          H := M - 1
        else
          H := - 2;
    end;

    if M = - 1 then
      Result := 0
    else
      if Bee_Common.CompareText (FName, THeader (Items [M]).GetName) < 0 then
        Result := M
      else
        Result := M + 1;

    Insert (Result, Item);
  end;

/// THeaders

  constructor THeaders.Create;
  begin
    inherited Create;
    cOption  := '';
    fOption  := False;
    uOption  := False;
    xOption  := nil;
    
    TidyList := TTidyList.Create;
    SfxStrm  := TMemoryStream.Create;
  end;

  destructor THeaders.Destroy;
  var
    I: integer;
  begin
    TidyList.Destroy;
    FreeAndNil (SfxStrm);
    for I := Count - 1 downto 0 do
      THeader (Items [I]).Destroy;
    inherited Destroy;
  end;

  function THeaders.AddNews;
  begin
    Result := 0;
    SearchNews (aMask, Result);
  end;

  procedure THeaders.MarkItems;
  var
    I: integer;
  begin
    for I := 0 to Count - 1 do
      if (THeader (Items [I]).Action = MaskAct) and (MaskInMasks (THeader (Items [I]).Name, Masks)) then
        THeader (Items [I]).Action := Action;
  end;

  procedure THeaders.MarkItem;
  begin
    THeader (Items [Index]).Action := Action;
  end;

  procedure THeaders.MarkAll;
  var
    I: integer;
  begin
    for I := 0 to Count - 1 do
      THeader (Items [I]).Action := Action;
  end;
  
  procedure THeaders.SortNews;
  var
    P: THeader;
    First, I, Method, Dictionary: integer;
    CurrentExt, PreviousExt: string;
  begin         
    QuickSort (0, Count -1);

    Config.Selector ('\main');
    Method := StrToInt (Config.CurrentSection.Values ['Method']);
    Dictionary := StrToInt (Config.CurrentSection.Values ['Dictionary']);
    Config.Selector ('\m' + Config.CurrentSection.Values ['Method']);

    First := GetNext (0, toUpdate);
    if not (First = -1) then
    begin
      CurrentExt := '.';
      I := First;
      repeat
        P := Get (I);

        if I = First then P.Flags := P.Flags + [foVersion, foMethod, foDictionary];

        P.Method     := Method;
        P.Dictionary := Dictionary;
        PreviousExt  := CurrentExt;

        if Length (eOption) = 0 then
          CurrentExt := ExtractFileExt (P.Name)
        else
          CurrentExt := eOption;

        if kOption then Include (P.Flags, foPassword);

        if (Method = 0) or (not Config.GetTable (CurrentExt, P.Table)) then
        begin
          Include (P.Flags, foMoved);
          Exclude (P.Flags, foTable);
        end else
          if Bee_Common.CompareText (CurrentExt, PreviousExt) <> 0 then
          begin
            Include (P.Flags, foTable);
          end else
          begin
            Exclude (P.Flags, foTable);
            if sOption then Exclude (P.Flags, foTear);
          end;

        Inc (I);
      until I = Count;
    end;
  end;

  function THeaders.SetModule;
  var
    SFXmodule: TStream;
  begin
    Result := False;
    SfxStrm.Size := 0;
    if FileExists (ExtractFilePath (ParamStr (0)) + Module) then
    begin
      SFXmodule := TFileReader.Create (ExtractFilePath (ParamStr (0)) + Module, fmOpenRead);
      try
        SfxStrm.CopyFrom (SFXmodule, SFXmodule.Size);
        Result := True;
      finally
        FreeAndNil (SFXmodule);
      end;
    end;
  end;

  function THeaders.GetModuleSize: integer;
  begin
    Result := SfxStrm.Size;
  end;

  function THeaders.FindFirstMarker;
  var
    Id: integer;
    StrmPos: integer;
  begin
    Result := -1; // archive type unknow

    StrmPos := Stream.Seek (0, 0);
    while Stream.Read (Id, SizeOf (integer)) = SizeOf (integer) do
    begin
      if Id = Marker then
      begin
        Result := StrmPos;
        Break;
      end;
      Inc (StrmPos, SizeOf (integer));
    end;

    if Result > 0 then // save sfx module
    begin
      Stream.Seek (0, 0);

      SfxStrm.Size := 0;
      SfxStrm.CopyFrom (Stream, Result);
    end;
  end;

  procedure THeaders.ReadItemsB4b;
  var
    P: THeader;
    Ptr: ^integer;
    Readed: byte;
    NextByte: integer;
    B4bMarker: array [0..3] of byte;
  begin
    P := nil;
    Ptr := @B4bMarker;
    Ptr^ := Marker;

    NextByte := 0;
    Stream.Seek (0, 0);
    repeat
      if Stream.Read (Readed, 1) = 1 then
      begin
        if Readed = B4bMarker [NextByte] then
          Inc (NextByte)
        else
          NextByte := 0;

        if NextByte = SizeOf (integer) then
          try
            NextByte := 0;
            P := THeader.Read (Stream, Default); AddItem (P);
          except
            P := nil;
          end;

      end else
        Break;
        
    until (not (P = nil)) and (foLast in P.Flags);
    if not (P = nil) then Exclude (P.Flags, foLast);
  end;

  procedure THeaders.ReadItems;
  var
    P: THeader;
    Id: integer;
    OffSet: integer;
  begin
    P := nil;
    OffSet := FindFirstMarker (Stream);

    if OffSet > -1 then
    begin
      Stream.Seek (OffSet, 0);
      repeat
        if (Stream.Read (Id, SizeOf (integer)) = SizeOf (integer)) and (Id = Marker) then
          try
            P := THeader.Read (Stream, Default); AddItem (P);
          except
            P := nil;
          end
        else
          Break;
      until (not (P = nil)) and (foLast in P.Flags);
      if not (P = nil) then Exclude (P.Flags, foLast);
    end else
      ReadItemsB4b (Stream, Default);
  end;

  procedure THeaders.WriteItems;
  var
    I: integer;
  begin
    if Stream.Seek (0, 1) = 0 then
    begin
      if (SfxStrm.Size > 0) then
      begin
        SfxStrm.Seek (0 ,0);
        Stream.CopyFrom (SfxStrm, SfxStrm.Size);
      end;
    end else
      Stream.Seek (SfxStrm.Size, 0);

    MarkLast (toDelete);
    for I := 0 to Count - 1 do
      if not (THeader (Items [I]).Action = toDelete) then
      begin
        Stream.Write (Marker, 4);
        THeader (Items [I]).Write (Stream);
      end;
  end;

  function THeaders.GetPointer;
  begin
    Result := TidyList.SearchItem (FileName);
    if not (Result = nil) then
      if not (THeader (Result).Action in Actions) then
        Result := nil;
  end;
  
  function THeaders.GetCount;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if (THeader (Items [I]).Action in Actions) then
        Inc (Result);
  end;

  function THeaders.GetNext (Child: integer; Action: THeaderAction): integer;
  var
    I: integer;
  begin
    Result := -1;
    for I := Child to Count - 1 do
      if (THeader (Items [I]).Action = Action) then
      begin
        Result := I;
        Exit;
      end;
  end;

  function THeaders.GetBack (Child: integer; Action: THeaderAction): integer;
  var
    I: integer;
  begin
    Result := -1;
    for I := Child downto 0 do
      if (THeader (Items [I]).Action = Action) then
      begin
        Result := I;
        Exit;
      end;
  end;

  function THeaders.GetNext (Child: integer; Flag: THeaderFlag): integer;
  var
    I: Integer;
  begin
    Result := -1;  
    for I := Child to Count - 1 do
    begin
      if (Flag in THeader (Items [I]).Flags) then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;

  function THeaders.GetBack (Child: integer; Flag: THeaderFlag): integer;
  var
    I: Integer;
  begin
    Result := -1;
    for I := Child downto 0 do
    begin
      if (Flag in THeader (Items [I]).Flags) then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;

  function THeaders.GetNext (Child: integer; Action: THeaderAction; const Name: string): integer;
  var
    I: Integer;
  begin
    Result := -1;
    for I := Child to Count - 1 do
    begin
      if (Action = THeader (Items [I]).Action) and
         (CompareText (Name, THeader (Items [I]).Name) = 0) then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;

  function THeaders.GetBack (Child: integer; Action: THeaderAction; const Name: string): integer;
  var
    I: Integer;
  begin
    Result := -1;
    for I := Child downto 0 do
    begin
      if (Action = THeader (Items [I]).Action) and
         (CompareText (Name, THeader (Items [I]).Name) = 0) then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;

  function THeaders.GetSize (Action: THeaderAction): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action = Action then
        Inc (Result, THeader (Items [I]).Size);
  end;

  function THeaders.GetPackedSize (Action: THeaderAction): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action = Action then
        Inc (Result, THeader (Items [I]).PackedSize);
  end;

  function THeaders.GetSize (Actions: THeaderActions): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action in Actions then
        Inc (Result, THeader (Items [I]).Size);
  end;

  function THeaders.GetPackedSize (Actions: THeaderActions): integer;
  var
    I: integer;
  begin
    Result := 0;
    for I := 0 to Count - 1 do
      if THeader (Items [I]).Action in Actions then
        Inc (Result, THeader (Items [I]).PackedSize);
  end;

  // Private procedure and function

  procedure THeaders.AddItem;
  begin
    Add (Item);
    TidyList.InsertItem (Item);
  end;

  procedure THeaders.QuickSort;
  var
    I, J, Pivot: integer;
  begin
    if R < L then Exit;
    repeat
      I := L;
      J := R;
      Pivot := (L + R) div 2;
      repeat
        while CompareFn (Self, I, Pivot) < 0 do Inc (I);
        while CompareFn (Self, J, Pivot) > 0 do Dec (J);
        if I <= J then
        begin
          Exchange (I, J);
          if Pivot = I then
            Pivot := J
          else
            if Pivot = J then
              Pivot := I;
          Inc (I);
          Dec (j);
        end;
      until I > J;
      if L < J then QuickSort (L, J);
      L := I;
    until I >= R;
  end;

  procedure THeaders.MarkLast;
  var
    I: integer;
  begin
    for I := Count - 1 downto 0 do
      if not (THeader (Items [I]).Action = Last) then
      begin
        Include (THeader (Items [I]).Flags, foLast);
        Exit;
      end;
  end;

  function THeaders.MaskInMasks (const Mask: string; Masks: TStringList): boolean;
  var
    Path, Name, Ext: string;
    jPath, jName, jExt: string;
    j, jCount: integer;
    Recursive: integer;
  begin
    Result := False;
    if (Assigned (Masks)) and (not (Masks.Count = 0)) then
    begin
      Path   := ExtractFilePath  (Mask);
      Name   := ChangeFileExt    (ExtractFileName (Mask), '');
      Ext    := ExtractFileExt   (Mask);
      jCount := 0;

      for j := 0  to Masks.Count - 1 do
      begin
        jPath  := ExtractFilePath  (Masks.Strings [j]);
        jName  := ChangeFileExt    (ExtractFileName (Masks.Strings [j]), '');
        jExt   := ExtractFileExt   (Masks.Strings [j]);
        jCount := 0;

        Recursive := Pos (RecursiveSign, jPath);
        if Recursive = (Length (jPath) - 1) then
        begin
          System.Delete (jPath, Recursive, 2);
          if (Recursive <> 1) then
            if not IsPathDelimiter (jPath, Recursive - 1) then Continue;
        end else
            if (Recursive <> 0) then Continue;

        if Recursive = 0 then
        begin
          if (Bee_Common.CompareText (jPath, Path) = 0) then Inc (jCount);
        end else
          if ( (Length (jPath) = 0) or (PosText (jPath, Path) = 1) ) then Inc (jCount);

        if ( (jName = '*') or (Bee_Common.CompareText (jName, Name) = 0) ) then Inc (jCount);
        if ( (jExt = '.*') or (Bee_Common.CompareText (jExt,  Ext ) = 0) ) then Inc (jCount);

        if (jCount = 3) then Break;
      end;

      if (jCount = 3) then Result := True else Result := False;
    end;
  end;

  procedure THeaders.SearchNews;
  var
    Mask, Path, Name: string;
    Recursive: integer;
    T: TSearchRec;
    P: THeader;
    J: Pointer;
  begin
    if DirectoryExists (aMask) then
      Mask := IncludeDelimiter (aMask) + RecursiveSign + '*.*'
    else
      Mask := aMask;

    Path := ExtractFilePath (Mask);
    Name := ExtractFileName (Mask);

    Recursive := Pos (RecursiveSign, Path);
    if Recursive = (Length (Path) - 1) then
    begin
      System.Delete (Path, Recursive, 2);
      System.Delete (Mask, Recursive, 2);
      if not (Recursive = 1) then
        if not IsPathDelimiter (Path, Recursive - 1) then Exit;
    end else
    if not (Recursive = 0) then Exit;

    // this directory...

    if FindFirst (Mask, faAnyFile - faDirectory, T) = 0 then
    repeat
      if MaskInMasks (Path + T.Name, xOption) = False then // if not excluded
      begin
        J := TidyList.SearchItem (cOption + DeleteFileDrive (Path + T.Name)); // search this filename
        if not (fOption xor uOption) then // update and fresh
        begin
          if (J = nil) then
          begin
            P := THeader.Create (cOption, Path, T);
            Inc (Size, T.Size);
            AddItem (P);                                                         
          end else
            if (T.Time > THeader (J).Time) then
              Size := Size + THeader (J).Fresh (cOption, Path, T);
        end else
          if fOption then // fresh
          begin
            if (not (J = nil)) and (T.Time > THeader (J).Time) then
              Size := Size + THeader (J).Fresh (cOption, Path, T);
          end else // update
          begin
            if (J = nil) then
            begin
              P := THeader.Create (cOption, Path, T);
              Inc (Size, T.Size);
              AddItem (P);  
            end;
          end;
      end;

    until not (FindNext (T) = 0);
    FindClose (T);

    if Recursive = 0 then exit;

    // sub-directoryes...

    if FindFirst (Path + '*.*', faDirectory, T) = 0 then
    repeat
      if (T.Name <> '.') and (T.Name <> '..') and (T.Attr and faDirectory = faDirectory) then
        SearchNews (Path + IncludeDelimiter (T.Name) + RecursiveSign + Name, Size);
    until not (FindNext (T) = 0);
    FindClose (T);
  end;

end.
