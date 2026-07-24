unit TlbGenerator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ActiveX, ComObj, Variants, IdlAst;

type
  EIdlGeneratorException = class(Exception);

  TTypeInfoCache = record
    Name: string;
    TypeInfo: ITypeInfo;
  end;

  TTlbGenerator = class
  private
    FFilePath: string;
    FCreateLib: ICreateTypeLib2;
    FCache: array of TTypeInfoCache;
    
    function GetAttributeValue(Attrs: TList; const Name: string; const DefaultVal: string = ''): string;
    procedure StringToGuid(const Str: string; out Guid: TGUID);
    function MapDataType(const TypeName: string; out Vt: TVarType): Boolean;
    
    procedure AddToCache(const AName: string; TI: ITypeInfo);
    function FindInCache(const AName: string): ITypeInfo;
    
    procedure GenerateLibrary(Lib: TIDLLibrary);
    procedure LoadImports(Imports: TStringList);
    procedure GenerateStruct(AstStruct: TIDLStruct);
    procedure GenerateInterface(Intf: TIDLInterface; IsDisp: Boolean = False);
    procedure GenerateEnum(AstEnum: TIDLEnum);
    procedure GenerateCoclass(AstCoclass: TIDLCoclass);
  public
    constructor Create(const AFilePath: string);
    procedure Generate(AstLib: TIDLLibrary);
  end;

implementation

{ TTlbGenerator }

constructor TTlbGenerator.Create(const AFilePath: string);
begin
  FFilePath := AFilePath;
end;

function TTlbGenerator.GetAttributeValue(Attrs: TList; const Name: string; const DefaultVal: string): string;
var
  I: Integer;
  A: TIDLAttribute;
begin
  Result := DefaultVal;
  for I := 0 to Attrs.Count - 1 do
  begin
    A := TIDLAttribute(Attrs[I]);
    if SameText(A.Name, Name) then
    begin
      Result := A.Value;
      Exit;
    end;
  end;
end;

procedure TTlbGenerator.StringToGuid(const Str: string; out Guid: TGUID);
begin
  // Dodajemy nawiasy klamrowe, których wymaga funkcja StringToGUID w FPC
  if (Length(Str) > 0) and (Str[1] <> '{') then
    Guid := SysUtils.StringToGUID('{' + Str + '}')
  else
    Guid := SysUtils.StringToGUID(Str);
end;

function TTlbGenerator.MapDataType(const TypeName: string; out Vt: TVarType): Boolean;
var
  CleanName: string;
begin
  Result := True;
  CleanName := Trim(TypeName);
  
  if Pos('SAFEARRAY(', CleanName) > 0 then
  begin
    Vt := VT_SAFEARRAY;
    Exit;
  end;
  
  // Usuwanie wskaźnika do mapowania głównego typu (wskaźniki obsługujemy przez VT_BYREF lub we flagach parametru)
  if Pos('*', CleanName) > 0 then
    CleanName := StringReplace(CleanName, '*', '', [rfReplaceAll]);

  if SameText(CleanName, 'long') then Vt := VT_I4
  else if SameText(CleanName, 'short') then Vt := VT_I2
  else if SameText(CleanName, 'BSTR') then Vt := VT_BSTR
  else if SameText(CleanName, 'VARIANT') then Vt := VT_VARIANT
  else if SameText(CleanName, 'HRESULT') then Vt := VT_HRESULT
  else if SameText(CleanName, 'void') then Vt := VT_VOID
  else
  begin
    Result := False; // Typ nierozpoznany lub niestandardowy
    Vt := VT_USERDEFINED;
  end;
end;

procedure TTlbGenerator.AddToCache(const AName: string; TI: ITypeInfo);
var
  Len: Integer;
begin
  Len := Length(FCache);
  SetLength(FCache, Len + 1);
  FCache[Len].Name := AName;
  FCache[Len].TypeInfo := TI;
end;

function TTlbGenerator.FindInCache(const AName: string): ITypeInfo;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FCache) do
  begin
    if SameText(FCache[I].Name, AName) then
    begin
      Result := FCache[I].TypeInfo;
      Exit;
    end;
  end;
end;

procedure TTlbGenerator.LoadImports(Imports: TStringList);
var
  I, J: Integer;
  LibName: string;
  ExtLib: ITypeLib;
  TI: ITypeInfo;
  BName: BSTR;
  DocString, HelpContext, HelpFile: BSTR;
begin
  for I := 0 to Imports.Count - 1 do
  begin
    LibName := Imports[I];
    if LoadTypeLib(PWideChar(WideString(LibName)), ExtLib) = S_OK then
    begin
      for J := 0 to ExtLib.GetTypeInfoCount - 1 do
      begin
        if Succeeded(ExtLib.GetTypeInfo(J, TI)) then
        begin
          if Succeeded(ExtLib.GetDocumentation(J, @BName, @DocString, @HelpContext, @HelpFile)) then
          begin
            AddToCache(BName, TI);
            SysFreeString(BName);
            SysFreeString(DocString);
            SysFreeString(HelpFile);
          end;
        end;
      end;
    end
    else
      WriteLn('Ostrzezenie: Nie mozna zaladowac biblioteki ', LibName);
  end;
end;

procedure TTlbGenerator.GenerateStruct(AstStruct: TIDLStruct);
var
  CreateTypeInfo: ICreateTypeInfo;
  TypeInfo: ITypeInfo;
  HRes: HRESULT;
  I: Integer;
  Mem: TIDLStructMember;
  VarDesc: tagVARDESC;
begin
  HRes := FCreateLib.CreateTypeInfo(PWideChar(WideString(AstStruct.Name)), TKIND_RECORD, CreateTypeInfo);
  if Failed(HRes) then Exit;

  for I := 0 to AstStruct.Members.Count - 1 do
  begin
    Mem := TIDLStructMember(AstStruct.Members[I]);
    
    FillChar(VarDesc, SizeOf(tagVARDESC), 0);
    VarDesc.memid := MEMBERID_NIL; // Dla struktur
    VarDesc.varkind := VAR_PERINSTANCE;
    MapDataType(Mem.DataType, VarDesc.elemdescVar.tdesc.vt);
    
    CreateTypeInfo.AddVarDesc(I, VarDesc);
    CreateTypeInfo.SetVarName(I, PWideChar(WideString(Mem.Name)));
  end;
  
  CreateTypeInfo.LayOut;
  
  if Succeeded(CreateTypeInfo.QueryInterface(IID_ITypeInfo, TypeInfo)) then
    AddToCache(AstStruct.Name, TypeInfo);
end;

procedure TTlbGenerator.GenerateLibrary(Lib: TIDLLibrary);
var
  LibGuid: TGUID;
  GuidStr: string;
  HRes: HRESULT;
begin
  // Pobieranie GUID
  GuidStr := GetAttributeValue(Lib.Attributes, 'uuid');
  if GuidStr = '' then
    raise EIdlGeneratorException.Create('Library musi posiadac atrybut uuid');
  StringToGuid(GuidStr, LibGuid);

  // Tworzenie pliku biblioteki
  HRes := CreateTypeLib2(SYS_WIN32, PWideChar(WideString(FFilePath)), FCreateLib);
  if Failed(HRes) then
    raise EIdlGeneratorException.CreateFmt('Blad CreateTypeLib2 (0x%x). Upewnij sie, ze sciezka jest poprawna.', [HRes]);

  // Ustawianie wlasciwosci
  FCreateLib.SetGuid(LibGuid);
  FCreateLib.SetName(PWideChar(WideString(Lib.Name)));
  FCreateLib.SetVersion(1, 0); // Mozna wyciagnac z atrybutu version
end;

procedure TTlbGenerator.GenerateInterface(Intf: TIDLInterface; IsDisp: Boolean);
var
  CreateTypeInfo: ICreateTypeInfo;
  TypeInfo: ITypeInfo;
  IntfGuid: TGUID;
  GuidStr: string;
  HRes: HRESULT;
  I, J: Integer;
  Meth: TIDLMethod;
  Param: TIDLParam;
  FuncDesc: tagFUNCDESC;
  ElemDesc: tagELEMDESC;
  ParamNames: array of PWideChar;
  ParamFlags: Word;
  Kind: TYPEKIND;
  HRef: HREFTYPE;
begin
  if IsDisp then
    Kind := TKIND_DISPATCH
  else
    Kind := TKIND_DISPATCH; // Zwykły IDispatch/Dual w OLE również jest TKIND_DISPATCH lub TKIND_INTERFACE zależnie od potrzeb
    
  // Tworzenie TypeInfo dla interfejsu
  HRes := FCreateLib.CreateTypeInfo(PWideChar(WideString(Intf.Name)), Kind, CreateTypeInfo);
  if Failed(HRes) then
    raise EIdlGeneratorException.CreateFmt('Nie mozna utworzyc interfejsu %s (0x%x)', [Intf.Name, HRes]);

  // Ustawianie GUID interfejsu
  GuidStr := GetAttributeValue(Intf.Attributes, 'uuid');
  if GuidStr <> '' then
  begin
    StringToGuid(GuidStr, IntfGuid);
    CreateTypeInfo.SetGuid(IntfGuid);
  end;

  // Flagi interfejsu np. oleautomation (TYPEFLAG_FOLEAUTOMATION = 256)
  // dual (TYPEFLAG_FDUAL = 64)
  ParamFlags := 0;
  if GetAttributeValue(Intf.Attributes, 'oleautomation', 'null') <> 'null' then ParamFlags := ParamFlags or 256;
  if GetAttributeValue(Intf.Attributes, 'dual', 'null') <> 'null' then ParamFlags := ParamFlags or 64;
  
  if ParamFlags > 0 then
    CreateTypeInfo.SetTypeFlags(ParamFlags);

  // Dziedziczenie z bazy (np. IUnknown)
  if Intf.BaseInterface <> '' then
  begin
    TypeInfo := FindInCache(Intf.BaseInterface);
    if Assigned(TypeInfo) then
    begin
      if Succeeded(CreateTypeInfo.AddRefTypeInfo(TypeInfo, HRef)) then
      begin
        CreateTypeInfo.AddImplType(0, HRef);
      end;
    end
    else
      WriteLn('Ostrzezenie: Nie znaleziono bazowego interfejsu ', Intf.BaseInterface);
  end;

  // Generowanie Metod
  for I := 0 to Intf.Methods.Count - 1 do
  begin
    Meth := TIDLMethod(Intf.Methods[I]);
    FillChar(FuncDesc, SizeOf(tagFUNCDESC), 0);
    
    // Identyfikator metody (DISPID)
    FuncDesc.memid := StrToIntDef(GetAttributeValue(Meth.Attributes, 'id', '0'), I + 1);
    FuncDesc.funckind := FUNC_DISPATCH;
    FuncDesc.invkind := INVOKE_FUNC;
    FuncDesc.callconv := CC_STDCALL;
    FuncDesc.cParams := Meth.Params.Count;
    FuncDesc.cParamsOpt := 0;

    // Typ zwracany (HRESULT)
    MapDataType(Meth.ReturnType, FuncDesc.elemdescFunc.tdesc.vt);

    // Parametry
    if Meth.Params.Count > 0 then
    begin
      FuncDesc.lprgelemdescParam := AllocMem(SizeOf(tagELEMDESC) * Meth.Params.Count);
      SetLength(ParamNames, Meth.Params.Count + 1);
      ParamNames[0] := PWideChar(WideString(Meth.Name)); // Pierwszy element to nazwa metody

      for J := 0 to Meth.Params.Count - 1 do
      begin
        Param := TIDLParam(Meth.Params[J]);
        ParamNames[J + 1] := StringToOleStr(WideString(Param.Name)); // Trzeba zwolnic!

        FillChar(ElemDesc, SizeOf(tagELEMDESC), 0);
        MapDataType(Param.DataType, ElemDesc.tdesc.vt);
        
        // Obsluga wskaźników
        if Pos('*', Param.DataType) > 0 then
        begin
          ElemDesc.tdesc.vt := ElemDesc.tdesc.vt or VT_BYREF;
        end;

        // Flagi parametrow ([in], [out], [retval])
        ParamFlags := 0;
        if GetAttributeValue(Param.Attributes, 'in', 'null') <> 'null' then ParamFlags := ParamFlags or PARAMFLAG_FIN;
        if GetAttributeValue(Param.Attributes, 'out', 'null') <> 'null' then ParamFlags := ParamFlags or PARAMFLAG_FOUT;
        if GetAttributeValue(Param.Attributes, 'retval', 'null') <> 'null' then ParamFlags := ParamFlags or PARAMFLAG_FRETVAL;
        
        ElemDesc.paramdesc.wParamFlags := ParamFlags;
        
        // Kopiowanie deskryptora do tablicy
        Move(ElemDesc, PByteArray(FuncDesc.lprgelemdescParam)^[J * SizeOf(tagELEMDESC)], SizeOf(tagELEMDESC));
      end;
    end;

    // Dodawanie metody do interfejsu
    HRes := CreateTypeInfo.AddFuncDesc(I, FuncDesc);
    
    // Ustawianie nazw parametrów
    if Meth.Params.Count > 0 then
    begin
      CreateTypeInfo.SetFuncAndParamNames(I, @ParamNames[0], Meth.Params.Count + 1);
      
      // Czyszczenie pamieci
      for J := 1 to Meth.Params.Count do
        SysFreeString(ParamNames[J]);
      FreeMem(FuncDesc.lprgelemdescParam);
    end;
  end;
  
  CreateTypeInfo.LayOut;
  
  // Zapisz do cache (dla coclass)
  if Succeeded(CreateTypeInfo.QueryInterface(IID_ITypeInfo, TypeInfo)) then
  begin
    AddToCache(Intf.Name, TypeInfo);
  end;
end;

procedure TTlbGenerator.GenerateEnum(AstEnum: TIDLEnum);
var
  CreateTypeInfo: ICreateTypeInfo;
  TypeInfo: ITypeInfo;
  HRes: HRESULT;
  I: Integer;
  Mem: TIDLEnumMember;
  VarDesc: tagVARDESC;
  VarVal: Variant;
begin
  HRes := FCreateLib.CreateTypeInfo(PWideChar(WideString(AstEnum.Name)), TKIND_ENUM, CreateTypeInfo);
  if Failed(HRes) then Exit;

  for I := 0 to AstEnum.Members.Count - 1 do
  begin
    Mem := TIDLEnumMember(AstEnum.Members[I]);
    
    FillChar(VarDesc, SizeOf(tagVARDESC), 0);
    VarDesc.memid := I;
    VarDesc.varkind := VAR_CONST;
    VarDesc.elemdescVar.tdesc.vt := VT_I4;
    
    VarVal := Mem.Value;
    VarDesc.lpvarValue := @VarVal;
    
    CreateTypeInfo.AddVarDesc(I, VarDesc);
    CreateTypeInfo.SetVarName(I, PWideChar(WideString(Mem.Name)));
  end;
  
  CreateTypeInfo.LayOut;
  
  if Succeeded(CreateTypeInfo.QueryInterface(IID_ITypeInfo, TypeInfo)) then
    AddToCache(AstEnum.Name, TypeInfo);
end;

procedure TTlbGenerator.GenerateCoclass(AstCoclass: TIDLCoclass);
var
  CreateTypeInfo: ICreateTypeInfo;
  HRes: HRESULT;
  GuidStr: string;
  ClassGuid: TGUID;
  I: Integer;
  Intf: TIDLCoclassInterface;
  TI: ITypeInfo;
  HRef: HREFTYPE;
  Flags: Integer;
begin
  HRef := 0; // Inicjalizacja, zeby uniknac warninga FPC
  HRes := FCreateLib.CreateTypeInfo(PWideChar(WideString(AstCoclass.Name)), TKIND_COCLASS, CreateTypeInfo);
  if Failed(HRes) then Exit;
  
  GuidStr := GetAttributeValue(AstCoclass.Attributes, 'uuid');
  if GuidStr <> '' then
  begin
    StringToGuid(GuidStr, ClassGuid);
    CreateTypeInfo.SetGuid(ClassGuid);
  end;
  
  for I := 0 to AstCoclass.Interfaces.Count - 1 do
  begin
    Intf := TIDLCoclassInterface(AstCoclass.Interfaces[I]);
    TI := FindInCache(Intf.Name);
    
    if Assigned(TI) then
    begin
      if Succeeded(CreateTypeInfo.AddRefTypeInfo(TI, HRef)) then
      begin
        CreateTypeInfo.AddImplType(I, HRef);
        
        Flags := 0;
        if Intf.IsDefault then Flags := Flags or IMPLTYPEFLAG_FDEFAULT;
        if Intf.IsSource then Flags := Flags or IMPLTYPEFLAG_FSOURCE;
        
        if Flags <> 0 then
          CreateTypeInfo.SetImplTypeFlags(I, Flags);
      end;
    end
    else
      WriteLn('Ostrzezenie: Nie znaleziono interfejsu ', Intf.Name, ' dla coclass ', AstCoclass.Name);
  end;
  
  CreateTypeInfo.LayOut;
end;

procedure TTlbGenerator.Generate(AstLib: TIDLLibrary);
var
  I: Integer;
begin
  SetLength(FCache, 0);
  CoInitialize(nil);
  try
    GenerateLibrary(AstLib);
    LoadImports(AstLib.Imports);
    
    // 1. Generowanie Struktur
    for I := 0 to AstLib.Structs.Count - 1 do
      GenerateStruct(TIDLStruct(AstLib.Structs[I]));

    // 2. Generowanie Enumów
    for I := 0 to AstLib.Enums.Count - 1 do
      GenerateEnum(TIDLEnum(AstLib.Enums[I]));
    
    // 3. Generowanie Interfejsów
    for I := 0 to AstLib.Interfaces.Count - 1 do
      GenerateInterface(TIDLInterface(AstLib.Interfaces[I]), False); // lub True w zależności od wewn struktury, uprościliśmy
      
    // 4. Generowanie Coclassów (muszą mieć już wygenerowane ITypeInfo interfejsów!)
    for I := 0 to AstLib.Coclasses.Count - 1 do
      GenerateCoclass(TIDLCoclass(AstLib.Coclasses[I]));

    // Zapis pliku
    FCreateLib.SaveAllChanges;
  finally
    SetLength(FCache, 0);
    CoUninitialize;
  end;
end;

end.
