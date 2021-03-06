{
 *****************************************************************************
 *                                                                           *
 *  This file is part of the Lazarus Component Library (LCL)                 *
 *                                                                           *
 *  See the file COPYING.modifiedLGPL.txt, included in this distribution,    *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

  Author: Mattias Gaertner

  Abstract:
    Methods and classes for loading translations/localizations from po files.

  Example 1: Load a specific .po file:

    procedure TForm1.FormCreate(Sender: TObject);
    var
      PODirectory: String;
    begin
      PODirectory:='/path/to/lazarus/lcl/languages/';
      TranslateUnitResourceStrings('LCLStrConsts',PODirectory+'lcl.%s.po',
                                   'nl','');
      MessageDlg('Title','Text',mtInformation,[mbOk,mbCancel,mbYes],0);
    end;


  Example 2: Load the current language file using the GetLanguageIDs function
    of the gettext unit in the project lpr file:

    uses
      ...
      Translations, LCLProc;

    procedure TranslateLCL;
    var
      PODirectory, Lang, FallbackLang: String;
    begin
      PODirectory:='/path/to/lazarus/lcl/languages/';
      Lang:='';
      FallbackLang:='';
      LCLGetLanguageIDs(Lang,FallbackLang); // in unit LCLProc
      Translations.TranslateUnitResourceStrings('LCLStrConsts',
                                PODirectory+'lclstrconsts.%s.po',Lang,FallbackLang);
    end;

    begin
      TranslateLCL;
      Application.Initialize;
      Application.CreateForm(TForm1, Form1);
      Application.Run;
    end.

    Note for Mac OS X:
      The supported language IDs should be added into the application
      bundle property list to CFBundleLocalizations key, see
      lazarus.app/Contents/Info.plist for example.
}

{ 2012/10/14: plurals added
http://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html#Plural-forms
http://www.gnu.org/software/gettext/manual/html_node/Translating-plural-forms.html#Translating-plural-forms

https://translations.launchpad.net/+languages
https://developer.mozilla.org/en-US/docs/Localization_and_Plurals

Posix locale:
http://gcc.gnu.org/onlinedocs/libstdc++/manual/localization.html
+eo_EO (Esperanto)
+gd_GB (Scottish Gaelic)
}

unit uTranslations;

{$mode objfpc}{$H+}{$INLINE ON}
{$DEFINE UseCLDefault}
{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  Classes, SysUtils, LazUTF8, LCLProc, FileUtil, StringHashList, AvgLvlTree,
  LConvEncoding, Typinfo;

type
  TStringsType = (stLrt, stRst);

{  THeaderKey=(poProjectID,poReportBugs,poPotCreation,poRevision,poLastTranslator,
              poLangTeam,poLanguage,poContentType,poContentTransfer,poPluralForms,
              poBiDiMode);
}
  //Rules based on i18n Package by Kambiz R. Khojasteh; http://www.delphiarea.com
  TPosixLocale=(
  //nplurals=2; plural=n!=1;
  af_ZA,bg_BG,ca_ES,de_AT,de_BE,de_CH,de_DE,de_LU,el_GR,en_AU,en_BW,en_CA,en_DK,
  en_GB,en_HK,en_IE,en_IN,en_NZ,en_PH,en_SG,en_US,en_ZA,en_ZW,eo_EO,es_AR,es_BO,
  es_CL,es_CO,es_CR,es_DO,es_EC,es_ES,es_GT,es_HN,es_MX,es_NI,es_PA,es_PE,es_PR,
  es_PY,es_SV,es_US,es_UY,es_VE,et_EE,eu_ES,da_DK,fi_FI,fo_FO,gl_ES,he_IL,hi_IN,
  hu_HU,it_CH,it_IT,mr_IN,nl_BE,nl_NL,se_NO,nn_NO,no_NO,sq_AL,pt_PT,sv_FI,sv_SE,
  ta_IN,te_IN,ur_PK,
  //nplurals=1; plural=0;
  fa_IR,id_ID,ka_GE,ms_MY,tg_TJ,th_TH,uz_UZ,vi_VN,zh_CN,zh_HK,zh_TW,
  //nplurals=2; plural=n>1;
  br_FR,fr_BE,fr_CA,fr_CH,fr_FR,fr_LU,mi_NZ,oc_FR,pt_BR,tr_TR,wa_BE,
  //nplurals=2; plural=n==1 || n%10==1 ? 0 : 1;
  mk_MK,
  //nplurals=2; plural=n%10!=1 || n%100==11;
  is_IS,
  //nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;,
  hr_HR,be_BY,bs_BA,ru_RU,ru_UA,sr_YU,uk_UA,
  //nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2;
  lt_LT,
  //nplurals=3; plural=n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;
  pl_PL,
  //nplurals=3; plural=n==1 ? 0 : n>=2 && n<=4 ? 1 : 2;
  cs_CZ,sk_SK,
  //nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n!=0 ? 1 : 2;'
  lv_LV,
  //nplurals=3; plural=n==1 ? 0 : n==0 || (n%100 > 0 && n%100 < 20) ? 1 : 2;
  ro_RO,
  //nplurals=4; plural=n==1 ? 0 : n==2 ? 1 : n!=8 && n!=11 ? 2 : 3;'
  cy_GB,
  //nplurals=4; plural=n==1 ? 0 : n==2 ? 1 : n==3 ? 2 : 3;
  kw_GB,
  //nplurals=4; plural=n==1 ? 0 : n==0 || (n%100>1 && n%100<11) ? 1 : n%100>10 && n%100<20 ? 2 : 3;
  mt_MT,
  //nplurals=4; plural=n%100==1 ? 1 : n%100==2 ? 2 : n%100==3 || n%100==4 ? 3 : 0;
  sl_SI,
  //nplurals=4; plural=n==1 || n==11 ? 0 : n==2 || n==12 ? 1 : n>2 && n<20 ? 2 : 3;
  gd_GB,
  //nplurals=5; plural=n==1 ? 0 : n==2 ? 1 : n<7 ? 2 : n<11 ? 3 : 4;'
  ga_IE,
  //nplurals=6; plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;'
  ar_AE,ar_BH,ar_DZ,ar_EG,ar_IN,ar_IQ,ar_JO,ar_KW,ar_LB,ar_LY,ar_MA,ar_OM,ar_QA,ar_SA,ar_SD,ar_SY,ar_TN,ar_YE);

{
------------------
  gv_GB
  iw_IL
  kl_GL
  tl_PH
  yi_US

  (Locale: 'ast';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'an';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'az';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'bn';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'fur';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'ku';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'fy';    PluralRule: 'nplurals=2; plural=n!=1;'),              THeaderKey
  (Locale: 'gu';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'ha';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'ia';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'kn';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'lb';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'mai';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'ml';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'mn';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'nah';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'nap';   PluralRule: 'nplurals=2; plurToStr(Now)al=n!=1;'),
  (Locale: 'nb';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'ne';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'nso';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'or';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'ps';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'pa';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'pap';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'sco';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'si';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'so';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'son';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'pms';   PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'rm';    PluralRule: 'nplurals=2; plural=n!=1;'),
  Project-Id-Version
Report-Msgid-Bugs-To
POT-Creation-Date
PO-Revision-Date
Last-Translator
Language-Team
Language
Content-Type
Content-Transfer-Encoding
Plural-Forms

  (Locale: 'sw';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'tk';    PluralRule: 'nplurals=2; plural=n!=1;'),
  (Locale: 'yo';    PluralRule: 'nplurals=2; plural=n!=1;'),

  (Locale: 'ay';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'bo';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'cgg';   PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'dz';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'hy';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'ja';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'kk';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'km';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'ko';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'ky';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'lo';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'su';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'tt';    PluralRule: 'nplurals=1; plural=0;'),
  (Locale: 'ug';    PluralRule: 'nplurals=1; plural=0;'),

  (Locale: 'ach';   PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'ak';    PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'am';    PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'arn';   PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'fil';   PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'gun';   PluralRule: 'nplurals=2; plural=n>1;'),                THeaderKey
  (Locale: 'ln';    PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'mfe';   PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'mg';    PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'oc';    PluralRule: 'nplurals=2; plural=n>1;'),
  (Locale: 'ti';    PluralRule: 'nplurals=2; plural=n>1;'),

  (Locale: 'jv';    PluralRule: 'nplurals=2; plural=n!=0;'),
  (Locale: 'csb';   PluralRule: 'nplurals=3; plural=n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;'),

 }
  TTranslateUnitResult = (turOK, turNoLang, turNoFBLang, turEmptyParam);

type
  { TPOFileItem }

  TPOFileItem = class
  public
    Tag: Integer;
    Comments: string;
    IdentifierLow: string; // lowercase
    Original: string;
    Translation: string;
    Flags: string;
    PreviousID: string;
    Context: string;
    constructor Create(const TheIdentifierLow, TheOriginal, TheTranslated: string);
    procedure ModifyFlag(const AFlag: string; Check: boolean);
  end;

  { TPOFile }

  TPOFile = class
  protected
    FItems: TFPList;// list of TPOFileItem
    FIdentifierLowToItem: TStringToPointerTree; // lowercase identifier to TPOFileItem
    FIdentLowVarToItem: TStringHashList; // of TPOFileItem
    FOriginalToItem: TStringHashList; // of TPOFileItem
    FCharSet: String;
    FHeader: TPOFileItem;
    FAllEntries: boolean;
    FTag: Integer;
    FModified: boolean;
    FHelperList: TStringList;
    FModuleList: TStringList;
    procedure RemoveTaggedItems(aTag: Integer);
    procedure RemoveUntaggedModules;
  private
    function GetHeaderValue(const aID:string):string;
    function GetItem(index: string): TPOFileItem;
  public
    constructor Create;
    constructor Create(const AFilename: String; Full:boolean=false);
    constructor Create(AStream: TStream; Full:boolean=false);
    destructor Destroy; override;
    procedure ReadPOText(const Txt: string);
    procedure Add(Identifier, OriginalValue, TranslatedValue, Comments,
                  Context, Flags, PreviousID: string);
    function Translate(const Identifier, OriginalValue: String): String;
    Property CharSet: String read FCharSet;
    procedure Report;
    procedure CreateHeader;
    procedure UpdateStrings(InputLines:TStrings; SType: TStringsType);
    procedure SaveToStrings(OutLst: TStrings);
    procedure SaveToFile(const AFilename: string);
    procedure UpdateItem(const Identifier: string; Original: string);
    procedure UpdateTranslation(BasePOFile: TPOFile);
    procedure ClearModuleList;
    procedure AddToModuleList(Identifier: string);
    procedure UntagAll;

    property Tag: integer read FTag write FTag;
    property Modified: boolean read FModified;
    property Items: TFPList read FItems;
  public
    property HeaderValue[index:string]:string read GetHeaderValue;
    property ItemByName[index:string]:TPOFileItem read GetItem;
  end;

  EPOFileError = class(Exception)
  public
    ResFileName: string;
    POFileName: string;
  end;

var
  SystemCharSetIsUTF8: Boolean = true;// the LCL interfaces expect UTF-8 as default
    // if you don't use UTF-8, install a proper widestring manager and set this
    // to false.

// translate resource strings for one unit
function TranslateUnitResourceStrings(const ResUnitName, BaseFilename,
  Lang, FallbackLang: string):TTranslateUnitResult; overload;
function TranslateUnitResourceStrings(const ResUnitName, AFilename: string
  ): boolean; overload;
function TranslateUnitResourceStrings(const ResUnitName:string; po: TPOFile): boolean; overload;

// translate all resource strings
function TranslateResourceStrings(po: TPOFile): boolean;
function TranslateResourceStrings(const AFilename: string): boolean;
procedure TranslateResourceStrings(const BaseFilename, Lang, FallbackLang: string);

function UTF8ToSystemCharSet(const s: string): string; inline;

function UpdatePoFile(Files: TStrings; const POFilename: string): boolean;

//split rPlural by | and select right one from number
function PluralForm(const ResString: string; const Number:integer; const Locale:string): string;

implementation

function IsKey(Txt, Key: PChar): boolean;
begin
  if Txt=nil then exit(false);
  if Key=nil then exit(true);
  repeat
    if Key^=#0 then exit(true);
    if Txt^<>Key^ then exit(false);
    inc(Key);
    inc(Txt);
  until false;
end;

function GetUTF8String(TxtStart, TxtEnd: PChar): string; inline;
begin
  Result:=LazUTF8.UTF8CStringToUTF8String(TxtStart,TxtEnd-TxtStart);
end;

function ComparePOItems(Item1, Item2: Pointer): Integer;
begin
  Result := CompareText(TPOFileItem(Item1).IdentifierLow,
                        TPOFileItem(Item2).IdentifierLow);
end;

function UTF8ToSystemCharSet(const s: string): string; inline;
begin
  if SystemCharSetIsUTF8 then
    exit(s);
  {$IFDEF NoUTF8Translations}
  Result:=s;
  {$ELSE}
  Result:=UTF8ToSys(s);
  {$ENDIF}
end;

function StrToPoStr(const s:string):string;
var
  SrcPos, DestPos: Integer;
  NewLength: Integer;
begin
  NewLength:=length(s);
  for SrcPos:=1 to length(s) do
    if s[SrcPos] in ['"','\'] then inc(NewLength);
  if NewLength=length(s) then begin
    Result:=s;
  end else begin
    SetLength(Result,NewLength);
    DestPos:=1;
    for SrcPos:=1 to length(s) do begin
      case s[SrcPos] of
      '"','\':
        begin
          Result[DestPos]:='\';
          inc(DestPos);
          Result[DestPos]:=s[SrcPos];
          inc(DestPos);
        end;
      else
        Result[DestPos]:=s[SrcPos];
        inc(DestPos);
      end;
    end;
  end;
end;

function FindAllTranslatedPoFiles(const Filename: string): TStringList;
var
  Path: String;
  Name: String;
  NameOnly: String;
  Ext: String;
  FileInfo: TSearchRec;
  CurExt: String;
begin
  Result:=TStringList.Create;
  Path:=ExtractFilePath(Filename);
  Name:=ExtractFilename(Filename);
  Ext:=ExtractFileExt(Filename);
  NameOnly:=LeftStr(Name,length(Name)-length(Ext));
  if FindFirstUTF8(Path+GetAllFilesMask,faAnyFile,FileInfo)=0 then begin
    repeat
      if (FileInfo.Name='.') or (FileInfo.Name='..') or (FileInfo.Name='')
      or (CompareFilenames(FileInfo.Name,Name)=0) then continue;
      CurExt:=ExtractFileExt(FileInfo.Name);
      if (CompareFilenames(CurExt,'.po')<>0)
      or (CompareFilenames(LeftStr(FileInfo.Name,length(NameOnly)),NameOnly)<>0)
      then
        continue;
      Result.Add(Path+FileInfo.Name);
    until FindNextUTF8(FileInfo)<>0;
  end;
  FindCloseUTF8(FileInfo);
end;

function UpdatePOFile(Files: TStrings; const POFilename: string): boolean;
var
  InputLines: TStringList;
  Filename: string;
  BasePoFile, POFile: TPoFile;
  i: Integer;
  E: EPOFileError;

  procedure UpdatePoFilesTranslation;
  var
    j: Integer;
    Lines: TStringList;
  begin
    // Update translated PO files
    Lines := FindAllTranslatedPoFiles(POFilename);
    try
      for j:=0 to Lines.Count-1 do begin
        POFile := TPOFile.Create(Lines[j], true);
        try
          POFile.Tag:=1;
          POFile.UpdateTranslation(BasePOFile);
          try
            POFile.SaveToFile(Lines[j]);
          except
            on Ex: Exception do begin
              E := EPOFileError.Create(Ex.Message);
              E.ResFileName:=Lines[j];
              E.POFileName:=POFileName;
              raise E;
            end;
          end;
        finally
          POFile.Free;
        end;
      end;
    finally
      Lines.Free;
    end;
  end;

begin
  Result := false;

  if (Files=nil) or (Files.Count=0) then begin

    if FileExistsUTF8(POFilename) then begin
      // just update translated po files
      BasePOFile := TPOFile.Create(POFilename, true);
      try
        UpdatePoFilesTranslation;
      finally
        BasePOFile.Free;
      end;
    end;

    exit;

  end;

  InputLines := TStringList.Create;
  try
    // Read base po items
    if FileExistsUTF8(POFilename) then
      BasePOFile := TPOFile.Create(POFilename, true)
    else
      BasePOFile := TPOFile.Create;
    BasePOFile.Tag:=1;

    // Update po file with lrt or/and rst files
    for i:=0 to Files.Count-1 do begin
      Filename:=Files[i];
      if (CompareFileExt(Filename,'.lrt')=0)
      or (CompareFileExt(Filename,'.rst')=0) then
        try
          //DebugLn('');
          //DebugLn(['AddFiles2Po Filename="',Filename,'"']);
          InputLines.Clear;
          InputLines.LoadFromFile(UTF8ToSys(FileName));

          if CompareFileExt(Filename,'.lrt')=0 then
            BasePOFile.UpdateStrings(InputLines, stLrt)
          else
            BasePOFile.UpdateStrings(InputLines, stRst);

        except
          on Ex: Exception do begin
            E := EPOFileError.Create(Ex.Message);
            E.ResFileName:=FileName;
            E.POFileName:=POFileName;
            raise E;
          end;
        end;
    end;
    BasePOFile.SaveToFile(POFilename);
    Result := BasePOFile.Modified;

    UpdatePOFilesTranslation;

  finally
    InputLines.Free;
    BasePOFile.Free;
  end;
end;

function GetPluralForm(aNumber:longword; const aLocaleID:TPosixLocale):byte;
var
  Mod10,Mod100 : longword;
begin
  Mod10:=aNumber mod 10;
  Mod100:=aNumber mod 100;
  case aLocaleID of
   fa_IR,id_ID,ka_GE,ms_MY,tg_TJ,th_TH,uz_UZ,vi_VN,zh_CN,zh_HK,zh_TW:
   //nplurals=1; plural=0;
     Result:=0;
   af_ZA,bg_BG,ca_ES,de_AT,de_BE,de_CH,de_DE,de_LU,el_GR,en_AU,en_BW,en_CA,en_DK,
   en_GB,en_HK,en_IE,en_IN,en_NZ,en_PH,en_SG,en_US,en_ZA,en_ZW,eo_EO,es_AR,es_BO,
   es_CL,es_CO,es_CR,es_DO,es_EC,es_ES,es_GT,es_HN,es_MX,es_NI,es_PA,es_PE,es_PR,
   es_PY,es_SV,es_US,es_UY,es_VE,et_EE,eu_ES,da_DK,fi_FI,fo_FO,gl_ES,he_IL,hi_IN,
   hu_HU,it_CH,it_IT,mr_IN,nl_BE,nl_NL,se_NO,nn_NO,no_NO,sq_AL,pt_PT,sv_FI,sv_SE,
   ta_IN,te_IN,ur_PK:
   //nplurals=2; plural=n!=1;
     if aNumber<>1 then
       Result:=1 else
       Result:=0;
   br_FR,fr_BE,fr_CA,fr_CH,fr_FR,fr_LU,mi_NZ,oc_FR,pt_BR,tr_TR,wa_BE:
   //nplurals=2; plural=n>1;
     if aNumber>1 then
       Result:=1 else
       Result:=0;
   mk_MK:
   //nplurals=2; plural=n==1 || n%10==1 ? 0 : 1;
     if (aNumber=1) or (Mod10=1) then
       Result:=0 else
       Result:=1;
   //nplurals=2; plural=n%10!=1 || n%100==11;
   is_IS:
     if (Mod10<>1) or (Mod100=11) then
       Result:=1 else
       Result:=0;
   hr_HR,be_BY,bs_BA,ru_RU,ru_UA,sr_YU,uk_UA:
   //nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;
     if ((Mod10=1) and (Mod100<>11)) then
       Result:=0 else
       if (Mod10>=2) and (Mod10<=4) and ((Mod100<10) or (Mod100>=20)) then
         Result:=1 else
         Result:=2;
   lt_LT:
   //nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2;
     if (Mod10=1) and (Mod100<>11) then
       Result:=0 else
       if (Mod10>=2) and ((Mod100<10) or (Mod100>=20)) then
       Result:=1 else
       Result:=2;
   pl_PL:
   //nplurals=3; plural=n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;
     if aNumber=1 then
       Result:=0 else
       if (Mod10>=2) and (Mod10<=4) and ((Mod100<10) or (Mod100>=20)) then
         Result:=1 else
         Result:=2;
   cs_CZ,sk_SK:
   //nplurals=3; plural=n==1 ? 0 : n>=2 && n<=4 ? 1 : 2;
     if aNumber=1 then
       Result:=0 else
       if (aNumber>=2) and (aNumber<=4) then
         Result:=1 else
         Result:=2;
   lv_LV:
   //nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n!=0 ? 1 : 2;'
     if (Mod10=1) and (Mod100<>11) then
         Result:=0 else
         if aNumber<>0 then
           Result:=1 else
           Result:=2;
   ro_RO:
   //nplurals=3; plural=n==1 ? 0 : n==0 || (n%100 > 0 && n%100 < 20) ? 1 : 2;
     if aNumber=1 then
       Result:=0 else
       if (aNumber=0) or ((Mod100>0) and (Mod100<20)) then
         Result:=1 else
         Result:=2;
   cy_GB:
   //nplurals=4; plural=n==1 ? 0 : n==2 ? 1 : n!=8 && n!=11 ? 2 : 3;'
     if aNumber=1 then
       Result:=0 else
       if aNumber=2 then
         Result:=1 else
         if (aNumber<>8) and (aNumber<>11) then
           Result:=2 else
           Result:=3;
   kw_GB:
   //nplurals=4; plural=n==1 ? 0 : n==2 ? 1 : n==3 ? 2 : 3;
     if aNumber=1 then
       Result:=0 else
         if aNumber=2 then
           Result:=1 else
           if aNumber=3 then
             Result:=2 else
             Result:=3;
   mt_MT:
   //nplurals=4; plural=n==1 ? 0 : n==0 || (n%100>1 && n%100<11) ? 1 : n%100>10 && n%100<20 ? 2 : 3;
     if aNumber=1 then
       Result:=0 else
         if (aNumber=0) or ((Mod100>1) and (Mod100<11)) then
           Result:=1 else
           if (Mod100>10) and (Mod100<20) then
             Result:=2 else
             Result:=3;
   sl_SI:
   //nplurals=4; plural=n%100==1 ? 1 : n%100==2 ? 2 : n%100==3 || n%100==4 ? 3 : 0;
     if Mod100=1 then
       Result:=1 else
         if (Mod100=2) then
           Result:=2 else
           if ((Mod100=3) or (Mod100=4)) then
             Result:=3 else
             Result:=0;
   gd_GB:
   //nplurals=4; plural=n==1 || n==11 ? 0 : n==2 || n==12 ? 1 : n>2 && n<20 ? 2 : 3;
     if (aNumber=1) or (aNumber=11) then
       Result:=0 else
       if (aNumber=2) or (aNumber=12) then
         Result:=1 else
         if (aNumber>2) and (aNumber<20) then
           Result:=2 else
           Result:=3;
   ga_IE:
   //nplurals=5; plural=n==1 ? 0 : n==2 ? 1 : n<7 ? 2 : n<11 ? 3 : 4;
     if (aNumber=1) then
       Result:=0 else
       if (aNumber=2) then
         Result:=1 else
         if (aNumber<7) then
           Result:=2 else
           if (aNumber<11) then
             Result:=3 else
             Result:=4;
   ar_AE,ar_BH,ar_DZ,ar_EG,ar_IN,ar_IQ,ar_JO,ar_KW,ar_LB,ar_LY,ar_MA,ar_OM,ar_QA,ar_SA,ar_SD,ar_SY,ar_TN,ar_YE:
   //nplurals=6; plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;
     if (aNumber=0) then
       Result:=0 else
       if (aNumber=1) then
         Result:=1 else
         if (aNumber=2) then
           Result:=2 else
           if (Mod100>=3) and (Mod100<=10) then
             Result:=3 else
             if Mod100>=11 then
               Result:=4 else
               Result:=5;
  end;//case
end;

function PluralForm(const ResString: string; const Number:integer; const Locale:string): string;
var
  aPluralForm:byte;
  aLocale:TPosixLocale;
begin
  aLocale:=TPosixLocale(GetEnumValue(TypeInfo(TPosixLocale),Locale));

  aPluralForm:=GetPluralForm(abs(Number),aLocale);
  with TStringList.Create do
  try
    Delimiter:='|';
    StrictDelimiter:=true;
    DelimitedText:=ResString;
    if Count>aPluralForm then
      Result:=Strings[aPluralForm] else
      Result:=Strings[0];
  finally
    Free;
  end;
end;

function Translate (Name,Value : AnsiString; Hash : Longint; arg:pointer) : AnsiString;
var
  po: TPOFile;
begin
  po:=TPOFile(arg);
  // get UTF8 string
  result := po.Translate(Name,Value);
  // convert UTF8 to current local
  if result<>'' then
    result:=UTF8ToSystemCharSet(result);
end;

function TranslateUnitResourceStrings(const ResUnitName, AFilename: string
  ): boolean;
var po: TPOFile;
begin
  //debugln('TranslateUnitResourceStrings) ResUnitName="',ResUnitName,'" AFilename="',AFilename,'"');
  if (ResUnitName='') or (AFilename='') or (not FileExistsUTF8(AFilename)) then
    exit;
  result:=false;
  po:=nil;
  try
    po:=TPOFile.Create(AFilename);
    result:=TranslateUnitResourceStrings(ResUnitName,po);
  finally
    po.free;
  end;
end;

function TranslateUnitResourceStrings(const ResUnitName: string; po: TPOFile): boolean;
begin
  Result:=false;
  try
    SetUnitResourceStrings(ResUnitName,@Translate,po);
    Result:=true;
  except
    on e: Exception do begin
      {$IFNDEF DisableChecks}
      DebugLn('Exception while translating ', ResUnitName);
      DebugLn(e.Message);
      DumpExceptionBackTrace;
      {$ENDIF}
    end;
  end;
end;

function TranslateUnitResourceStrings(const ResUnitName, BaseFilename,
  Lang, FallbackLang: string):TTranslateUnitResult;
begin
  Result:=turOK;                //Result: OK
  if (ResUnitName='') or (BaseFilename='') then
    Result:=turEmptyParam       //Result: empty Parameter
  else begin
    //debugln('TranslateUnitResourceStrings BaseFilename="',BaseFilename,'"');
    if (FallbackLang<>'') and FileExistsUTF8(Format(BaseFilename,[FallbackLang])) then
      TranslateUnitResourceStrings(ResUnitName,Format(BaseFilename,[FallbackLang]))
    else
      Result:=turNoFBLang;      //Result: missing FallbackLang file
    if (Lang<>'') and FileExistsUTF8(Format(BaseFilename,[Lang])) then
      TranslateUnitResourceStrings(ResUnitName,Format(BaseFilename,[Lang]))
    else
      Result:=turNoLang;        //Result: missing Lang file
  end;
end;

function TranslateResourceStrings(po: TPOFile): boolean;
begin
  Result:=false;
  try
    SetResourceStrings(@Translate,po);
    Result:=true;
  except
    on e: Exception do begin
      {$IFNDEF DisableChecks}
      DebugLn('Exception while translating:');
      DebugLn(e.Message);
      DumpExceptionBackTrace;
      {$ENDIF}
    end;
  end;
end;

function TranslateResourceStrings(const AFilename: string): boolean;
var po: TPOFile;
begin
  //debugln('TranslateResourceStrings) ResUnitName,'" AFilename="',AFilename,'"');
  if (AFilename='') or (not FileExistsUTF8(AFilename)) then
    exit;
  result:=false;
  po:=nil;
  try
    po:=TPOFile.Create(AFilename);
    result:=TranslateResourceStrings(po);
  finally
    po.free;
  end;
end;

procedure TranslateResourceStrings(const BaseFilename, Lang, FallbackLang: string);
begin
  if (BaseFilename='') then exit;

  //debugln('TranslateResourceStrings BaseFilename="',BaseFilename,'"');
  if (FallbackLang<>'') then
    TranslateResourceStrings(Format(BaseFilename,[FallbackLang]));
  if (Lang<>'') then
    TranslateResourceStrings(Format(BaseFilename,[Lang]));
end;

{ TPOFile }

procedure TPOFile.RemoveUntaggedModules;
var
  Module: string;
  Item,VItem: TPOFileItem;
  i, p: Integer;
  VarName: String;
begin
  if FModuleList=nil then
    exit;
    
  // remove all module references that were not tagged
  for i:=FItems.Count-1 downto 0 do begin
    Item := TPOFileItem(FItems[i]);
    p := pos('.',Item.IdentifierLow);
    if P=0 then
      continue; // module not found (?)
      
    Module :=LeftStr(Item.IdentifierLow, p-1);
    if (FModuleList.IndexOf(Module)<0) then
      continue; // module was not modified this time

    if Item.Tag=FTag then
      continue; // PO item was updated
      
    // this item is not more in updated modules, delete it
    FIdentifierLowToItem.Remove(Item.IdentifierLow);
    // delete it also from VarToItem
    VarName := RightStr(Item.IdentifierLow, Length(Item.IdentifierLow)-P);
    VItem := TPoFileItem(FIdentLowVarToItem.Data[VarName]);
    if (VItem=Item) then
      FIdentLowVarToItem.Remove(VarName);

    FOriginalToItem.Remove(Item.Original, Item);
    FItems.Delete(i);
    Item.Free;
  end;
end;

constructor TPOFile.Create;
begin
  inherited Create;
  FAllEntries:=true;
  FItems:=TFPList.Create;
  FIdentifierLowToItem:=TStringToPointerTree.Create(true);
  FIdentLowVarToItem:=TStringHashList.Create(true);
  FOriginalToItem:=TStringHashList.Create(true);
end;

constructor TPOFile.Create(const AFilename: String; Full:boolean=False);
var
  f: TStream;
begin
  f := TFileStream.Create(UTF8ToSys(AFilename), fmOpenRead or fmShareDenyNone);
  try
    Create(f, Full);
    if FHeader=nil then
      CreateHeader;
  finally
    f.Free;
  end;
end;

constructor TPOFile.Create(AStream: TStream; Full:boolean=false);
var
  Size: Integer;
  s: string;
begin
  Create;
  
  FAllEntries := Full;
  
  Size:=AStream.Size-AStream.Position;
  if Size<=0 then exit;
  SetLength(s,Size);
  AStream.Read(s[1],Size);
  ReadPOText(s);
end;

destructor TPOFile.Destroy;
var
  i: Integer;
begin
  if FModuleList<>nil then
    FModuleList.Free;
  if FHelperList<>nil then
    FHelperList.Free;
  if FHeader<>nil then
    FHeader.Free;
  for i:=0 to FItems.Count-1 do
    TObject(FItems[i]).Free;
  FItems.Free;
  FIdentLowVarToItem.Free;
  FIdentifierLowToItem.Free;
  FOriginalToItem.Free;
  inherited Destroy;
end;

procedure TPOFile.ReadPOText(const Txt: string);
{ Read a .po file. Structure:

Example
#: lazarusidestrconsts:lisdonotshowsplashscreen
msgid "                      Do not show splash screen"
msgstr ""

}
type
  TMsg = (
    mid,
    mstr,
    mctx);
var
  l: Integer;
  LineLen: Integer;
  p: PChar;
  LineStart: PChar;
  LineEnd: PChar;
  Identifier: String;
  PrevMsgID: String;
  Comments: String;
  Flags: string;
  TextEnd: PChar;
  i: Integer;
  OldLineStartPos: PtrUInt;
  NewSrc: String;
  s: String;
  Handled: Boolean;
  CurMsg: TMsg;
  Msg: array[TMsg] of string;

  procedure ResetVars;
  begin
    CurMsg:=mid;
    Msg[mid]:='';
    Msg[mstr]:='';
    Msg[mctx]:='';
    Identifier := '';
    Comments := '';
    Flags := '';
    PrevMsgID := '';
  end;
  
  procedure AddEntry;
  var
    Item: TPOFileItem;
    i:integer;
  begin
    if Identifier<>'' then begin
      // check for unresolved duplicates in po file
      Item := TPOFileItem(FOriginalToItem.Data[Msg[mid]]);
      if (Item<>nil) then begin
        // fix old duplicate context
        if Item.Context='' then
          Item.Context:=Item.IdentifierLow;
        // set context of new duplicate
        if Msg[mctx]='' then
          Msg[mctx] := Identifier;
        // if old duplicate was translated and
        // new one is not, provide a initial translation
        if Msg[mstr]='' then
          Msg[mstr] := Item.Translation;
      end;
      //remove ending pipe
      i:=length(Msg[mstr]);
      if (i>0) and (Msg[mstr][i]='|') then
        delete(Msg[mstr],i,1);
      Add(Identifier,Msg[mid],Msg[mstr],Comments,Msg[mctx],Flags,PrevMsgID);
      ResetVars;
    end else
    if (Msg[CurMsg]<>'') and (FHeader=nil) then begin
      FHeader := TPOFileItem.Create('',Msg[mid],Msg[CurMsg]);
      FHeader.Comments:=Comments;
      ResetVars;
    end
  end;

begin
  if Txt='' then exit;
  s:=Txt;
  l:=length(s);
  p:=PChar(s);
  LineStart:=p;
  TextEnd:=p+l;

  ResetVars;

  while LineStart<TextEnd do begin
    LineEnd:=LineStart;
    while (not (LineEnd^ in [#0,#10,#13])) do inc(LineEnd);
    LineLen:=LineEnd-LineStart;
    if LineLen>0 then begin
      Handled:=false;
      case LineStart^ of
      '#':
        begin
          case LineStart[1] of
          ':':
            if LineStart[2]=' ' then begin
              // '#: '
              AddEntry;
              Identifier:=copy(s,LineStart-p+4,LineLen-3);
              // the RTL creates identifier paths with point instead of colons
              // fix it:
              for i:=1 to length(Identifier) do
                if Identifier[i]=':' then
                  Identifier[i]:='.';
              Handled:=true;
            end;
          '|':
            if IsKey(LineStart,'#| msgid "') then begin
              PrevMsgID:=PrevMsgID+GetUTF8String(LineStart+length('#| msgid "'),LineEnd-1);
              Handled:=true;
            end else if IsKey(LineStart, '#| "') then begin
              Msg[CurMsg] := Msg[CurMsg] + GetUTF8String(LineStart+length('#| "'),LineEnd-1);
              Handled:=true;
            end;
          ',':
            if LineStart[2]=' ' then begin
              // '#, '
              Flags := GetUTF8String(LineStart+3,LineEnd);
              Handled:=true;
            end;
          end;
          if not Handled then begin
            // '#'
            if Msg[mid]<>'' then //no comments after msgstr; first entry not nec. #: xyz
              AddEntry;
            if Comments<>'' then
              Comments := Comments + LineEnding;
            Comments := Comments + GetUTF8String(LineStart+1,LineEnd);
            Handled:=true;
          end;
        end;
      'm':
        if (LineStart[1]='s') and (LineStart[2]='g') then begin
          case LineStart[3] of
          'i':
            if IsKey(LineStart,'msgid "') then begin
              CurMsg:=mid;
              Msg[CurMsg]:=Msg[CurMsg]+GetUTF8String(LineStart+length('msgid "'),LineEnd-1);
              Handled:=true;
            end else
            if IsKey(LineStart,'msgid_plural "') then  //ignored
            begin
              CurMsg:=mid;
              Msg[CurMsg]:=Msg[CurMsg]+'|'+GetUTF8String(LineStart+length('msgid_plural "'),LineEnd-1);
              Handled:=true;
            end;
          's':
            begin
              if IsKey(LineStart,'msgstr "') then begin
                CurMsg:=mstr;
                Msg[CurMsg]:=Msg[CurMsg]+GetUTF8String(LineStart+length('msgstr "'),LineEnd-1);
                Handled:=true;
              end else
              if IsKey(LineStart,'msgstr[') then begin  //translated plurals, concenated by pipe
                CurMsg:=mstr;
                Msg[CurMsg]:=Msg[CurMsg]+GetUTF8String(LineStart+length('msgstr[0] "'),LineEnd-1);
                if Msg[CurMsg]<>'' then
                  Msg[CurMsg]:=Msg[CurMsg]+'|';
                Handled:=true;
              end;
            end;
          'c':
            if IsKey(LineStart, 'msgctxt "') then begin
              CurMsg:=mctx;
              Msg[CurMsg]:=Msg[CurMsg]+GetUTF8String(LineStart+length('msgctxt "'), LineEnd-1);
              Handled:=true;
            end;
          end;
        end;
      '"':
        begin
          if (Msg[mid]='')
          and IsKey(LineStart,'"Content-Type: text/plain; charset=') then
          begin
            FCharSet:=GetUTF8String(LineStart+length('"Content-Type: text/plain; charset='),LineEnd);
            if SysUtils.CompareText(FCharSet,'UTF-8')<>0 then begin
              // convert encoding to UTF-8
              OldLineStartPos:=PtrUInt(LineStart-PChar(s))+1;
              NewSrc:=ConvertEncoding(copy(s,OldLineStartPos,length(s)),
                                      FCharSet,EncodingUTF8);
              // replace text and update all pointers
              s:=copy(s,1,OldLineStartPos-1)+NewSrc;
              l:=length(s);
              p:=PChar(s);
              TextEnd:=p+l;
              LineStart:=p+(OldLineStartPos-1);
              LineEnd:=LineStart;
              while (not (LineEnd^ in [#0,#10,#13])) do inc(LineEnd);
              LineLen:=LineEnd-LineStart;
            end;
          end;
          // continuation
          Msg[CurMsg]:=Msg[CurMsg]+GetUTF8String(LineStart+1,LineEnd-1);
          Handled:=true;
        end;
      end;
      if not Handled then
        AddEntry;
    end;
    LineStart:=LineEnd+1;
    while (LineStart^ in [#10,#13]) do inc(LineStart);
  end;
  AddEntry;
end;

procedure TPOFile.Add(Identifier, OriginalValue, TranslatedValue,
  Comments, Context, Flags, PreviousID: string);
var
  Item: TPOFileItem;
  p: Integer;
begin
  if (not FAllEntries) and (TranslatedValue='') then exit;

  Item:=TPOFileItem.Create(lowercase(Identifier),OriginalValue,TranslatedValue);
  Item.Comments:=Comments;
  Item.Context:=Context;
  Item.Flags:=Flags;
  Item.PreviousID:=PreviousID;
  Item.Tag:=FTag;
  FItems.Add(Item);

  //debugln(['TPOFile.Add Identifier=',Identifier,' Orig="',dbgstr(OriginalValue),'" Transl="',dbgstr(TranslatedValue),'"']);
  FIdentifierLowToItem[Item.IdentifierLow]:=Item;
  P := Pos('.', Identifier);
  if P>0 then
    FIdentLowVarToItem.Add(copy(Item.IdentifierLow, P+1, Length(Item.IdentifierLow)), Item);

  if OriginalValue<>'' then
    FOriginalToItem.Add(OriginalValue,Item);
end;

function TPOFile.Translate(const Identifier, OriginalValue: String): String;
var
  Item: TPOFileItem;
  b:boolean;
begin
  Result:='';
  b:=true;
  Item:=TPOFileItem(FIdentifierLowToItem[lowercase(Identifier)]);
  if Item=nil then
  begin
    b:=false;
    Item:=TPOFileItem(FOriginalToItem.Data[OriginalValue]);
  end;
  if Item<>nil then
  begin
    Result:=Item.Translation;
//    if Result='' then RaiseGDBException('TPOFile.Translate Inconsistency');
  end;// else

  if not b then
  begin
    Add(Identifier, OriginalValue,'','# New Item',Identifier,'','');
    if Result='' then
      Result:=OriginalValue;
  end;
end;

procedure TPOFile.Report;
var
  Item: TPOFileItem;
  i: Integer;
begin
  DebugLn('Header:');
  DebugLn('---------------------------------------------');

  if FHeader=nil then
    DebugLn('No header found in po file')
  else begin
    DebugLn('Comments=',FHeader.Comments);
    DebugLn('Identifier=',FHeader.IdentifierLow);
    DebugLn('msgid=',FHeader.Original);
    DebugLn('msgstr=', FHeader.Translation);
  end;
  DebugLn;
  
  DebugLn('Entries:');
  DebugLn('---------------------------------------------');
  for i:=0 to FItems.Count-1 do begin
    DebugLn('#',dbgs(i),': ');
    Item := TPOFileItem(FItems[i]);
    DebugLn('Comments=',Item.Comments);
    DebugLn('Identifier=',Item.IdentifierLow);
    DebugLn('msgid=',Item.Original);
    DebugLn('msgstr=', Item.Translation);
    DebugLn;
  end;

end;

procedure TPOFile.CreateHeader;
begin
  if FHeader=nil then
    FHeader := TPOFileItem.Create('','','');
  FHeader.Translation:='Content-Type: text/plain; charset=UTF-8';
  FHeader.Comments:='';
end;

procedure TPOFile.UpdateStrings(InputLines: TStrings; SType: TStringsType);
var
  i,j,n: integer;
  p: LongInt;
  Identifier, Value,Line: string;
  Ch: Char;
  MultiLinedValue: boolean;

  procedure NextLine;
  begin
    if i<InputLines.Count then
      inc(i);
    if i<InputLines.Count then
      Line := InputLines[i]
    else
      Line := '';
    n := Length(Line);
    p := 1;
  end;

begin
  ClearModuleList;
  UntagAll;
  // for each string in lrt/rst list check if it's already in PO
  // if not add it
  Value := '';
  Identifier := '';
  i := 0;
  while i < InputLines.Count do begin

    Line := InputLines[i];
    n := Length(Line);

    if n=0 then
      // empty line
    else
    if SType=stLrt then begin

      p:=Pos('=',Line);
      Value :=copy(Line,p+1,n-p); //if p=0, that's OK, all the string
      Identifier:=copy(Line,1,p-1);
      UpdateItem(Identifier, Value);

    end else begin
      // rst file
      if Line[1]='#' then begin
        // rst file: comment

        Value := '';
        Identifier := '';
        MultilinedValue := false;

      end else begin

        p:=Pos('=',Line);
        if P>0 then begin

          Identifier := copy(Line,1,p-1);
          inc(p); // points to ' after =

          Value := '';
          while p<=n do begin

            if Line[p]='''' then begin
              inc(p);
              j:=p;
              while (p<=n)and(Line[p]<>'''') do
                inc(p);
              Value := Value + copy(Line, j, P-j);
              inc(p);
              continue;
            end else
            if Line[p] = '#' then begin
              // a #decimal
              repeat
                inc(p);
                j:=p;
                while (p<=n)and(Line[p] in ['0'..'9']) do
                  inc(p);

                Ch := Chr(StrToInt(copy(Line, j, p-j)));
                Value := Value + Ch;
                if Ch in [#13,#10] then
                  MultilinedValue := True;

                if (p=n) and (Line[p]='+') then
                  NextLine;

              until (p>n) or (Line[p]<>'#');
            end else
            if Line[p]='+' then
              NextLine
            else
              inc(p); // this is an unexpected string
          end;

          if Value<>'' then begin
            if MultiLinedValue then begin
              // check that we end on lineending, multilined
              // resource strings from rst usually do not end
              // in lineending, fix here.
              if not (Value[Length(Value)] in [#13,#10]) then
                Value := Value + LineEnding;
            end;
            // po requires special characters as #number
            p:=1;
            while p<=length(Value) do begin
              j := LazUTF8.UTF8CharacterLength(pchar(@Value[p]));
              if (j=1) and (Value[p] in [#0..#9,#11,#12,#14..#31,#127..#255]) then
                Value := copy(Value,1,p-1)+'#'+IntToStr(ord(Value[p]))+copy(Value,p+1,length(Value))
              else
                inc(p,j);
            end;

            UpdateItem(Identifier, Value);
          end;

        end; // if p>0 then begin
      end;
    end;

    inc(i);
  end;
  
  RemoveUntaggedModules;
end;

procedure TPOFile.SaveToStrings(OutLst: TStrings);
var
  j: Integer;

  procedure WriteLst(const AProp, AValue: string );
  var
    i: Integer;
    s: string;
  begin
    if (AValue='') and (AProp='') then
      exit;

    FHelperList.Text:=AValue;
    if FHelperList.Count=1 then begin
      if AProp='' then OutLst.Add(FHelperList[0])
      else             OutLst.Add(AProp+' "'+FHelperList[0]+'"');
    end else begin
      if AProp<>'' then
        OutLst.Add(AProp+' ""');
      for i:=0 to FHelperList.Count-1 do
      begin
        s := FHelperList[i];
        if AProp<>'' then
        begin
          if i<FHelperList.Count-1 then
            s := '"' + s + '\n"' else
            s := '"' + s + '"';
          if AProp='#| msgid' then
            s := '#| ' + s;
        end;
        OutLst.Add(s)
      end;
    end;
  end;

  procedure WriteItem(Item: TPOFileItem);
  var
    i:integer;
  begin
    if (Item.Comments<>'') and (Item.Comments[1]<>'#') then
      Item.Comments:='#'+Item.Comments;
    WriteLst('',Item.Comments);
    if Item.IdentifierLow<>'' then
      OutLst.Add('#: '+Item.IdentifierLow);
    if Trim(Item.Flags)<>'' then
      OutLst.Add('#, '+Trim(Item.Flags));
    if Item.PreviousID<>'' then
      WriteLst('#| msgid', strToPoStr(Item.PreviousID));
    if Item.Context<>'' then
      WriteLst('msgctxt', Item.Context);

    if pos('|',Item.Original)>0 then
    begin
      with TStringList.Create do
      try
        Delimiter:='|';
        StrictDelimiter:=true;
        //original
        DelimitedText:=Item.Original;
        WriteLst('msgid', StrToPoStr(Strings[0]));
        WriteLst('msgid_plural', StrToPoStr(Strings[1]));
        //translation
        DelimitedText:=Item.Translation;
        for i:=0 to Count-1 do
          WriteLst('msgstr['+inttostr(i)+']', StrToPoStr(Strings[i]));
      finally
        Free;
      end;
    end else
    begin
      WriteLst('msgid', StrToPoStr(Item.Original));
      WriteLst('msgstr', StrToPoStr(Item.Translation));
    end;

    OutLst.Add('');
  end;

begin
  if FHeader=nil then
    CreateHeader;

  if FHelperList=nil then
    FHelperList:=TStringList.Create;

  // write header
  WriteItem(FHeader);

  // Sort list of items by identifier
  FItems.Sort(@ComparePOItems);

  for j:=0 to Fitems.Count-1 do
    WriteItem(TPOFileItem(FItems[j]));
end;

function TPOFile.GetHeaderValue(const aID:string):string;
var
  s:string;
  z1,z2:integer;
begin
  s:=FHeader.Translation;
  z1:=pos(aID,s);
  if z1>0 then
  begin
    z2:=pos(#10,copy(s,z1,length(s)));
    Result:=copy(s,z1+length(aID),z2-length(aID)-1);
    if (Result<>'') and (Result[length(Result)]=#13) then
      delete(Result,length(Result),1);
  end else
    Result:='';
end;

function TPOFile.GetItem(index: string): TPOFileItem;
begin
  Result:=TPOFileItem(FIdentifierLowToItem[lowercase(index)]);
end;

procedure TPOFile.RemoveTaggedItems(aTag: Integer);
var
  Item: TPOFileItem;
  i: Integer;
begin
  // get rid of all entries that have Tag=aTag
  for i:=FItems.Count-1 downto 0 do begin
    Item := TPOFileItem(FItems[i]);
    if Item.Tag<>aTag then
      Continue;
    FIdentifierLowToItem.Remove(Item.IdentifierLow);

    FOriginalToItem.Remove(Item.Original, Item);
    FItems.Delete(i);
    Item.Free;
  end;
end;

procedure TPOFile.SaveToFile(const AFilename: string);
var
  OutLst: TStringList;
begin
  OutLst := TStringList.Create;
  try
    SaveToStrings(OutLst);
    OutLst.SaveToFile(UTF8ToSys(AFilename));
  finally
    OutLst.Free;
  end;
end;

function SkipLineEndings(var P: PChar; var DecCount: Integer): Integer;
  procedure Skip;
  begin
    Dec(DecCount);
    Inc(P);
  end;
begin
  Result  := 0;
  while (P^ in [#10,#13]) do begin
    Inc(Result);
    if (P^=#13) then begin
      Skip;
      if P^=#10 then
        Skip;
    end else
      Skip;
  end;
end;

function CompareMultilinedStrings(const S1,S2: string): Integer;
var
  C1,C2,L1,L2: Integer;
  P1,P2: PChar;
begin
  L1 := Length(S1);
  L2 := Length(S2);
  P1 := pchar(S1);
  P2 := pchar(S2);
  Result := ord(P1^) - ord(P2^);

  while (Result=0) and (P1^<>#0) do begin
    Inc(P1); Inc(P2);
    Dec(L1); Dec(L2);
    if P1^<>P2^ then begin
      C1 := SkipLineEndings(P1, L1);
      C2 := SkipLineEndings(P2, L2);
      if (C1<>C2) then
        // different amount of lineendings
        result := C1-C2
      else
      if (C1=0) then
        // there are no lineendings at all, will end loop
        result := Ord(P1^)-Ord(P2^);
    end;
  end;

  // if strings are the same, check that all chars have been consumed
  // just in case there are unexpected chars in between, in this case
  // L1=L2=0;
  if Result=0 then
    Result := L1-L2;
end;

procedure TPOFile.UpdateItem(const Identifier: string; Original: string);
var
  Item: TPOFileItem;
  AContext,AComment,ATranslation,AFlags,APrevStr: string;
begin
  if FHelperList=nil then
    FHelperList := TStringList.Create;

  // try to find PO entry by identifier
  Item:=TPOFileItem(FIdentifierLowToItem[lowercase(Identifier)]);
  if Item<>nil then begin
    // found, update item value
    AddToModuleList(Identifier);

    if CompareMultilinedStrings(Item.Original, Original)<>0 then begin
      FModified := True;
      if Item.Translation<>'' then begin
        Item.ModifyFlag('fuzzy', true);
        Item.PreviousID:=Item.Original;
      end;
    end;
    Item.Original:=Original;
    Item.Tag:=FTag;
    exit;
  end;

  // try to find po entry based only on it's value
  AContext := '';
  AComment := '';
  ATranslation := '';
  AFlags := '';
  APrevStr := '';
  Item := TPOFileItem(FOriginalToItem.Data[Original]);
  if Item<>nil then begin
    // old item don't have context, add one
    if Item.Context='' then
      Item.Context := Item.IdentifierLow;
      
    // if old item it's already translated use translation
    if Item.Translation<>'' then
      ATranslation := Item.Translation;

    AFlags := Item.Flags;
    // if old item was fuzzy, new should be fuzzy too.
    if (ATranslation<>'') and (pos('fuzzy', AFlags)<>0) then
      APrevStr := Item.PreviousID;

    // update identifier list
    AContext := Identifier;
  end;

  // this appear to be a new item
  FModified := true;
  Add(Identifier, Original, ATranslation, AComment, AContext, AFlags, APrevStr);
end;

procedure TPOFile.UpdateTranslation(BasePOFile: TPOFile);
var
  Item: TPOFileItem;
  i: Integer;
begin
  UntagAll;
  ClearModuleList;
  for i:=0 to BasePOFile.Items.Count-1 do begin
    Item := TPOFileItem(BasePOFile.Items[i]);
    UpdateItem(Item.IdentifierLow, Item.Original);
  end;
  RemoveTaggedItems(0); // get rid of any item not existing in BasePOFile
end;

procedure TPOFile.ClearModuleList;
begin
  if FModuleList<>nil then
    FModuleList.Clear;
end;

procedure TPOFile.AddToModuleList(Identifier: string);
var
  p: Integer;
begin
  if FModuleList=nil then begin
    FModuleList := TStringList.Create;
    FModuleList.Duplicates:=dupIgnore;
  end;
  p := pos('.', Identifier);
  if p>0 then
    FModuleList.Add(LeftStr(Identifier, P-1));
end;

procedure TPOFile.UntagAll;
var
  Item: TPOFileItem;
  i: Integer;
begin
  for i:=0 to Items.Count-1 do begin
    Item := TPOFileItem(Items[i]);
    Item.Tag:=0;
  end;
end;

{ TPOFileItem }

constructor TPOFileItem.Create(const TheIdentifierLow, TheOriginal,
  TheTranslated: string);
begin
  IdentifierLow:=TheIdentifierLow;
  Original:=TheOriginal;
  Translation:=TheTranslated;
end;

procedure TPOFileItem.ModifyFlag(const AFlag: string; Check: boolean);
var
  i: Integer;
  F: TStringList;
begin
  F := TStringList.Create;
  try

    F.CommaText := Flags;
    i := F.IndexOf(AFlag);

    if (i<0) and Check then
      F.Add(AFlag)
    else
    if (i>=0) and (not Check) then
      F.Delete(i);

    Flags := F.CommaText;

  finally
    F.Free;
  end;
end;

end.


