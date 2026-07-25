# FPCTLB - Kompilator IDL do TLB / IDL to TLB Compiler

[🇵🇱 Wersja Polska](#-wersja-polska-polish-version) | [🇬🇧 English Version](#-english-version)

---

## 🇵🇱 Wersja Polska (Polish Version)

FPCTLB to napisany od zera (we Free Pascalu) kompilator języka IDL (Interface Definition Language), który generuje binarne pliki bibliotek typów OLE/COM (`.tlb`) oraz gotowe do użycia pliki interfejsów w Object Pascalu (`_TLB.pas`).

### 1. Jak tworzyć pliki IDL

Pliki IDL definiują interfejsy, metody, struktury i klasy COM. Składnia przypomina język C++ z dodatkiem atrybutów w nawiasach kwadratowych `[...]`.

#### Podstawowa struktura

Każdy plik IDL powinien zaczynać się od definicji biblioteki (słowo kluczowe `library`). Biblioteka musi posiadać swój unikalny identyfikator `uuid`.

```cpp
[
  uuid(12345678-1234-1234-1234-1234567890AB),
  version(1.0),
  helpstring("Opis mojej biblioteki")
]
library MojaBiblioteka
{
  importlib("stdole2.tlb"); // Import standardowych typów OLE (np. IUnknown, IDispatch)

  // Tutaj definiujemy typy, interfejsy i klasy
}
```

#### Definiowanie Struktur i Enumów

Wewnątrz bloku `library` możesz zdefiniować typy danych, z których będą korzystać Twoje metody:

```cpp
  typedef enum {
    StatusError = 0,
    StatusOk = 1
  } MyStatus;

  typedef struct {
    long id;
    BSTR name;
  } UserData;
```

#### Definiowanie Interfejsów

Interfejs określa metody, jakie dany obiekt udostępnia. Ważne atrybuty to `uuid`, `oleautomation` oraz `dual` (dla interfejsów wspierających IDispatch). Każda metoda powinna zwracać `HRESULT` i posiadać unikalny `[id(X)]`.

```cpp
  [
    uuid(87654321-4321-4321-4321-BA0987654321),
    oleautomation,
    dual
  ]
  interface IMyInterface : IUnknown
  {
    [id(1)] HRESULT DoSomething([in] long value, [out, retval] long* result);
    [id(2)] HRESULT GetUser([in] long userId, [out, retval] UserData* data);
  }
```

- **[in]** - parametr wejściowy.
- **[out, retval]** - parametr wyjściowy (w Pascalu i C# będzie traktowany jako wynik funkcji).

#### Definiowanie Klasy (Coclass)

Klasa (Coclass) łączy interfejsy w jeden gotowy komponent COM.

```cpp
  [
    uuid(11111111-2222-3333-4444-555555555555)
  ]
  coclass MyComponent
  {
    [default] interface IMyInterface;
  }
```

### 2. Użycie kompilatora (Konsola)

Kompilator wywołuje się przekazując mu plik źródłowy IDL, ścieżkę do pliku wyjściowego TLB oraz opcjonalnie pliku wyjściowego Pascal:

```bash
Idl2Tlb.exe Sample.idl Sample.tlb Sample_TLB.pas
```

### 3. Integracja ze środowiskiem Lazarus IDE

#### Sposób A: Edycja i debugowanie samego kompilatora

Jeśli chcesz modyfikować kod źródłowy kompilatora (pliki `.pas` w tym katalogu):

1. Otwórz plik `Idl2Tlb.lpi` w Lazarusie.
2. Zanim wciśniesz **F9** (Uruchom), musisz podać argumenty. W górnym menu wybierz **Uruchom** -> **Parametry uruchomieniowe...** (_Run_ -> _Run Parameters..._).
3. W polu **Parametry linii poleceń** (_Command line parameters_) wpisz np.:
   `Sample.idl Sample.tlb Sample_TLB.pas`
4. Teraz po wciśnięciu **F9** kompilator poprawnie przetworzy plik, a Ty możesz używać breakpointów w kodzie.

#### Sposób B: Konfiguracja Narzędzia Zewnętrznego (External Tool)

Jeśli po prostu piszesz pliki `.idl` w Lazarusie i chcesz je szybko kompilować do `.tlb` i `_TLB.pas` za pomocą jednego kliknięcia/skrótu:

1. W górnym menu Lazarusa wybierz **Narzędzia** -> **Konfiguruj Narzędzia Zewnętrzne...** (_Tools_ -> _Configure External Tools..._).
2. Kliknij **Dodaj** (_Add_).
3. Skonfiguruj formularz następująco:
   - **Tytuł:** `Kompilator IDL -> TLB`
   - **Program:** Wskaż pełną ścieżkę do zbudowanego pliku `Idl2Tlb.exe` (np. `D:\Projekty\FPCTLB\Idl2Tlb.exe`).
   - **Parametry:** `$EdFile() $EdFile().tlb $EdFile()_TLB.pas`
   - **Katalog roboczy:** `$EdDir()`
4. Zaznacz opcję: **Skanuj wyjście w poszukiwaniu błędów FPC** (_Scan output for FPC errors_), aby komunikaty z naszego parsera były widoczne w oknie wiadomości Lazarusa.
5. Kliknij **OK**.

**Jak tego używać?**
Otwórz dowolny plik `.idl` w edytorze Lazarusa. Następnie wybierz z menu **Narzędzia** -> **Kompilator IDL -> TLB**. Narzędzie w ułamku sekundy przetworzy aktywny plik, a w tym samym folderze pojawią się gotowe pliki `.tlb` oraz `_TLB.pas`.

### 4. Przykładowa implementacja (TestCOM.lpr)

W repozytorium znajduje się plik `TestCOM.lpr`, który pokazuje, jak w praktyce użyć wygenerowanego pliku `_TLB.pas` do stworzenia i wywołania obiektu COM.

Aby go przetestować z poziomu konsoli:

```bash
# 1. Skompiluj plik IDL (wygeneruj .tlb oraz .pas)
.\Idl2Tlb.exe Sample.idl Sample.tlb MyTestLib_TLB.pas

# 2. Skompiluj program testowy
fpc TestCOM.lpr

# 3. Uruchom
.\TestCOM.exe
```

Lub otwórz plik `TestCOM.lpr` w Lazarusie i wciśnij **F9**.

---

## 🇬🇧 English Version

FPCTLB is a from-scratch IDL (Interface Definition Language) compiler written in Free Pascal. It generates binary OLE/COM Type Library files (`.tlb`) and ready-to-use Object Pascal interface files (`_TLB.pas`).

### 1. How to create IDL files

IDL files define COM interfaces, methods, structures, and classes. The syntax is similar to C++ with the addition of attributes in square brackets `[...]`.

#### Basic Structure

Every IDL file should start with a library definition (the `library` keyword). The library must have its own unique `uuid`.

```cpp
[
  uuid(12345678-1234-1234-1234-1234567890AB),
  version(1.0),
  helpstring("My library description")
]
library MyLibrary
{
  importlib("stdole2.tlb"); // Import standard OLE types (e.g., IUnknown, IDispatch)

  // Define types, interfaces, and classes here
}
```

#### Defining Structures and Enums

Inside the `library` block, you can define data types that your methods will use:

```cpp
  typedef enum {
    StatusError = 0,
    StatusOk = 1
  } MyStatus;

  typedef struct {
    long id;
    BSTR name;
  } UserData;
```

#### Defining Interfaces

An interface specifies the methods that an object exposes. Important attributes are `uuid`, `oleautomation`, and `dual` (for interfaces supporting IDispatch). Each method should return an `HRESULT` and have a unique `[id(X)]`.

```cpp
  [
    uuid(87654321-4321-4321-4321-BA0987654321),
    oleautomation,
    dual
  ]
  interface IMyInterface : IUnknown
  {
    [id(1)] HRESULT DoSomething([in] long value, [out, retval] long* result);
    [id(2)] HRESULT GetUser([in] long userId, [out, retval] UserData* data);
  }
```

- **[in]** - input parameter.
- **[out, retval]** - output parameter (treated as the function result in Pascal and C#).

#### Defining a Class (Coclass)

A class (Coclass) combines interfaces into a single, ready-to-use COM component.

```cpp
  [
    uuid(11111111-2222-3333-4444-555555555555)
  ]
  coclass MyComponent
  {
    [default] interface IMyInterface;
  }
```

### 2. Using the compiler (CLI)

You can run the compiler by passing the source IDL file, the output TLB file path, and optionally the output Pascal file:

```bash
Idl2Tlb.exe Sample.idl Sample.tlb Sample_TLB.pas
```

### 3. Integration with Lazarus IDE

#### Method A: Editing and debugging the compiler itself

If you want to modify the compiler's source code (`.pas` files in this directory):

1. Open the `Idl2Tlb.lpi` file in Lazarus.
2. Before pressing **F9** (Run), you need to provide arguments. In the top menu, go to **Run** -> **Run Parameters...**.
3. In the **Command line parameters** field, type for example:
   `Sample.idl Sample.tlb Sample_TLB.pas`
4. Now, pressing **F9** will compile and process the file correctly, allowing you to use breakpoints in the code.

#### Method B: Configuring an External Tool

If you are just writing `.idl` files in Lazarus and want to quickly compile them to `.tlb` and `_TLB.pas` with a single click/shortcut:

1. In the Lazarus top menu, go to **Tools** -> **Configure External Tools...**.
2. Click **Add**.
3. Configure the form as follows:
   - **Title:** `IDL -> TLB Compiler`
   - **Program:** Provide the full path to the built `Idl2Tlb.exe` file (e.g., `D:\Projekty\FPCTLB\Idl2Tlb.exe`).
   - **Parameters:** `$EdFile() $EdFile().tlb $EdFile()_TLB.pas`
   - **Working directory:** `$EdDir()`
4. Check the option: **Scan output for FPC errors** so that messages from our parser are visible in the Lazarus messages window.
5. Click **OK**.

**How to use it?**
Open any `.idl` file in the Lazarus editor. Then select **Tools** -> **IDL -> TLB Compiler** from the menu. The tool will process the active file in a fraction of a second, and the ready `.tlb` and `_TLB.pas` files will appear in the same folder.

### 4. Example Implementation (TestCOM.lpr)

The repository includes a `TestCOM.lpr` file that demonstrates how to practically use the generated `_TLB.pas` file to create and call a COM object.

To test it from the command line:

```bash
# 1. Compile the IDL file (generate .tlb and .pas)
.\Idl2Tlb.exe Sample.idl Sample.tlb MyTestLib_TLB.pas

# 2. Compile the test program
fpc TestCOM.lpr

# 3. Run
.\TestCOM.exe
```

Alternatively, open `TestCOM.lpr` in Lazarus and press **F9**.
