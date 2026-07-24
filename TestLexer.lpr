program TestLexer;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, IdlLexer;

const
  SampleIDL = 
    '// Przykładowy plik IDL' + sLineBreak +
    '[' + sLineBreak +
    '  uuid(12345678-1234-1234-1234-1234567890AB),' + sLineBreak +
    '  version(1.0),' + sLineBreak +
    '  helpstring("Moja Biblioteka Typow")' + sLineBreak +
    ']' + sLineBreak +
    'library MyLib' + sLineBreak +
    '{' + sLineBreak +
    '  importlib("stdole2.tlb");' + sLineBreak +
    '' + sLineBreak +
    '  /* Interfejs testowy */' + sLineBreak +
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

var
  Lexer: TIdlLexer;
  Tok: TToken;
begin
  WriteLn('--- Rozpoczynam test Lexera IDL ---');
  WriteLn('Kod zrodlowy:');
  WriteLn(SampleIDL);
  WriteLn('-----------------------------------');
  WriteLn('Tokeny:');
  
  Lexer := TIdlLexer.Create(SampleIDL);
  try
    repeat
      Tok := Lexer.NextToken;
      WriteLn(Format('Linia: %3d | Kol: %3d | Typ: %-15s | Wartosc: "%s"', 
        [Tok.Line, Tok.Column, TokenKindToStr(Tok.Kind), Tok.Text]));
    until Tok.Kind = tkEOF;
  finally
    Lexer.Free;
  end;
  
  WriteLn('--- Koniec testu ---');
end.
