unit IdlAst;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs;

type
  TIDLAttribute = class
  public
    Name: string;
    Value: string;
  end;

  TIDLParam = class
  public
    Name: string;
    DataType: string;
    Attributes: TObjectList; // Lista TIDLAttribute
    constructor Create;
    destructor Destroy; override;
  end;

  TIDLMethod = class
  public
    Name: string;
    ReturnType: string;
    Attributes: TObjectList; // Lista TIDLAttribute
    Params: TObjectList;     // Lista TIDLParam
    constructor Create;
    destructor Destroy; override;
  end;

  TIDLInterface = class
  public
    Name: string;
    BaseInterface: string;
    Attributes: TObjectList; // Lista TIDLAttribute
    Methods: TObjectList;    // Lista TIDLMethod
    constructor Create;
    destructor Destroy; override;
  end;

  TIDLEnumMember = class
  public
    Name: string;
    Value: Integer;
  end;

  TIDLEnum = class
  public
    Name: string;
    Attributes: TObjectList; // Lista TIDLAttribute
    Members: TObjectList;    // Lista TIDLEnumMember
    constructor Create;
    destructor Destroy; override;
  end;

  TIDLCoclassInterface = class
  public
    Name: string;
    IsDefault: Boolean;
    IsSource: Boolean;
  end;

  TIDLCoclass = class
  public
    Name: string;
    Attributes: TObjectList;
    Interfaces: TObjectList; // Lista TIDLCoclassInterface
    constructor Create;
    destructor Destroy; override;
  end;

  TIDLStructMember = class
  public
    Name: string;
    DataType: string;
  end;

  TIDLStruct = class
  public
    Name: string;
    Members: TObjectList; // Lista TIDLStructMember
    constructor Create;
    destructor Destroy; override;
  end;

  TIDLLibrary = class
  public
    Name: string;
    Attributes: TObjectList; // Lista TIDLAttribute
    Interfaces: TObjectList; // Lista TIDLInterface
    Enums: TObjectList;      // Lista TIDLEnum
    Coclasses: TObjectList;  // Lista TIDLCoclass
    Structs: TObjectList;    // Lista TIDLStruct
    Imports: TStringList;    // Lista ścieżek z importlib
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TIDLParam }

constructor TIDLParam.Create;
begin
  Attributes := TObjectList.Create(True);
end;

destructor TIDLParam.Destroy;
begin
  Attributes.Free;
  inherited Destroy;
end;

{ TIDLMethod }

constructor TIDLMethod.Create;
begin
  Attributes := TObjectList.Create(True);
  Params := TObjectList.Create(True);
end;

destructor TIDLMethod.Destroy;
begin
  Attributes.Free;
  Params.Free;
  inherited Destroy;
end;

{ TIDLInterface }

constructor TIDLInterface.Create;
begin
  Attributes := TObjectList.Create(True);
  Methods := TObjectList.Create(True);
end;

destructor TIDLInterface.Destroy;
begin
  Attributes.Free;
  Methods.Free;
  inherited Destroy;
end;

{ TIDLEnum }

constructor TIDLEnum.Create;
begin
  Attributes := TObjectList.Create(True);
  Members := TObjectList.Create(True);
end;

destructor TIDLEnum.Destroy;
begin
  Attributes.Free;
  Members.Free;
  inherited Destroy;
end;

{ TIDLCoclass }

constructor TIDLCoclass.Create;
begin
  Attributes := TObjectList.Create(True);
  Interfaces := TObjectList.Create(True);
end;

destructor TIDLCoclass.Destroy;
begin
  Attributes.Free;
  Interfaces.Free;
  inherited Destroy;
end;

{ TIDLStruct }

constructor TIDLStruct.Create;
begin
  Members := TObjectList.Create(True);
end;

destructor TIDLStruct.Destroy;
begin
  Members.Free;
  inherited Destroy;
end;

{ TIDLLibrary }

constructor TIDLLibrary.Create;
begin
  Attributes := TObjectList.Create(True);
  Interfaces := TObjectList.Create(True);
  Enums := TObjectList.Create(True);
  Coclasses := TObjectList.Create(True);
  Structs := TObjectList.Create(True);
  Imports := TStringList.Create;
end;

destructor TIDLLibrary.Destroy;
begin
  Attributes.Free;
  Interfaces.Free;
  Enums.Free;
  Coclasses.Free;
  Structs.Free;
  Imports.Free;
  inherited Destroy;
end;

end.
