program TestCOM;

{$mode objfpc}{$H+}
{$APPTYPE CONSOLE} // Wymusza na Lazarusie/Windowsie otwarcie widocznego okna konsoli!

uses
  SysUtils, Classes, ComObj, ActiveX, 
  MyTestLib_TLB; // Importujemy nasz wygenerowany plik!

type
  { Tworzymy klasę implementującą nasz interfejs z pliku TLB }
  TMyComponent = class(TInterfacedObject, IMyInterface)
  public
    // Implementacja metod wymaganych przez IMyInterface
    function SayHello(name: WideString; greeting: PWideString): HRESULT; safecall;
    function GetColor(colorValue: PInteger): HRESULT; safecall;
    function ProcessData(data: PMyDataStruct; results: PSafeArray): HRESULT; safecall;
  end;

{ --- Implementacja metod --- }

function TMyComponent.SayHello(name: WideString; greeting: PWideString): HRESULT; safecall;
var
  Answer: WideString;
begin
  Writeln('Wywolano metode SayHello z parametrem: ', name);
  Answer := 'Witaj ' + name + ', to jest odpowiedz z obiektu COM!';
  greeting^ := Answer; // Zwracamy tekst przez wskaźnik
  Result := S_OK;      // Zwracamy kod sukcesu COM
end;

function TMyComponent.GetColor(colorValue: PInteger): HRESULT; safecall;
begin
  colorValue^ := ColorGreen; // Używamy Enuma wygenerowanego przez kompilator!
  Result := S_OK;
end;

function TMyComponent.ProcessData(data: PMyDataStruct; results: PSafeArray): HRESULT; safecall;
begin
  // Unikamy ostrzeżeń o nieużywanych parametrach (Hints)
  if Assigned(data) then { nic };
  if Assigned(results) then { nic };
  
  // Tutaj np. operacje na strukturach
  Result := S_OK;
end;

{ --- Program glowny --- }
var
  MyObj: IMyInterface;
  ReturnedGreeting: WideString;
  ColorValue: Integer;
begin
  try
    Writeln('--- Rozpoczynam test OLE ---');
    
    // 1. Inicjalizacja biblioteki COM
    CoInitialize(nil);

    // 2. Tworzymy instancję naszej klasy i przypisujemy do zmiennej interfejsowej
    MyObj := TMyComponent.Create as IMyInterface;

    // 3. Test metody SayHello
    MyObj.SayHello('Dominik', @ReturnedGreeting);
    Writeln('Wynik SayHello: ', ReturnedGreeting);

    // 4. Test metody GetColor
    MyObj.GetColor(@ColorValue);
    if ColorValue = ColorGreen then
      Writeln('Wynik GetColor: Sukces! Odebrano kolor zielony (', ColorValue, ')');

    // 5. Sprzątanie
    MyObj := nil; // Interfejsy zwalniają się automatycznie (Reference Counting)
    CoUninitialize();

    Writeln('--- Test zakonczony ---');
  except
    on E: Exception do
      Writeln('Wystapil blad: ', E.Message);
  end;

  Writeln('Nacisnij ENTER, aby zakonczyc...');
  Readln;
end.

