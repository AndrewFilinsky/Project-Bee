unit UOptimizer;

{ Implements genetic optimization to create optimal parameters
  for Bee 0.7.7.
}

{$R-,Q-,S-,W-,O+}

interface

uses
  Math,               // Max (), Min (), ...
  Classes,
  Windows,
  System.Types,
  SysUtils,

  Bee_Configuration,
  Bee_Common,
  Bee_Files,
  Bee_Headers,
  Bee_Codec,          // TSecondaryEncoder, TSecondaryDecoder...
  Bee_Modeller;       // TBaseCoder...

const
  DefaultCfgName = 'Bee.ini';     // Стандартное имя файла конфигурации
  // Для PPM:
  CrossoverProbability = 0.15;    // Вероятность кроссовера
  MutationProbability  = 0.08;    // Вероятность мутации

type
  /// Тело сжимаемого файла

  TBody = class
  public
    Data: array of Byte;
  public
    constructor Create(const aFileName: string);
    destructor  Destroy; override;
  end;

  /// Особь (в смысле генетического алгоритма)

  TPerson = class (TObject)
  public
    Genome: TTableParameters;  /// Геном особи
    Cost: Integer;             /// Качество особи
  public
    constructor Create; overload;
    constructor Create (Parent1, Parent2: TPerson); overload;
    constructor Create (Stream: TStream); overload;
    procedure   Save (Stream: TStream);
    procedure   MarkToRecalculate;        /// Отметить особь как не оцененую
    function    IsEqual (Person: TPerson): Boolean;
  end;

  /// Популяция особей (в смысле генетического алгоритма), определяющих параметры определенного уровня сжатия

  TPopulation = class (TList)
  public
    constructor Create; overload;                   /// Создать пустую популяцию
    constructor Create (Stream: TStream); overload; /// Прочитать популяцию из потока
    destructor  Destroy; override;        /// Уничтожить популяцию вместе с содержимым
    procedure   Save (Stream: TStream);
    procedure   Add (P: TPerson);         /// Добавить особь, не нарушая упорядоченность
    procedure   MarkToRecalculate;        /// Отметить все особи как не оцененые
    function    HasPerson (Person: TPerson): Boolean;
  end;

  /// Множество популяций (в смысле генетического алгоритма), каждая из которых определяет параметры определенного уровня сжатия

  TPopulations = class (TList)
  public
    CurrentPopulation: Integer;           /// Номер текущей популяции
    CurrentAge: Integer;                  /// Номер текущего годе
    Improvements: Integer;                /// Количество улучшенных особей
  public
    constructor Create;                         /// Создать набор пустых популяций
    destructor  Destroy; override;              /// Уничтожить набор популяций вместе с содержимым
    procedure   Load (const FileName: string);  /// Прочитать набор популяций.
    procedure   Save (const FileName: string);  /// Записать набор популяций.
    procedure   Live;                           /// Имитировать размножение одной из особей одной из популяций
    procedure   MarkToRecalculate;              /// Отметить все особи всех популяций как не оцененые
  end;

  /// Окружение мира, в котором происходит эволюция

  TApp = class
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   Evolution; /// Запустить эволюцию

    procedure   ExtractLevels (World: TPopulations; const Ext: string);
    procedure   CollectWorlds (const Path: string);
    procedure   CollectConfigurations (CfgName: string);
    /// Собрать рекурсивно несколько dat файлов в один ...
    procedure   MergeDataRecursively (const Path, Name: string; World: TPopulations);
    procedure   DrawLevelProgress;
  public
    SrcName: string;       /// Имя обрабатываемого каталога
    Cfg: TConfiguration;   /// Параметры конфигурации
    World: TPopulations;   /// Мир, набор популяций

    Headers: THeaders;     /// Список файлов
    Bodyes: TList;         /// Содержимое файлов
    SamplesSize: Integer;  /// Размер выборки файлов

    Encoder: TBaseCoder;   /// Упаковщик
    SecondaryCodec: TSecondaryCodec;   /// Допаковщик
    Nowhere: TNulWriter;   /// Выходной поток упаковщика

    Priority: Cardinal;    /// Выбранный приоритет задачи оптимизации
  private
    ConfigurationName: string;
  private
    procedure   Encode (aDeep: Boolean);                        // Закодировать все блоки, используя текущие установленные параметры.
    procedure   ReduceSection (Section: TConfigSection);        // Reduce unneeded strings from given Section of Bee.Ini
  end;

implementation

uses
  Forms,
  UFormMain;

/// TBody...

constructor TBody.Create(const aFileName: string);
var
  F: TFileStream;
begin
  inherited Create;
  F := TFileStream.Create (aFileName, fmOpenRead + fmShareDenyWrite);
  SetLength (Data, F.Size);
  F.ReadBuffer (Data [0], F.Size);
  F.Free;
end;

destructor  TBody.Destroy;
begin
  Data := nil;
  inherited;
end;

{ TPerson }

constructor TPerson.Create;
var
  I: Integer;
begin
  /// Построить геном случайным образом
  for I := 0 to SizeOf (Genome) - 1 do Genome [I] := Random (256);
  /// Качество еще не оценено
  Cost := 0;
end;

{ Mutate value as unsigned int8.
}
function Mutate(Value: Byte): Byte;
var
  ToIncrement: boolean;
begin
  // select direction ..
  if Value = 255 then
    ToIncrement := false
  else if Value = 0 then
    ToIncrement := true
  else
    ToIncrement := Random > 0.5;

  // change value ..
  if ToIncrement then
  begin
    // Increment value..
    Result := Value + 1 + round(Sqr(Sqr(Random)) * (255 - Value - 1));
  end else
  begin
    // Decrement value..
    Result := Value - 1 - round(Sqr(Sqr(Random)) * (Value - 1));
  end;
end;

constructor TPerson.Create (Parent1, Parent2: TPerson);
var
  Parents: array [0..1] of TPerson; // Массив предков, для удобства выбора
  ParentIndex: Integer;             // Текущий номер предка
  I: Integer;                       // Текущий номер хромосомы и гена в хромосоме
begin
  /// Приготовиться к смешиванию...
  Parents [0] := Parent1;
  Parents [1] := Parent2;
  ParentIndex := Random (2);
  /// Формируем новый геном
  for I := 1 to SizeOf (Genome) - 1 do
  begin
    /// Меняем предка с некоторой вероятностью
    if Random < CrossoverProbability then ParentIndex := ParentIndex xor 1;
    Genome [I] := Parents [ParentIndex].Genome [I];
    // Гены мутируют с некоторой вероятностью
    // Применяем мутацию аналогового значения, а не отдельных битов:
    if Random < MutationProbability then
      Genome[I] := Mutate(Genome[I]);
  end;
  /// Качество еще не оценено
  Cost := 0;
end;

constructor TPerson.Create (Stream: TStream);
begin
  Stream.ReadBuffer (Genome, SizeOf (Genome));
  Stream.ReadBuffer (Cost, SizeOf (Cost));
end;

procedure TPerson.Save (Stream: TStream);
begin
  Stream.WriteBuffer (Genome, SizeOf (Genome));
  Stream.WriteBuffer (Cost, SizeOf (Cost));
end;

procedure TPerson.MarkToRecalculate;
begin
  Cost := 0;
end;

function  TPerson.IsEqual (Person: TPerson): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to SizeOf (Genome) - 1 do
    if Genome [I] <> Person.Genome [I] then Exit;
  Result := True;
end;

/// TPopulation

constructor TPopulation.Create;
begin
  inherited;
end;

constructor TPopulation.Create (Stream: TStream);
var
  NewCount: Integer;
begin
  inherited Create;
  /// Прочитать численность новой популяции
  Stream.ReadBuffer (NewCount, SizeOf (NewCount));
  /// Прочитать особи новой популяции
  while Count < NewCount do
    Add (TPerson.Create (Stream));
end;

procedure TPopulation.Save (Stream: TStream);
var
  I: Integer;
begin
  /// Записать численность популяции
  Stream.WriteBuffer (Count, SizeOf (Count));
  /// Записать особи популяции
  for I := 0 to Count - 1 do TPerson (List [I]).Save (Stream);
end;

procedure   TPopulation.Add (P: TPerson);
var
  I: Integer;
begin
  I := 0; while (I < Count) and (TPerson (List [I]).Cost < P.Cost) do Inc (I);
  Insert (I, P);
end;

procedure   TPopulation.MarkToRecalculate;
begin
  while Count > 1 do TPerson (Extract (Last)).Free;
  if Count > 0 then TPerson (First).MarkToRecalculate;
end;

destructor  TPopulation.Destroy;
begin
  while Count > 0 do TPerson (Extract (First)).Free;
  inherited;
end;

function  TPopulation.HasPerson (Person: TPerson): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to Count - 1 do
    if Person.IsEqual (TPerson (List [I])) then Exit;
  Result := False;
end;

/// TPopulations

constructor TPopulations.Create;
begin
  inherited;
  CurrentPopulation := 0;
  CurrentAge := 0;
  Improvements := 0;
  while Count < 15 do Add (TPopulation.Create);
end;

destructor TPopulations.Destroy;
begin
  while Count > 0 do TPopulation (Extract (First)).Free;
  inherited;
end;

procedure TPopulations.Load (const FileName: string);
var
  Stream: TFileReader;       /// Поток для чтения состояния мира
begin
  /// Поток не создан
  Stream := nil;
  /// Создать поток
  if FileExists (FileName) then
    Stream := TFileReader.Create (FileName, fmOpenRead + fmShareDenyWrite)
  else if FileExists (FileName + '.tmp') then
    Stream := TFileReader.Create (FileName + '.tmp', fmOpenRead + fmShareDenyWrite);
  /// Поток создан?
  if Stream <> nil then
  begin
    /// Прочитать мир из потока
    Stream.ReadBuffer (CurrentPopulation, SizeOf (CurrentPopulation));
    Stream.ReadBuffer (CurrentAge, SizeOf (CurrentAge));
    Stream.ReadBuffer (Improvements, SizeOf (Improvements));
    while Count > 0 do TPopulation (Extract (First)).Free;
    while Count < 15 do Add (TPopulation.Create (Stream));
    /// Закрыть поток
    Stream.Free;
  end;
end;

procedure TPopulations.Save (const FileName: string);
var
  Stream: TFileWriter;       /// Поток для записи состояния мира
  I: Integer;                /// Номер популяции
  TmpName: string;
begin
  TmpName := FileName + '.tmp';
  DeleteFile(TmpName);
  // Создать новый файл для сохранения состояния мира
  Stream := TFileWriter.Create (TmpName, fmCreate);
  Stream.WriteBuffer (CurrentPopulation, SizeOf (CurrentPopulation));
  Stream.WriteBuffer (CurrentAge, SizeOf (CurrentAge));
  Stream.WriteBuffer (Improvements, SizeOf (Improvements));
  for I := 0 to Count - 1 do
    TPopulation (List [I]).Save (Stream);
  Stream.Free;
  // Переименовать в основной файл
  DeleteFile(FileName);
  RenameFile(TmpName, FileName);
end;

procedure TPopulations.Live;
var
  FullSize,                 /// Размер популяции
  HalfSize: Integer;        /// Размер половины популяции
  Population1,              /// Основная популяция...
  Population2: TPopulation; /// Соседняя популяция...
  Parent1,                  /// Перый родитель
  Parent2,                  /// Второй родитель
  Person: TPerson;          /// Новая особь
var
  DictionaryLevel: Integer;
  I: Integer;
begin
  /// Вычислить размер популяции
  FullSize := 1;
  HalfSize := 1;

  /// Переоценка нужна?
  if CurrentAge mod 2000 = 0 then
  begin
    /// Выполнить переоценку ...
    for I := 0 to Count - 1 do TPopulation (List [I]).MarkToRecalculate;
    /// Потратить один год ...
    Inc (CurrentAge);
  end;

  /// Получить доступ к текущей популяции
  Population1 := List [CurrentPopulation];

  if Population1.Count = 0 then /// Популяция пуста?
  begin
    /// Построить новую особь случайным образом...
    Person := TPerson.Create;
    MainForm.ShowStatusBar ('Generate random parameters...');
  end
  else if TPerson (Population1.First).Cost = 0 then /// Первая особь популяции не оценена?
  begin
    /// Изъять первую особь из популяции...
    Person := Population1.Extract (Population1.First);
    MainForm.ShowStatusBar ('Recalculate parameters estimation...');
  end else
  begin
    repeat
      /// Выбрать популяцию второго родителя
      repeat
        Population2 :=
          List [Max (0, Min (CurrentPopulation + Random (3) - 1, Count - 1))];
      until Population2.Count > 0;
      /// Выбрать первого родителя
      Parent1 := Population1.List[Random(Population1.Count)];
      /// Выбрать второго родителя
      Parent2 := Population2.List[Random(Population2.Count)];
    until Parent1 <> Parent2;
    /// Построить новую особь, взяв за образец генотипы родителей
    repeat
      Person := TPerson.Create (Parent1, Parent2);
      if Population1.HasPerson (Person) then FreeAndNil (Person);
    until Person <> nil;
    MainForm.ShowStatusBar ('Parameters optimization...');
  end;

  /// Оценить особь
  begin
    /// Перевести номер популяции в уровень сжатия
    Person.Genome [0] := CurrentPopulation + 1;
    /// Передать геном кодировщику
    MainForm.App.Encoder.SetTable (Person.Genome);
    /// Установить размер словаря для кодировщика
    DictionaryLevel := CurrentAge div 2000 + 1;
    MainForm.App.Encoder.SetDictionary (DictionaryLevel);
    MainForm.Label_DictionaryLevelValue.Caption := Format ('%d (~%d Mb)', [DictionaryLevel, (1 shl (17 + Min (Max (0, DictionaryLevel), 9))) * 20 shr 20]);
    /// Очистить выходной поток
    // MainForm.App.Nowhere.Position := 0;
    MainForm.App.Nowhere.Current := 0;
    /// Очистить допаковщик
    MainForm.App.SecondaryCodec.Start;
    /// Закодировать список блоков
    MainForm.App.Encode (False);
    if MainForm.DeepOptimizationEnabled then MainForm.App.Encode (True);

    /// Сбросить буфер допаковщика
    MainForm.App.SecondaryCodec.Flush;
    /// Аннулировать результат упаковки и выйти, если прервано...
    if MainForm.NeedToClose then
    begin
      /// Добавить (неоцененную) особь в популяцию ...
      Population1.Add (Person);
      /// Выйти ...
      Exit;
    end else
    begin
      /// Запомнить результат упаковки ...
      // Person.Cost := MainForm.App.Nowhere.Position;
      Person.Cost := MainForm.App.Nowhere.Current;
    end;
  end;

  /// Расчитать статистику и Изменить текущую популяцию ...
  begin
    if Population1.Count > 0 then
    begin
      /// Расчитать возраст мира ...
      if TPerson (Population1.First).Cost > 0 then Inc (CurrentAge);
      /// Расчитать процент усовершенствований ...
      if TPerson (Population1.First).Cost > Person.Cost then Inc (Improvements);
    end;
    /// Добавить особь в популяцию ...
    Population1.Add (Person);

    /// Популяция полна & Все особи популяции оценены?
    if (Population1.Count > FullSize) and (TPerson (Population1.First).Cost > 0) then
      /// Популяция полна. Уничтожить половину самых слабых ...
      while Population1.Count > HalfSize do TPerson (Population1.Extract (Population1.Last)).Free;
  end;

  /// Вывести отчет о популяции...
  WriteText (MainForm.App.SrcName + '.log.txt', Format ('%d' + #9, [TPerson (Population1.First).Cost]));
  /// Вывести отчет обо всех популяциях...
  if CurrentPopulation = 14 then
    WriteText (MainForm.App.SrcName + '.log.txt', Format ('| %5d turn, -d%d, %d jumps (%1.1f%%).' + Cr, [CurrentAge, DictionaryLevel, Improvements, Improvements / (CurrentAge + 1) * 100]));
  /// Перейти к следующей популяции
  CurrentPopulation := (CurrentPopulation + 1) mod 15;
end;

procedure TPopulations.MarkToRecalculate;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do TPopulation (List [I]).MarkToRecalculate;
  CurrentPopulation := 0;
  CurrentAge := 0;
  Improvements := 0;
end;

/// Окружение мира, в котором происходит эволюция

constructor TApp.Create;
var
  I: Integer;
  S: string;
begin
  inherited Create;
  SetFileApisToOEM;
  Randomize;

  /// Создать пустой мир
  World := TPopulations.Create;
  /// Имя каталога по умолчанию не выбрано
  SrcName := '';
  /// Создать пустую конфигурацию
  Cfg := TConfiguration.Create;
  /// Наполнить конфигурацию значениями по умолчанию
  Cfg.Selector ('\main');
  Cfg.CurrentSection.Values ['Method'] := '1';
  Cfg.CurrentSection.Values ['Dictionary'] := '3';

  /// Дефолтный приоритет = 0

  Priority := 0;

  /// Разобрать параметры командной строки
  for I := 1 to ParamCount do
  begin
    S := UpperCase (ParamStr (I));
    /// Задан режим переоценки особей?
    if Pos ('-RECALCULATE', S) = 1 then
    begin
      MainForm.NeedToRecalculate := True;
    end else
    /// Задано собрать несколько .dat файлов в один?
    if Pos ('-REDUCE', S) = 1 then
    begin
      MainForm.NeedToReduceIni := True;
    end else
    /// Задано собрать несколько .dat файлов в один?
    if Pos ('-MERGE', S) = 1 then
    begin
      MainForm.NeedToMerge := True;
    end else
    /// Задано спрятать приложение?
    if Pos ('-HIDE', S) = 1 then
    begin
      MainForm.NeedToHide := True;
    end else
    /// It is specified to perform deep parameters optimization?
    if Pos ('-DEEP', S) = 1 then
    begin
      MainForm.DeepOptimizationEnabled := True;
    end else
    /// Задан уровень сжатия?
    if Pos ('-M', S) = 1 then
    begin
      Delete (S, 1, 2);
      Cfg.Selector ('\main');
      Cfg.CurrentSection.Values ['Method'] := IntToStr (Max (1, Min (StrToInt (S), 3)));
    end else
    /// Задан размер словаря?
    if Pos ('-D', S) = 1 then
    begin
      Delete (S, 1, 2);
      Cfg.Selector ('\main');
      Cfg.CurrentSection.Values ['Dictionary'] := IntToStr (Max (0, Min (StrToInt (S), 9)));
    end else
    /// Задана сборка файла конфигурации?
    if Pos ('-C', S) = 1 then
    begin
      ConfigurationName := Copy (ParamStr (I), 3, MaxInt);
      MainForm.NeedToCollectConfig := True;
      MainForm.NeedToRun := False;
    end else
    /// Задан приоритет?
    if Pos ('-PRI', S) = 1 then
    begin
      Priority := StrToInt (Copy (ParamStr (I), 5, MaxInt));
    end else
    /// Какой-то другой параметр?
    if CharInSet (S[I], ['-', '/']) then
    begin
      /// Nothing
    end else
    /// Имя каталога еще не определено?
    if SrcName = '' then
    begin
      SrcName := ParamStr (I);
      MainForm.Label_ExtensionValue.Caption := '.' + SrcName;
    end;
  end;

  Headers     := THeaders.Create;
  Bodyes      := TList.Create;
  SamplesSize := 0;

  if SrcName <> '' then
  begin
    /// Просканировать указанный каталог
    Headers.AddNews (SrcName);
    Headers.SortNews (Cfg, False {not Solid}, False, '');
    /// Прочитать все блоки данных
    for I := 0 to Headers.Count - 1 do
    begin
      Bodyes.Add (TBody.Create (THeader (Headers [I]).Name));
      SamplesSize := SamplesSize + Length (TBody (Bodyes [I]).Data);
    end;
  end;

  Nowhere := TNulWriter.Create;
  // Nowhere := TFileStream.Create('nul', fmOpenWrite);
  SecondaryCodec := TSecondaryEncoder.Create (Nowhere);
  Encoder := TBaseCoder.Create (SecondaryCodec);

  MainForm.Label_SampleSizeValue.Caption := Format ('%d', [SamplesSize]);

  /// Свернуть приложение
  MainForm.ApplicationMinimize (nil);
end;

destructor TApp.Destroy;
begin
  World.Free;
  Cfg.Free;
  Headers.Free;
  while Bodyes.Count > 0 do
  begin
    TBody (Bodyes.First).Free;
    Bodyes.Delete (0);
  end;
  Bodyes.Free;
  Encoder.Free;
  SecondaryCodec.Free;
  Nowhere.Free;
  inherited;
end;

procedure TApp.ExtractLevels (World: TPopulations; const Ext: string);
var
  Levels: TList;
  I: Integer;
begin
  Levels := TList.Create;

  /// Собрать лучших представителей популяций
  WriteText ('Collect.txt', Cr + Ext + ':' + Cr);
  for I := 0 to World.Count - 1 do
  begin
    if TPopulation (World.List [I]).Count = 0 then Continue;
    WriteText ('Collect.txt', Format ('%d:', [TPerson (TPopulation (World.List [I]).First).Genome [0]]) + #9 + Format ('%d', [TPerson (TPopulation (World.List [I]).First).Cost]));
    if TPerson (TPopulation (World.List [I]).First).Genome [0] < 2 then
    begin
      WriteText ('Collect.txt', Cr);
      Continue;
    end else if (Levels.Count > 0) and (TPerson (TPopulation (World.List [I]).First).Cost > TPerson (Levels.Last).Cost) then
    begin
      WriteText ('Collect.txt', Cr);
      Continue;
    end else
    begin
      WriteText ('Collect.txt', ' +' + Cr);
      Levels.Add (TPopulation (World.List [I]).First);
    end;
  end;

  /// Добавить в конфигурацию представителей для трех степеней сжатия
  if Levels.Count > 0 then
  begin
    Cfg.Selector ('\m1');
    Cfg.CurrentSection.Values [Ext + '.Size'] := IntToStr (TPerson (Levels.First).Cost);
    Cfg.PutData (Ext, TPerson (Levels.First).Genome, SizeOf (TPerson (Levels.First).Genome));
    Cfg.Selector ('\m2');
    Cfg.CurrentSection.Values [Ext + '.Size'] := IntToStr (TPerson (Levels.List [Min (1, Levels.Count - 1)]).Cost);
    Cfg.PutData (Ext, TPerson (Levels.List [Min (1, Levels.Count - 1)]).Genome, SizeOf (TPerson (Levels.First).Genome));
    Cfg.Selector ('\m3');
    Cfg.CurrentSection.Values [Ext + '.Size'] := IntToStr (TPerson (Levels.Last).Cost);
    Cfg.PutData (Ext, TPerson (Levels.Last).Genome, SizeOf (TPerson (Levels.First).Genome));
  end;
end;

procedure  TApp.CollectWorlds (const Path: string);
var
  World: TPopulations;
  T: TSearchRec;
begin
  /// Найти в заданном каталоге миры и добавить их параметры в файл конфигурации
  if FindFirst (Path + '*.dat', faAnyFile - faDirectory, T) = 0 then
    repeat
      if (T.Name <> '.') and (T.Name <> '..') then
      begin
        World := TPopulations.Create;
        World.Load (Path + T.Name);
        ExtractLevels (World, '.' + ChangeFileExt (ExtractFileName (T.Name), ''));
        World.Free;
      end;
    until FindNext (T) <> 0;
  FindClose (T);

  /// Найти подкаталоги и вызвать их рекурсивную обработку
  if FindFirst (Path + '*.*', faDirectory, T) = 0 then
    repeat
      if (T.Name <> '.') and (T.Name <> '..') then CollectWorlds (Path + T.Name + '\');
    until FindNext (T) <> 0;
  FindClose (T);
end;

procedure  TApp.CollectConfigurations (CfgName: string);
begin
  /// Задать стандартное имя файла конфигурации, если имя файла не указано
  if CfgName = '' then CfgName := DefaultCfgName;
  /// Добавить к имени стандартное расширение, если расширение не указано явно
  if ExtractFileExt (CfgName) = '' then CfgName := CfgName + '.ini';
  /// Прочитать заданный файл конфигурации
  if FileExists (SelfPath + CfgName) then Cfg.LoadFromFile (SelfPath + CfgName);
  /// Собрать рекурсивно все файлы описания миров
  CollectWorlds (SelfPath);
  /// Reduce Cfg if need ...
  if MainForm.NeedToReduceIni then
  begin
    Cfg.Selector ('\m1'); ReduceSection (Cfg.CurrentSection);
    Cfg.Selector ('\m2'); ReduceSection (Cfg.CurrentSection);
    Cfg.Selector ('\m3'); ReduceSection (Cfg.CurrentSection);
  end;
  /// Сохранить собранный файл конфигурации
  Cfg.SaveToFile (CfgName);
end;

/// Собрать рекурсивно несколько ".dat" файлов в один ...

procedure TApp.MergeDataRecursively (const Path, Name: string; World: TPopulations);
var
  TmpWorld: TPopulations;
  T: TSearchRec;
  I: Integer;
begin
  /// Найти в заданном каталоге миры и добавить их параметры в файл конфигурации
  if FindFirst (Path + Name, faAnyFile - faDirectory, T) = 0 then
    repeat
      if (T.Name <> '.') and (T.Name <> '..') then
      begin
        TmpWorld := TPopulations.Create;
        TmpWorld.Load (Path + T.Name);
        World.CurrentAge := Max (0, Min (World.CurrentAge, TmpWorld.CurrentAge));
        TmpWorld.MarkToRecalculate;
        for I := 0 to TmpWorld.Count - 1 do
          if TPopulation (TmpWorld.List [I]).Count > 0 then
          begin
            TPopulation (World.List [I]).Add (TPopulation (TmpWorld.List [I]).First);
            TPopulation (TmpWorld.List [I]).Delete (0);
          end;
        TmpWorld.Free;
      end;
    until FindNext (T) <> 0;
  FindClose (T);

  /// Найти подкаталоги и вызвать их рекурсивную обработку
  if FindFirst (Path + '*.*', faDirectory, T) = 0 then
    repeat
      if (T.Name <> '.') and (T.Name <> '..') then
        MergeDataRecursively (Path + T.Name + '\', Name, World);
    until FindNext (T) <> 0;

  /// Закончить поиск ...
  FindClose (T);
end;

procedure TApp.Evolution;
begin
  /// Collect configuration, if needed ...
  if MainForm.NeedToCollectConfig then
    CollectConfigurations (ConfigurationName);

  /// Выполнить подготовку к пересчету, если нужно ...
  if MainForm.NeedToRecalculate then
  begin
    World.Load (SrcName + '.dat');
    World.MarkToRecalculate;
    World.Save (SrcName + '.dat');
    MainForm.ShowStatusBar ('Parameters marked to recalculate.');
    MainForm.ApplicationRestore (Self);
    Exit;
  end;

  /// Выполнить сборку ".dat" файлов, если нужно ...
  if MainForm.NeedToMerge then
  begin
    World.Free;
    World := TPopulations.Create;
    World.CurrentAge := 12000;
    /// Собрать рекурсивно все файлы описания миров
    MergeDataRecursively ('.\', SrcName + '.dat', World);
    /// Установить год продолжения оптимизации ...
    World.CurrentAge := (World.CurrentAge div 2000) * 2000 + 1;
    /// Сохранить собранный .dat файл ...
    World.Save (SrcName + '.dat');
    /// Выдать status bar ...
    MainForm.ShowStatusBar ('All "' + SrcName + '.dat" merged. Run again to continue...');
    MainForm.ApplicationRestore (Self);
    Exit;
  end;

  if MainForm.NeedToRun = False then
  begin
    MainForm.ShowStatusBar ('Configuration file was maked.');
    MainForm.ApplicationRestore (Self);
    Exit;
  end;

  /// Выполнить проверки обязательных условий оптимизации ...

  if SrcName = '' then
  begin
    MainForm.ShowStatusBar ('Folder is not selected.');
    MainForm.ApplicationRestore (Self);
    Exit;
  end;

  if Headers.Count = 0 then
  begin
    MainForm.ShowStatusBar ('No files for optimization.');
    MainForm.ApplicationRestore (Self);
    Exit;
  end;

  MainForm.ShowStatusBar ('Optimization...');

  /// Установить выбранный приоритет приложения
  SetPriority (Priority);

  /// Начать / продолжить эволюцию...

  World.Load (SrcName + '.dat');

  repeat
    DrawLevelProgress;
    World.Live;
    if not MainForm.NeedToClose then World.Save (SrcName + '.dat');
    Application.ProcessMessages;
  until MainForm.NeedToClose;
end;

procedure TApp.DrawLevelProgress;
begin
  MainForm.Label_VariantsEstimatedValue.Caption := Format ('%d', [World.CurrentAge]);
  MainForm.Label_PercentOfImprovementsValue.Caption := Format ('%f%%', [World.Improvements / (World.CurrentAge + 1) * 100]);
  MainForm.Label_LevelValue.Caption := Format ('%d', [World.CurrentPopulation + 1]);

  if TPopulation (World.List [World.CurrentPopulation]).Count > 0 then
    MainForm.Label_PackedSizeValue.Caption := Format ('%d', [TPerson (TPopulation (World.List [World.CurrentPopulation]).First).Cost])
  else
    MainForm.Label_PackedSizeValue.Caption := '-';

  MainForm.TrayIcon.Tip := Format ('%d variants, %f%% improvements.', [World.CurrentAge, World.Improvements / (World.CurrentAge + 1) * 100]);
end;

procedure TApp.Encode(aDeep: Boolean);
var
  I, J: Integer;
  CurrentBody: TBody;
  Data: PByte;
begin
  for I := 0 to Bodyes.Count - 1 do
  begin
    if aDeep then
      Encoder.FreshSolid
    else
      Encoder.FreshFlexible;

    CurrentBody := Bodyes [I];
    Data := @ CurrentBody.Data [0];

    for J := Length (CurrentBody.Data) downto 1 do
    begin
      Encoder.UpdateModel (Data^);
      if J and $FFF = 0 then
      begin
        Application.ProcessMessages;
        if MainForm.NeedToClose then Exit;
      end;
      Inc (Data);
    end;
  end;
end;

procedure TApp.ReduceSection (Section: TConfigSection);
var
  I: Integer;
begin
  I := 0;
  while I < Section.Count do
    if Pos ('.Size', Cfg.CurrentSection.Names [I]) > 0 then
      Section.Delete (I)
    else
      Inc (I);
end;

end.

