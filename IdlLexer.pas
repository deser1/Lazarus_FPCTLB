unit IdlLexer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TTokenKind = (
    tkEOF,
    tkIdentifier,
    tkString,
    tkNumber,
    tkGUID,        // XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    tkLBracket,    // [
    tkRBracket,    // ]
    tkLParen,      // (
    tkRParen,      // )
    tkLBrace,      // {
    tkRBrace,      // }
    tkComma,       // ,
    tkColon,       // :
    tkSemiColon,   // ;
    tkEqual,       // =
    tkStar,        // *
    tkUnknown
  );

  TToken = record
    Kind: TTokenKind;
    Text: string;
    Line: Integer;
    Column: Integer;
  end;

  TIdlLexer = class
  private
    FInput: string;
    FPos: Integer;
    FLine: Integer;
    FColumn: Integer;
    FLength: Integer;

    function PeekChar: Char;
    function GetChar: Char;
    procedure Advance;
    procedure SkipWhitespaceAndComments;
    function ReadIdentifier: string;
    function ReadString: string;
    function ReadNumber: string;
    function IsGUIDAhead: Boolean;
    function ReadGUID: string;
  public
    constructor Create(const AInput: string);
    function NextToken: TToken;
  end;

function TokenKindToStr(Kind: TTokenKind): string;

implementation

function TokenKindToStr(Kind: TTokenKind): string;
begin
  case Kind of
    tkEOF: Result := 'EOF';
    tkIdentifier: Result := 'Identifier';
    tkString: Result := 'String';
    tkNumber: Result := 'Number';
    tkGUID: Result := 'GUID';
    tkLBracket: Result := 'LBracket ([)';
    tkRBracket: Result := 'RBracket (])';
    tkLParen: Result := 'LParen (()';
    tkRParen: Result := 'RParen ())';
    tkLBrace: Result := 'LBrace ({)';
    tkRBrace: Result := 'RBrace (})';
    tkComma: Result := 'Comma (,)';
    tkColon: Result := 'Colon (:)';
    tkSemiColon: Result := 'SemiColon (;)';
    tkEqual: Result := 'Equal (=)';
    tkStar: Result := 'Star (*)';
    tkUnknown: Result := 'Unknown';
  else
    Result := '???';
  end;
end;

{ TIdlLexer }

constructor TIdlLexer.Create(const AInput: string);
begin
  FInput := AInput;
  FLength := Length(AInput);
  FPos := 1;
  FLine := 1;
  FColumn := 1;
end;

function TIdlLexer.PeekChar: Char;
begin
  if FPos <= FLength then
    Result := FInput[FPos]
  else
    Result := #0;
end;

function TIdlLexer.GetChar: Char;
begin
  Result := PeekChar;
  Advance;
end;

procedure TIdlLexer.Advance;
begin
  if FPos <= FLength then
  begin
    if FInput[FPos] = #10 then
    begin
      Inc(FLine);
      FColumn := 1;
    end
    else
    begin
      Inc(FColumn);
    end;
    Inc(FPos);
  end;
end;

procedure TIdlLexer.SkipWhitespaceAndComments;
var
  C, NextC: Char;
begin
  while FPos <= FLength do
  begin
    C := PeekChar;
    
    // Skip whitespace
    if C in [#9, #10, #13, ' '] then
    begin
      Advance;
      Continue;
    end;

    // Check for comments
    if C = '/' then
    begin
      if FPos < FLength then
        NextC := FInput[FPos + 1]
      else
        NextC := #0;

      // Single-line comment //
      if NextC = '/' then
      begin
        Advance; // Skip '/'
        Advance; // Skip '/'
        while (FPos <= FLength) and (PeekChar <> #10) and (PeekChar <> #13) do
          Advance;
        Continue;
      end
      // Multi-line comment /* ... */
      else if NextC = '*' then
      begin
        Advance; // Skip '/'
        Advance; // Skip '*'
        while FPos <= FLength do
        begin
          if (PeekChar = '*') and (FPos < FLength) and (FInput[FPos + 1] = '/') then
          begin
            Advance; // Skip '*'
            Advance; // Skip '/'
            Break;
          end;
          Advance;
        end;
        Continue;
      end;
    end;

    Break; // Not a whitespace or comment
  end;
end;

function TIdlLexer.ReadIdentifier: string;
var
  StartPos: Integer;
begin
  StartPos := FPos;
  while (FPos <= FLength) and (PeekChar in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
    Advance;
  Result := Copy(FInput, StartPos, FPos - StartPos);
end;

function TIdlLexer.ReadString: string;
var
  StartPos: Integer;
begin
  Advance; // Skip opening quote '"'
  StartPos := FPos;
  while (FPos <= FLength) and (PeekChar <> '"') do
  begin
    if PeekChar = '\' then // Handle escape characters naively
      Advance;
    Advance;
  end;
  Result := Copy(FInput, StartPos, FPos - StartPos);
  if PeekChar = '"' then
    Advance; // Skip closing quote
end;

function TIdlLexer.ReadNumber: string;
var
  StartPos: Integer;
begin
  StartPos := FPos;
  // Bardzo proste czytanie liczby (obsługuje m.in. hex np. 0x123)
  while (FPos <= FLength) and (PeekChar in ['0'..'9', 'a'..'f', 'A'..'F', 'x', 'X', '.']) do
    Advance;
  Result := Copy(FInput, StartPos, FPos - StartPos);
end;

function TIdlLexer.IsGUIDAhead: Boolean;
var
  I: Integer;
  C: Char;
begin
  if FPos + 35 > FLength then Exit(False);
  for I := 0 to 35 do
  begin
    C := FInput[FPos + I];
    if I in [8, 13, 18, 23] then
    begin
      if C <> '-' then Exit(False);
    end
    else
    begin
      if not (C in ['0'..'9', 'a'..'f', 'A'..'F']) then Exit(False);
    end;
  end;
  Result := True;
end;

function TIdlLexer.ReadGUID: string;
var
  I: Integer;
begin
  Result := Copy(FInput, FPos, 36);
  for I := 1 to 36 do Advance;
end;

function TIdlLexer.NextToken: TToken;
var
  C: Char;
begin
  SkipWhitespaceAndComments;

  Result.Line := FLine;
  Result.Column := FColumn;

  if FPos > FLength then
  begin
    Result.Kind := tkEOF;
    Result.Text := '';
    Exit;
  end;

  C := PeekChar;

  if IsGUIDAhead then
  begin
    Result.Kind := tkGUID;
    Result.Text := ReadGUID;
    Exit;
  end;

  case C of
    'a'..'z', 'A'..'Z', '_':
      begin
        Result.Kind := tkIdentifier;
        Result.Text := ReadIdentifier;
      end;
    '0'..'9':
      begin
        Result.Kind := tkNumber;
        Result.Text := ReadNumber;
      end;
    '"':
      begin
        Result.Kind := tkString;
        Result.Text := ReadString;
      end;
    '[': begin Result.Kind := tkLBracket; Result.Text := '['; Advance; end;
    ']': begin Result.Kind := tkRBracket; Result.Text := ']'; Advance; end;
    '(': begin Result.Kind := tkLParen; Result.Text := '('; Advance; end;
    ')': begin Result.Kind := tkRParen; Result.Text := ')'; Advance; end;
    '{': begin Result.Kind := tkLBrace; Result.Text := '{'; Advance; end;
    '}': begin Result.Kind := tkRBrace; Result.Text := '}'; Advance; end;
    ',': begin Result.Kind := tkComma; Result.Text := ','; Advance; end;
    ':': begin Result.Kind := tkColon; Result.Text := ':'; Advance; end;
    ';': begin Result.Kind := tkSemiColon; Result.Text := ';'; Advance; end;
    '=': begin Result.Kind := tkEqual; Result.Text := '='; Advance; end;
    '*': begin Result.Kind := tkStar; Result.Text := '*'; Advance; end;
  else
    begin
      Result.Kind := tkUnknown;
      Result.Text := C;
      Advance;
    end;
  end;
end;

end.
