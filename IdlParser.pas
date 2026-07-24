unit IdlParser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, IdlLexer, IdlAst;

type
  EIdlParserException = class(Exception);

  TIdlParser = class
  private
    FLexer: TIdlLexer;
    FCurrent: TToken;
    procedure Advance;
    procedure Match(Kind: TTokenKind);
    
    function ParseAttributes: TObjectList;
    function ParseParam: TIDLParam;
    function ParseMethod: TIDLMethod;
    function ParseInterface(Attributes: TObjectList; IsDisp: Boolean = False): TIDLInterface;
    function ParseType: string;
    function ParseEnum(Attributes: TObjectList): TIDLEnum;
    function ParseCoclass(Attributes: TObjectList): TIDLCoclass;
    function ParseStruct(Attributes: TObjectList): TIDLStruct;
  public
    constructor Create(ALexer: TIdlLexer);
    function ParseLibrary: TIDLLibrary;
    property Current: TToken read FCurrent;
  end;

implementation

{ TIdlParser }

constructor TIdlParser.Create(ALexer: TIdlLexer);
begin
  FLexer := ALexer;
  Advance; // Pobierz pierwszy token
end;

procedure TIdlParser.Advance;
begin
  FCurrent := FLexer.NextToken;
end;

procedure TIdlParser.Match(Kind: TTokenKind);
begin
  if FCurrent.Kind = Kind then
  begin
    Advance
  end
  else
    raise EIdlParserException.CreateFmt('Oczekiwano tokenu %s, a otrzymano %s (Linia %d, Kolumna %d)', 
      [TokenKindToStr(Kind), TokenKindToStr(FCurrent.Kind), FCurrent.Line, FCurrent.Column]);
end;

function TIdlParser.ParseAttributes: TObjectList;
var
  Attr: TIDLAttribute;
begin
  Result := TObjectList.Create(True);
  
  if FCurrent.Kind <> tkLBracket then Exit;
  
  Advance; // Pomijamy '['
  
  while (FCurrent.Kind <> tkRBracket) and (FCurrent.Kind <> tkEOF) do
  begin
    if FCurrent.Kind = tkIdentifier then
    begin
      Attr := TIDLAttribute.Create;
      Attr.Name := FCurrent.Text;
      Advance;
      
      // Sprawdzamy czy atrybut ma wartość np. uuid(...)
      if FCurrent.Kind = tkLParen then
      begin
        Advance; // Pomijamy '('
        
        // Wartość atrybutu może być GUIDem, stringiem, liczbą itp.
        if FCurrent.Kind in [tkGUID, tkString, tkNumber, tkIdentifier] then
        begin
          Attr.Value := FCurrent.Text;
          Advance;
        end;
        
        Match(tkRParen);
      end;
      
      Result.Add(Attr);
    end;
    
    if FCurrent.Kind = tkComma then
      Advance
    else if FCurrent.Kind <> tkRBracket then
      Advance; // Pomijamy nierozpoznane tokeny wewnątrz atrybutów dla odporności
  end;
  
  Match(tkRBracket);
end;

function TIdlParser.ParseType: string;
begin
  Result := '';
  
  if (FCurrent.Kind = tkIdentifier) and SameText(FCurrent.Text, 'SAFEARRAY') then
  begin
    Advance;
    Match(tkLParen);
    Result := 'SAFEARRAY(' + Self.ParseType + ')';
    Match(tkRParen);
  end
  else if FCurrent.Kind = tkIdentifier then
  begin
    Result := FCurrent.Text;
    Advance;
  end;
  
  // Obsługa wskaźników np. long**
  while FCurrent.Kind = tkStar do
  begin
    Result := Result + '*';
    Advance;
  end;
end;

function TIdlParser.ParseParam: TIDLParam;
begin
  Result := TIDLParam.Create;
  
  // Atrybuty np. [in]
  Result.Attributes.Free;
  Result.Attributes := ParseAttributes;
  
  // Typ danych np. BSTR
  Result.DataType := ParseType;
  
  // Nazwa parametru
  if FCurrent.Kind = tkIdentifier then
  begin
    Result.Name := FCurrent.Text;
    Advance;
  end;
end;

function TIdlParser.ParseMethod: TIDLMethod;
begin
  Result := TIDLMethod.Create;
  
  // Atrybuty np. [id(1)]
  Result.Attributes.Free;
  Result.Attributes := ParseAttributes;
  
  // Typ zwracany np. HRESULT
  Result.ReturnType := ParseType;
  
  // Nazwa metody
  if FCurrent.Kind = tkIdentifier then
  begin
    Result.Name := FCurrent.Text;
    Advance;
  end;
  
  Match(tkLParen);
  
  // Parametry
  while (FCurrent.Kind <> tkRParen) and (FCurrent.Kind <> tkEOF) do
  begin
    Result.Params.Add(ParseParam);
    
    if FCurrent.Kind = tkComma then
      Advance
    else
      Break;
  end;
  
  Match(tkRParen);
  Match(tkSemiColon);
end;

function TIdlParser.ParseInterface(Attributes: TObjectList; IsDisp: Boolean): TIDLInterface;
begin
  Result := TIDLInterface.Create;
  
  // Przejmujemy atrybuty przekazane z wyższego poziomu
  Result.Attributes.Free;
  Result.Attributes := Attributes;
  
  Match(tkIdentifier); // Oczekujemy 'interface' lub 'dispinterface'
  
  if FCurrent.Kind = tkIdentifier then
  begin
    Result.Name := FCurrent.Text;
    Advance;
  end;
  
  if FCurrent.Kind = tkColon then
  begin
    Advance;
    if FCurrent.Kind = tkIdentifier then
    begin
      Result.BaseInterface := FCurrent.Text;
      Advance;
    end;
  end;
  
  Match(tkLBrace);
  
  while (FCurrent.Kind <> tkRBrace) and (FCurrent.Kind <> tkEOF) do
  begin
    // Uproszczona obsługa dispinterface (pomijamy etykiety properties: i methods:)
    if IsDisp and (FCurrent.Kind = tkIdentifier) and ((FCurrent.Text = 'properties') or (FCurrent.Text = 'methods')) then
    begin
      Advance;
      Match(tkColon);
      Continue;
    end;
    
    Result.Methods.Add(ParseMethod);
  end;
  
  Match(tkRBrace);
end;

function TIdlParser.ParseEnum(Attributes: TObjectList): TIDLEnum;
var
  Mem: TIDLEnumMember;
  Counter: Integer;
begin
  Result := TIDLEnum.Create;
  Result.Attributes.Free;
  Result.Attributes := Attributes;
  
  Match(tkIdentifier); // 'enum'
  
  // Opcjonalna nazwa po enum (np. typedef enum MyEnumName { ... })
  if FCurrent.Kind = tkIdentifier then
    Advance;
    
  Match(tkLBrace);
  
  Counter := 0;
  while (FCurrent.Kind <> tkRBrace) and (FCurrent.Kind <> tkEOF) do
  begin
    Mem := TIDLEnumMember.Create;
    
    if FCurrent.Kind = tkIdentifier then
    begin
      Mem.Name := FCurrent.Text;
      Advance;
    end;
    
    if FCurrent.Kind = tkEqual then
    begin
      Advance;
      Mem.Value := StrToIntDef(FCurrent.Text, Counter);
      if FCurrent.Kind = tkNumber then
        Advance;
      Counter := Mem.Value;
    end
    else
      Mem.Value := Counter;
      
    Result.Members.Add(Mem);
    Inc(Counter);
    
    if FCurrent.Kind = tkComma then
      Advance
    else
      Break;
  end;
  
  Match(tkRBrace);
  
  if FCurrent.Kind = tkIdentifier then
  begin
    Result.Name := FCurrent.Text;
    Advance;
  end;
  
  Match(tkSemiColon);
end;

function TIdlParser.ParseCoclass(Attributes: TObjectList): TIDLCoclass;
var
  Intf: TIDLCoclassInterface;
  Attrs: TObjectList;
begin
  Result := TIDLCoclass.Create;
  Result.Attributes.Free;
  Result.Attributes := Attributes;
  
  Match(tkIdentifier); // 'coclass'
  
  if FCurrent.Kind = tkIdentifier then
  begin
    Result.Name := FCurrent.Text;
    Advance;
  end;
  
  Match(tkLBrace);
  
  while (FCurrent.Kind <> tkRBrace) and (FCurrent.Kind <> tkEOF) do
  begin
    Attrs := ParseAttributes;
    
    Intf := TIDLCoclassInterface.Create;
    Intf.IsDefault := False;
    Intf.IsSource := False;
    
    // Sprawdzamy atrybuty interfejsu (np. [default])
    if Attrs.Count > 0 then
    begin
      if TIDLAttribute(Attrs[0]).Name = 'default' then Intf.IsDefault := True;
      if TIDLAttribute(Attrs[0]).Name = 'source' then Intf.IsSource := True;
    end;
    Attrs.Free;
    
    if (FCurrent.Kind = tkIdentifier) and ((FCurrent.Text = 'interface') or (FCurrent.Text = 'dispinterface')) then
      Advance;
      
    if FCurrent.Kind = tkIdentifier then
    begin
      Intf.Name := FCurrent.Text;
      Advance;
    end;
    
    Match(tkSemiColon);
    Result.Interfaces.Add(Intf);
  end;
  
  Match(tkRBrace);
  if FCurrent.Kind = tkSemiColon then
    Advance;
end;

function TIdlParser.ParseStruct(Attributes: TObjectList): TIDLStruct;
var
  Mem: TIDLStructMember;
begin
  Result := TIDLStruct.Create;
  
  Match(tkIdentifier); // 'struct'
  
  if FCurrent.Kind = tkIdentifier then
  begin
    Result.Name := FCurrent.Text;
    Advance;
  end;
  
  Match(tkLBrace);
  
  while (FCurrent.Kind <> tkRBrace) and (FCurrent.Kind <> tkEOF) do
  begin
    Mem := TIDLStructMember.Create;
    Mem.DataType := ParseType;
    
    if FCurrent.Kind = tkIdentifier then
    begin
      Mem.Name := FCurrent.Text;
      Advance;
    end;
    
    Result.Members.Add(Mem);
    Match(tkSemiColon);
  end;
  
  Match(tkRBrace);
  
  if FCurrent.Kind = tkIdentifier then
  begin
    if Result.Name = '' then Result.Name := FCurrent.Text;
    Advance;
  end;
  
  Match(tkSemiColon);
end;

function TIdlParser.ParseLibrary: TIDLLibrary;
var
  Attrs: TObjectList;
begin
  Result := TIDLLibrary.Create;
  
  // Główne atrybuty biblioteki
  Result.Attributes.Free;
  Result.Attributes := ParseAttributes;
  
  Match(tkIdentifier); // Oczekujemy 'library'
  
  if FCurrent.Kind = tkIdentifier then
  begin
    Result.Name := FCurrent.Text;
    Advance;
  end;
  
  Match(tkLBrace);
  
  while (FCurrent.Kind <> tkRBrace) and (FCurrent.Kind <> tkEOF) do
  begin
    if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'importlib') then
    begin
      Advance; Match(tkLParen); 
      if FCurrent.Kind = tkString then
      begin
        Result.Imports.Add(FCurrent.Text);
      end;
      Advance; // String
      Match(tkRParen); Match(tkSemiColon);
      Continue;
    end;
    
    // Parowanie atrybutów dla interfejsów / coclass
    Attrs := ParseAttributes;
    
    if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'interface') then
    begin
      Result.Interfaces.Add(ParseInterface(Attrs, False));
    end
    else if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'dispinterface') then
    begin
      Result.Interfaces.Add(ParseInterface(Attrs, True));
    end
    else if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'typedef') then
    begin
      Advance; // pomijamy 'typedef'
      if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'enum') then
        Result.Enums.Add(ParseEnum(Attrs))
      else if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'struct') then
        Result.Structs.Add(ParseStruct(Attrs))
      else
      begin
        Attrs.Free;
        Advance;
      end;
    end
    else if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'struct') then
    begin
      Result.Structs.Add(ParseStruct(Attrs));
    end
    else if (FCurrent.Kind = tkIdentifier) and (FCurrent.Text = 'coclass') then
    begin
      Result.Coclasses.Add(ParseCoclass(Attrs));
    end
    else
    begin
      Attrs.Free;
      Advance; // Pomijamy nieznane tokeny na poziomie library
    end;
  end;
  
  Match(tkRBrace);
end;

end.
