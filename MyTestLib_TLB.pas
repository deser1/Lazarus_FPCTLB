unit MyTestLib_TLB;

// Wygenerowane automatycznie przez FPCTLB

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ActiveX, ComObj, Variants;

const
  MyTestLibMajorVersion = 1;
  MyTestLibMinorVersion = 0;
  LIBID_MyTestLib: TGUID = '{12345678-1234-1234-1234-1234567890AB}';

type
  MyColor = TOleEnum;
const
  ColorRed = 1;
  ColorGreen = 2;
  ColorBlue = 5;

type
  PMyDataStruct = ^MyDataStruct;

  MyDataStruct = record
    id: Integer;
    description: WideString;
  end;

type
  // Deklaracje wyprzedzające interfejsów
  IMyInterface = interface;
  IMyEvents = interface;

type
  // Interfejs IMyInterface
  IMyInterface = interface(IUnknown)
    ['{87654321-4321-4321-4321-BA0987654321}']
    function SayHello(name: WideString; greeting: PWideString): HRESULT; safecall;
    function GetColor(colorValue: PInteger): HRESULT; safecall;
    function ProcessData(data: PMyDataStruct; results: PSafeArray): HRESULT; safecall;
  end;

  // Interfejs IMyEvents
  IMyEvents = interface(IUnknown)
    ['{99999999-4321-4321-4321-BA0987654321}']
    function OnClick(x: Integer; y: Integer): HRESULT; safecall;
  end;

const
  CLASS_MyComponent: TGUID = '{11111111-2222-3333-4444-555555555555}';

implementation

end.
