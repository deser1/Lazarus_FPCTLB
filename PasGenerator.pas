unit PasGenerator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IdlAst;

type
  TPasGenerator = class
  private
    FOutput: TStringList;
    
    function MapTypeToPascal(const IdlType: string): string;
    function FormatGuid(const GuidStr: string): string;
    function GetAttributeValue(Attrs: TList; const Name: string; const DefaultVal: string = ''): string;
    
    procedure GenerateHeader(Lib: TIDLLibrary);
    procedure GenerateEnums(Lib: TIDLLibrary);
    procedure GenerateStructs(Lib: TIDLLibrary);
    procedure GenerateForwardDecls(Lib: TIDLLibrary);
    procedure GenerateInterfaces(Lib: TIDLLibrary);
    procedure GenerateCoclasses(Lib: TIDLLibrary);
    procedure GenerateFooter;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Generate(AstLib: TIDLLibrary; const FilePath: string);
  end;

implementation

constructor TPasGenerator.Create;
begin
  FOutput := TStringList.Create;
end;

destructor TPasGenerator.Destroy;
begin
  FOutput.Free;
  inherited Destroy;
end;

function TPasGenerator.GetAttributeValue(Attrs: TList; const Name: string; const DefaultVal: string): string;
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

function TPasGenerator.FormatGuid(const GuidStr: string): string;
begin
  Result := GuidStr;
  if Result = '' then Exit;
  if Result[1] <> '{' then
    Result := '{' + Result + '}';
end;

function TPasGenerator.MapTypeToPascal(const IdlType: string): string;
var
  CleanName: string;
  PtrLevel: Integer;
  IsSafeArray: Boolean;
begin
  CleanName := Trim(IdlType);
  PtrLevel := 0;
  IsSafeArray := False;
  
  if Pos('SAFEARRAY(', CleanName) > 0 then
  begin
    IsSafeArray := True;
    CleanName := StringReplace(CleanName, 'SAFEARRAY(', '', [rfIgnoreCase]);
    CleanName := StringReplace(CleanName, ')', '', []);
  end;

  while (Length(CleanName) > 0) and (CleanName[Length(CleanName)] = '*') do
  begin
    Inc(PtrLevel);
    SetLength(CleanName, Length(CleanName) - 1);
  end;

  CleanName := Trim(CleanName);

  if SameText(CleanName, 'long') then Result := 'Integer'
  else if SameText(CleanName, 'short') then Result := 'SmallInt'
  else if SameText(CleanName, 'BSTR') then Result := 'WideString'
  else if SameText(CleanName, 'VARIANT') then Result := 'OleVariant'
  else if SameText(CleanName, 'HRESULT') then Result := 'HRESULT'
  else if SameText(CleanName, 'void') then Result := 'Pointer'
  else Result := CleanName; // Fallback do nazwy interfejsu / enuma

  if IsSafeArray then
    Result := 'PSafeArray'
  else if PtrLevel > 0 then
  begin
    // W Pascalu out, retval często są mapowane na "out parameter: Typ" zamiast "parameter: PTyp"
    // Ale w czystej deklaracji C-podobnej uzyjemy wskaźnika. Dla prostoty generujemy PType.
    if Result = 'Integer' then Result := 'PInteger'
    else if Result = 'WideString' then Result := 'PWideString'
    else if Result = 'OleVariant' then Result := 'POleVariant'
    else if Result = 'HRESULT' then Result := 'PHRESULT'
    else Result := 'P' + Result; // Dodaj 'P' dla pozostałych wskaźników (np. struktur)
  end;
end;

procedure TPasGenerator.GenerateHeader(Lib: TIDLLibrary);
begin
  FOutput.Add('unit ' + Lib.Name + '_TLB;');
  FOutput.Add('');
  FOutput.Add('// Wygenerowane automatycznie przez FPCTLB');
  FOutput.Add('');
  FOutput.Add('{$mode objfpc}{$H+}');
  FOutput.Add('');
  FOutput.Add('interface');
  FOutput.Add('');
  FOutput.Add('uses');
  FOutput.Add('  Classes, SysUtils, ActiveX, ComObj, Variants;');
  FOutput.Add('');
  FOutput.Add('const');
  FOutput.Add('  ' + Lib.Name + 'MajorVersion = 1;');
  FOutput.Add('  ' + Lib.Name + 'MinorVersion = 0;');
  FOutput.Add('  LIBID_' + Lib.Name + ': TGUID = ''' + FormatGuid(GetAttributeValue(Lib.Attributes, 'uuid')) + ''';');
  FOutput.Add('');
end;

procedure TPasGenerator.GenerateEnums(Lib: TIDLLibrary);
var
  I, J: Integer;
  E: TIDLEnum;
  M: TIDLEnumMember;
begin
  if Lib.Enums.Count = 0 then Exit;
  FOutput.Add('type');
  for I := 0 to Lib.Enums.Count - 1 do
  begin
    E := TIDLEnum(Lib.Enums[I]);
    FOutput.Add('  ' + E.Name + ' = TOleEnum;');
    FOutput.Add('const');
    for J := 0 to E.Members.Count - 1 do
    begin
      M := TIDLEnumMember(E.Members[J]);
      FOutput.Add('  ' + M.Name + ' = ' + IntToStr(M.Value) + ';');
    end;
    FOutput.Add('');
  end;
end;

procedure TPasGenerator.GenerateStructs(Lib: TIDLLibrary);
var
  I, J: Integer;
  S: TIDLStruct;
  M: TIDLStructMember;
begin
  if Lib.Structs.Count = 0 then Exit;
  FOutput.Add('type');
  for I := 0 to Lib.Structs.Count - 1 do
  begin
    S := TIDLStruct(Lib.Structs[I]);
    FOutput.Add('  P' + S.Name + ' = ^' + S.Name + ';');
  end;
  FOutput.Add('');
  for I := 0 to Lib.Structs.Count - 1 do
  begin
    S := TIDLStruct(Lib.Structs[I]);
    FOutput.Add('  ' + S.Name + ' = record');
    for J := 0 to S.Members.Count - 1 do
    begin
      M := TIDLStructMember(S.Members[J]);
      FOutput.Add('    ' + M.Name + ': ' + MapTypeToPascal(M.DataType) + ';');
    end;
    FOutput.Add('  end;');
    FOutput.Add('');
  end;
end;

procedure TPasGenerator.GenerateForwardDecls(Lib: TIDLLibrary);
var
  I: Integer;
  Intf: TIDLInterface;
begin
  if Lib.Interfaces.Count = 0 then Exit;
  FOutput.Add('type');
  FOutput.Add('  // Deklaracje wyprzedzające interfejsów');
  for I := 0 to Lib.Interfaces.Count - 1 do
  begin
    Intf := TIDLInterface(Lib.Interfaces[I]);
    FOutput.Add('  ' + Intf.Name + ' = interface;');
  end;
  FOutput.Add('');
end;

procedure TPasGenerator.GenerateInterfaces(Lib: TIDLLibrary);
var
  I, J, K: Integer;
  Intf: TIDLInterface;
  Meth: TIDLMethod;
  Param: TIDLParam;
  Line: string;
  Base: string;
  GuidStr: string;
begin
  if Lib.Interfaces.Count = 0 then Exit;
  FOutput.Add('type');
  for I := 0 to Lib.Interfaces.Count - 1 do
  begin
    Intf := TIDLInterface(Lib.Interfaces[I]);
    
    Base := Intf.BaseInterface;
    if Base = '' then Base := 'IUnknown';
    
    FOutput.Add('  // Interfejs ' + Intf.Name);
    FOutput.Add('  ' + Intf.Name + ' = interface(' + Base + ')');
    
    GuidStr := GetAttributeValue(Intf.Attributes, 'uuid');
    if GuidStr <> '' then
      FOutput.Add('    [''' + FormatGuid(GuidStr) + ''']');
      
    for J := 0 to Intf.Methods.Count - 1 do
    begin
      Meth := TIDLMethod(Intf.Methods[J]);
      Line := '    function ' + Meth.Name;
      if Meth.Params.Count > 0 then
      begin
        Line := Line + '(';
        for K := 0 to Meth.Params.Count - 1 do
        begin
          Param := TIDLParam(Meth.Params[K]);
          Line := Line + Param.Name + ': ' + MapTypeToPascal(Param.DataType);
          if K < Meth.Params.Count - 1 then
            Line := Line + '; ';
        end;
        Line := Line + ')';
      end;
      Line := Line + ': ' + MapTypeToPascal(Meth.ReturnType) + '; safecall;';
      FOutput.Add(Line);
    end;
    
    FOutput.Add('  end;');
    FOutput.Add('');
  end;
end;

procedure TPasGenerator.GenerateCoclasses(Lib: TIDLLibrary);
var
  I: Integer;
  Co: TIDLCoclass;
  GuidStr: string;
begin
  if Lib.Coclasses.Count = 0 then Exit;
  FOutput.Add('const');
  for I := 0 to Lib.Coclasses.Count - 1 do
  begin
    Co := TIDLCoclass(Lib.Coclasses[I]);
    GuidStr := GetAttributeValue(Co.Attributes, 'uuid');
    if GuidStr <> '' then
      FOutput.Add('  CLASS_' + Co.Name + ': TGUID = ''' + FormatGuid(GuidStr) + ''';');
  end;
  FOutput.Add('');
end;

procedure TPasGenerator.GenerateFooter;
begin
  FOutput.Add('implementation');
  FOutput.Add('');
  FOutput.Add('end.');
end;

procedure TPasGenerator.Generate(AstLib: TIDLLibrary; const FilePath: string);
begin
  FOutput.Clear;
  GenerateHeader(AstLib);
  GenerateEnums(AstLib);
  GenerateStructs(AstLib);
  GenerateForwardDecls(AstLib);
  GenerateInterfaces(AstLib);
  GenerateCoclasses(AstLib);
  GenerateFooter;
  
  FOutput.SaveToFile(FilePath);
end;

end.