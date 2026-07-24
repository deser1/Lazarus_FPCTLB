program TestParser;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, IdlLexer, IdlAst, IdlParser;

const
  SampleIDL = 
    '[' + sLineBreak +
    '  uuid(12345678-1234-1234-1234-1234567890AB),' + sLineBreak +
    '  version(1.0),' + sLineBreak +
    '  helpstring("Moja Biblioteka Typow")' + sLineBreak +
    ']' + sLineBreak +
    'library MyLib' + sLineBreak +
    '{' + sLineBreak +
    '  importlib("stdole2.tlb");' + sLineBreak +
    '' + sLineBreak +
    '  [' + sLineBreak +
    '    uuid(87654321-4321-4321-4321-BA0987654321),' + sLineBreak +
    '    object,' + sLineBreak +
    '    oleautomation' + sLineBreak +
    '  ]' + sLineBreak +
    '  interface IMyInterface : IUnknown' + sLineBreak +
    '  {' + sLineBreak +
    '    [id(1)] HRESULT DoSomething([in] BSTR text, [out, retval] long* result);' + sLineBreak +
    '  }' + sLineBreak +
    '}';

procedure PrintAttributes(Prefix: string; Attrs: TObjectList);
var
  I: Integer;
  A: TIDLAttribute;
begin
  for I := 0 to Attrs.Count - 1 do
  begin
    A := TIDLAttribute(Attrs[I]);
    if A.Value <> '' then
      WriteLn(Prefix, 'Atrybut: ', A.Name, ' = ', A.Value)
    else
      WriteLn(Prefix, 'Atrybut: ', A.Name);
  end;
end;

var
  Lexer: TIdlLexer;
  Parser: TIdlParser;
  Lib: TIDLLibrary;
  Intf: TIDLInterface;
  Meth: TIDLMethod;
  Param: TIDLParam;
  I, J, K: Integer;
begin
  WriteLn('--- Rozpoczynam test Parsera IDL ---');
  
  Lexer := TIdlLexer.Create(SampleIDL);
  Parser := TIdlParser.Create(Lexer);
  try
    try
      Lib := Parser.ParseLibrary;
      
      WriteLn('Biblioteka: ', Lib.Name);
      PrintAttributes('  ', Lib.Attributes);
      
      for I := 0 to Lib.Interfaces.Count - 1 do
      begin
        Intf := TIDLInterface(Lib.Interfaces[I]);
        WriteLn('  Interfejs: ', Intf.Name, ' (Baza: ', Intf.BaseInterface, ')');
        PrintAttributes('    ', Intf.Attributes);
        
        for J := 0 to Intf.Methods.Count - 1 do
        begin
          Meth := TIDLMethod(Intf.Methods[J]);
          WriteLn('    Metoda: ', Meth.Name, ' Zwraca: ', Meth.ReturnType);
          PrintAttributes('      ', Meth.Attributes);
          
          for K := 0 to Meth.Params.Count - 1 do
          begin
            Param := TIDLParam(Meth.Params[K]);
            WriteLn('      Parametr: ', Param.Name, ' Typ: ', Param.DataType);
            PrintAttributes('        ', Param.Attributes);
          end;
        end;
      end;
      
      Lib.Free;
    except
      on E: Exception do
        WriteLn('Blad parsowania: ', E.Message);
    end;
  finally
    Parser.Free;
    Lexer.Free;
  end;
  
  WriteLn('--- Koniec testu ---');
end.
