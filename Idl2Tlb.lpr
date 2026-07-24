program Idl2Tlb;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, IdlLexer, IdlAst, IdlParser, TlbGenerator, PasGenerator;

procedure CompileIdlToTlb(const InputIdlPath, OutputTlbPath, OutputPasPath: string);
var
  FileStream: TStringStream;
  IdlCode: string;
  Lexer: TIdlLexer;
  Parser: TIdlParser;
  Generator: TTlbGenerator;
  PasGen: TPasGenerator;
  LibAst: TIDLLibrary;
begin
  WriteLn('Czytanie pliku: ', InputIdlPath);
  FileStream := TStringStream.Create('');
  try
    FileStream.LoadFromFile(InputIdlPath);
    IdlCode := FileStream.DataString;
  finally
    FileStream.Free;
  end;

  WriteLn('Analiza leksykalna i parsowanie (Frontend)...');
  Lexer := TIdlLexer.Create(IdlCode);
  Parser := TIdlParser.Create(Lexer);
  try
    LibAst := Parser.ParseLibrary;
    try
      WriteLn('Generowanie binarnego pliku TLB (Backend)...');
      Generator := TTlbGenerator.Create(OutputTlbPath);
      try
        Generator.Generate(LibAst);
        WriteLn('Sukces! Plik zapisany: ', OutputTlbPath);
      finally
        Generator.Free;
      end;
      
      if OutputPasPath <> '' then
      begin
        WriteLn('Generowanie pliku Pascal (_TLB.pas)...');
        PasGen := TPasGenerator.Create;
        try
          PasGen.Generate(LibAst, OutputPasPath);
          WriteLn('Sukces! Kod zrodlowy zapisany: ', OutputPasPath);
        finally
          PasGen.Free;
        end;
      end;
    finally
      LibAst.Free;
    end;
  finally
    Parser.Free;
    Lexer.Free;
  end;
end;

var
  InputFile, OutputFile, PasFile: string;
begin
  WriteLn('=== IDL to TLB & PAS Compiler (Free Pascal) ===');
  WriteLn;

  if ParamCount < 2 then
  begin
    WriteLn('Uzycie: Idl2Tlb.exe <plik_wejsciowy.idl> <plik_wyjsciowy.tlb> [plik_wyjsciowy_tlb.pas]');
    WriteLn('Przyklad: Idl2Tlb.exe Sample.idl Sample.tlb Sample_TLB.pas');
    Exit;
  end;

  InputFile := ParamStr(1);
  OutputFile := ParamStr(2);
  if ParamCount >= 3 then
    PasFile := ParamStr(3)
  else
    PasFile := '';

  if not FileExists(InputFile) then
  begin
    WriteLn('Blad: Plik wejsciowy nie istnieje!');
    Exit;
  end;

  try
    CompileIdlToTlb(InputFile, OutputFile, PasFile);
  except
    on E: Exception do
      WriteLn('Blad krytyczny: ', E.Message);
  end;
end.
