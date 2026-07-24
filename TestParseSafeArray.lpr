program TestParseSafeArray;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, IdlLexer, IdlParser;

const
  Code = 'library MyLib { interface IMyInterface : IUnknown { [id(3)] HRESULT ProcessData([in] MyDataStruct* data, [out, retval] SAFEARRAY(BSTR)* results); } }';

var
  Lexer: TIdlLexer;
  Parser: TIdlParser;
begin
  Lexer := TIdlLexer.Create(Code);
  Parser := TIdlParser.Create(Lexer);
  try
    try
      Parser.ParseLibrary;
      WriteLn('OK. Next Token: ', TokenKindToStr(Parser.Current.Kind), ' "', Parser.Current.Text, '"');
    except
      on E: Exception do WriteLn(E.Message);
    end;
  finally
    Parser.Free;
    Lexer.Free;
  end;
end.