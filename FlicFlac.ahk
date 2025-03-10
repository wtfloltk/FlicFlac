VersionString := "1.11"
;-------------------------------------------------------------------------------
;
;  FlicFlac
;  Tiny Portable Audio Converter (WAV MP3 FLAC OGG APE M4A AAC)
;  by Danny Ben Shitrit
;  https://github.com/DannyBen/FlicFlac
;  ---------------------------------------------------------------------------
; 
;  This is a simple utility for converting WAV, FLAC, MP3, OGG, APE, M4A
;  and AAC files into any of the other formats.
;
;  It requires these command line executables: 
;  - flac.exe (FLAC converter)
;    http://sourceforge.net/project/showfiles.php?group_id=13478&package_id=12675
;    (Get flac-win.zip)
;
;  - lame.exe (MP3 converter)
;    http://www.rarewares.org/mp3-lame-bundle.php#lame-current
;    (Get the Lame Release Bundle)
; 
;  - oggenc.exe and oggdec.exe (OGG converter)
;    http://www.vorbis.com/files/1.0.1/windows/vorbis-tools-1.0.1-win32.zip
;    (Newer versions are available but seem to require some vorbis DLLs)
;
;  - MAC.exe (APE converter)
;    http://www.monkeysaudio.com/
;
;  - faad.exe (M4A/AAC converter)
;    https://www.rarewares.org/aac-decoders.php
;  
;  The external executables are only needed for the non compiled script. 
;  The compiled version of this script will swallow all external files, and will 
;  use them internally (from a temporary folder) as needed.
;
;  Please refer to the distribution Readme.txt for revision history and more
;  details
;
;-------------------------------------------------------------------------------
NameString    := "FlicFlac"
IniFile        = %A_ScriptDir%\%NameString%.ini

FileInstall FlicFlac.ini, %A_ScriptDir%\FlicFlac.ini

#SingleInstance Force
#NoTrayIcon
SetWorkingDir %A_ScriptDir%

Gosub Init
Gosub Main

Return

;-------------------------------------------------------------------------------
; MAINS
;-------------------------------------------------------------------------------
Init:
  RequiredIniVersion := 10
  MandatoryIniUpdate := true
  TmpFilename        := "~FlicFlacTmp"
  LogFilename        := A_ScriptDir . "\Log.log"

  ; Check for context menu files
  Files = %1%
  If( Files ) {       ; Sleep to prevent the GUI for showing briefly before we 
    Sleep 500         ; are killed by the SingleInstance force (in case of 
    MenuMode := true  ; multiple files).
  }               
  
  ThisYear       := A_YYYY
  WinTemp        := A_Temp
  ScriptDir      := A_ScriptDir
  
  If( FileExist( LogFilename ) )
    FileDelete %LogFilename%
    
  IniRead IniVersion, %IniFile%, Internal, IniVersion, 0
  ValidateIniVersion( IniVersion )  
  
  ; Read some INI configs  
  IniRead AbortOnError       , %IniFile%, General, AbortOnError, 1
  IniRead SupressErrors      , %IniFile%, General, SupressErrors, 0
  IniRead ConfirmBeforeDelete, %IniFile%, General, ConfirmBeforeDelete, FLAC,WAV,MP3,OGG,APE,M4A,AAC
  IniRead ExitAfterContextMenu,%IniFile%, General, ExitAfterContextMenu, 1
  IniRead OpenFolderWhenDone , %IniFile%, General, OpenFolderWhenDone, 0
  IniRead StartInactiveWhenOnTop, %IniFile%, General, StartInactiveWhenOnTop, 1
  IniRead ClassicTheme       , %IniFile%, General, ClassicTheme, 0
  IniRead ToolWindow         , %IniFile%, General, ToolWindow, 1
  IniRead IniArtist          , %IniFile%, General, Artist, % ""
  IniRead FlatButtons        , %IniFile%, General, FlatButtons, 1
  FlatButtons := FlatButtons ? "0x8000" : ""
  
  IniRead EncMode,        %IniFile%, MP3, Mode, CBR
  IniRead IniMp3Kbps,     %IniFile%, MP3, CBRKbps, 192
  IniRead IniMp3VbrLevel, %IniFile%, MP3, VBRLevel, 4
  IniRead IniMp3VbrRate,  %IniFile%, MP3, VBRRate, 32-320
  IniRead MP3Presets,     %IniFile%, MP3, Presets, % "Normal:CBR:128,CD Quality:CBR:192,Studio Quality:CBR:320,Normal VBR:VBR:4:32-320,High Quality VBR:VBR:2:64-320"
  StringSplit IniMp3VbrRate, IniMp3VbrRate, -
  MP3Presets := "Custom:" . EncMode . ":" . ( EncMode = "CBR" ? IniMp3Kbps : IniMp3VbrLevel . ":" . IniMp3VbrRate ) . ( MP3Presets <> "" ? ",," . MP3Presets : "" )
  
  IniRead IniOggQuality,   %IniFile%, OGG, Quality, 5
  
  IniRead ApeCompression,  %IniFile%, APE, Compression, 2000
  
  IniRead CleanupOnExit,   %IniFile%, Advanced, CleanupOnExit
  IniRead FlacOptions,     %IniFile%, Advanced, FlacOptions
  IniRead FlacOptionsDec,  %IniFile%, Advanced, FlacOptionsDec
  IniRead LameOptionsCBR,  %IniFile%, Advanced, LameOptionsCBR
  IniRead LameOptionsVBR,  %IniFile%, Advanced, LameOptionsVBR
  IniRead LameOptionsDec,  %IniFile%, Advanced, LameOptionsDec
  IniRead OggOptions,      %IniFile%, Advanced, OggOptions
  IniRead OggOptionsDec,   %IniFile%, Advanced, OggOptionsDec
  IniRead FaadOptions,     %IniFile%, Advanced, FaadOptions
  IniRead TempFolder,      %IniFile%, Advanced, TempFolder
  Transform TempFolder, Deref, %TempFolder%
  
  IniRead DebugMode,    %IniFile%, Advanced, DebugMode, 0
  If( DebugMode > 1 )
    Log( "Info", "Simulation only, no action is taken" )
  
  IniRead BaseDir,      %IniFile%, Recent, Dir, %A_ScriptDir%
  IniRead WinX,         %IniFile%, Recent, WinX, Center
  IniRead WinY,         %IniFile%, Recent, WinY, Center
  IniRead ActivePreset, %IniFile%, Recent, MP3Preset, CD Quality

  If( BaseDir = "" )
    BaseDir := A_ScriptDir
  FixCoordinates( WinX, WinY )
    
  IniRead SelectedFormat  ,%IniFile%, Recent, SelectedFormat, 1
  IniRead GuiAlwaysOnTop  ,%IniFile%, Recent, AlwaysOnTopState, 1
  IniRead GuiDeleteInput  ,%IniFile%, Recent, DeleteInputState, 1  

  FFMpegLocation := TempFolder . "\ffmpeg.exe"
  ApeLocation    := TempFolder . "\MAC.exe"      
  FlacLocation   := TempFolder . "\flac.exe"      
  LameLocation   := TempFolder . "\lame.exe"      
  OggEncLocation := TempFolder . "\oggenc.exe"
  OggDecLocation := TempFolder . "\oggdec.exe"
  FaadLocation   := TempFolder . "\faad.exe"
  
  ; Install encoders

  FileInstall ffmpeg.exe, %FFMpegLocation%
  FileInstall MAC.exe, %ApeLocation%
  FileInstall flac.exe, %FlacLocation%
  FileInstall lame.exe, %LameLocation%
  FileInstall oggenc.exe, %OggEncLocation%
  FileInstall oggdec.exe, %OggDecLocation%
  FileInstall faad.exe, %FaadLocation%
  
  ; Make sure we can find our command line converters
  ErrString := ""
  If( Not FileExist( FlacLocation ) )
    ErrString .= "Missing flac.exe (" . FlacLocation . ")`n"
  If( Not FileExist( LameLocation ) )
    ErrString .= "Missing lame.exe (" . LameLocation . ")`n"
  If( Not FileExist( OggEncLocation ) )
    ErrString .= "Missing oggenc.exe (" . OggEncLocation . ")`n"
  If( Not FileExist( OggDecLocation ) )
    ErrString .= "Missing oggdec.exe (" . OggDecLocation . ")`n"
  If( Not FileExist( ApeLocation ) )
    ErrString .= "Missing MAC.exe (" . MacLocation . ")`n"
  If( Not FileExist( FaadLocation ) )
    ErrString .= "Missing faad.exe (" . FaadLocation . ")`n"
  If( Not FileExist( FFMpegLocation ) )
    ErrString .= "Missing ffmpeg.exe (" . FlacLocation . ")`n"

  If( ErrString ) {
    ErrorMessage( "Some files that are required for the operation of " . NameString . " are missing.`n`n" . ErrString )
    Gosub Exit
  }
  
  Gosub BuildMenu

Return


Main:
  InFormats     := "FLAC|WAV|MP3|OGG|APE|M4A|AAC"
  OutFormats    := "FLAC|WAV|MP3|OGG|APE"
  InExtensions  := "[wav][mp3][ogg][ape][m4a][aac]|[flac][mp3][ogg][ape][m4a][aac]|[wav][flac][ogg][ape][mp3][m4a][aac]|[wav][flac][mp3][ape][m4a][aac]|[wav][flac][mp3][ogg][m4a][aac]"
  InFileFilters := "Audio to FLAC (*.wav; *.mp3; *.ogg; *.ape; *.m4a; *.aac)|Audio to WAV (*.flac; *.mp3; *.ogg; *.ape; *.m4a; *.aac)|Audio to MP3 (*.wav; *.flac; *.ogg; *.mp3; *.ape; *.m4a; *.aac)|Audio to OGG (*.wav; *.flac; *.mp3; *.ape; *.m4a; *.aac)|Audio to APE (*.wav; *.flac; *.mp3; *.ogg; *.m4a; *.aac)"
  
  StringSplit OutFormat, OutFormats, |
  StringSplit InFileFilter, InFileFilters, |
  StringSplit InFormat, InFormats, |
  StringSplit InExtension, InExtensions, |

  If( ClassicTheme ) {
    Gui -Theme
  }
  If( ToolWindow ) {
    Gui +ToolWindow
  }

  Gui Margin, 4,4
  Gui +OwnDialogs
  Gui Color, EEEEEE,DDDDDD
  Gui Font, s10, MS Sans Serif
  Gui Add, Button, %FlatButtons% w110 h136 section Default vGuiMainBtn gSelectFilesBtn, % "&Select or`nDrop Files"
  Gui Font, s9 
  Gui Add, Radio, %FlatButtons% +0x1000 x+4 yp w70 h24 -Wrap Checked vGuiOutFormat, % "to &" . OutFormat1
  Gui Add, Radio, %FlatButtons% +0x1000 wp hp -Wrap                         , % "to &" . OutFormat2
  Gui Add, Radio, %FlatButtons% +0x1000 wp hp -Wrap                         , % "to &" . OutFormat3
  Gui Add, Radio, %FlatButtons% +0x1000 wp hp -Wrap                         , % "to &" . OutFormat4
  Gui Add, Radio, %FlatButtons% +0x1000 wp hp -Wrap                         , % "to &" . OutFormat5
  Gui Font, s9
  Gui Add, Progress, xs w184 h8 vGuiProgress cBlack BackgroundCCCCCC   , 0
  
  Gui Add, Checkbox, h16 wp-38 section checked%GuiDeleteInput% vGuiDeleteInput   , &Delete input file
  Gui Add, Checkbox, hp wp checked%GuiAlwaysOnTop% vGuiAlwaysOnTop gToggleOnTop , &Always on top
  Gui Font, s12, Webdings
  Gui Add, Button  , %FlatButtons% x+4 ys w34 h34 gShowMenu, @
  Gui Font, s9, MS Sans Serif
  
  GuiControl ,,% "to &" . OutFormat%SelectedFormat%, 1
  
  If( MenuMode ) 
    GuiControl ,,GuiMainBtn, &Start

  NAString := ""
  If( GuiAlwaysOnTop ) {
    Gui +AlwaysOnTop
    If( StartInactiveWhenOnTop )
      NAString := "NoActivate"
  }

  Gui Show,x%WinX% y%WinY% %NAString%,%NameString%
  
Return


;-------------------------------------------------------------------------------
; SELECT FILES - BUTTON OR DROP
;-------------------------------------------------------------------------------
SelectFilesBtn:
  Gui Submit, NoHide
  If( MenuMode or Files := SelectFiles( BaseDir, InFileFilter%GuiOutFormat% ) ) {
    Files := CleanFileList( Files, InExtension%GuiOutFormat% )
    Convert( Files, OutFormat%GuiOutFormat%, GuiDeleteInput )
    If( MenuMode ) {
      If( ExitAfterContextMenu )
        Gosub Exit
      Else {
        MenuMode := false
        GuiControl,,GuiMainBtn, &Select / Drop`n        Files
      }
    }
  }
Return

GuiDropFiles:
  ; Handle files and folders that are dropped on the GUI.
  ; Files with the wrong extension will be cleaned out of the list.
  
  Gui Submit, NoHide
  Files := A_GuiEvent
  StringSplit File, Files, `n
  SplitPath File1, Filename, Dir, Extension, NameNoExt, Drive
  BaseDir := Dir
  
  If( RegExMatch( A_GuiControl, "^to |GuiOutFormat" ) ) {
    GuiControl ,,%A_GuiControl%, 1
    Gui Submit, NoHide
  }
  
  If( A_GuiControl = "GuiMainBtn" or RegExMatch( A_GuiControl, "^to |GuiOutFormat" ) ) {
    Files := CleanFileList( ExpandFileList( Files ), InExtension%GuiOutFormat% )
    Convert( Files, OutFormat%GuiOutFormat%, GuiDeleteInput )
    If( MenuMode ) {
      MenuMode := false
      GuiControl,,GuiMainBtn, &Select / Drop`n        Files
    }
  }
Return


;-------------------------------------------------------------------------------
; CONVERSION FUNCTION
;-------------------------------------------------------------------------------
Convert( files, outFormat, delSource=false ) {
  ; Gets a list of newline separated file names (full path), and an output 
  ; format (e.g. MP3) and converts all the files.
  ; The list of files is expected to be valid (i.e. only WAV/FLAC files for any 
  ; "to MP3" conversion).
  ; If delSource is true, we will delete the source after doing our best to 
  ; ensure a successful conersion was done.
  
  Global AbortOnError, SupressErrors, ConfirmDeleteAll, ConfirmOverwrite
  
  ConfirmDeleteAll    := ""   ; These two variables are used by deeper routines
  ConfirmOverwrite    := ""   ; and need to be reset at the beginning of the loop
  SkippedFiles        := ""
  
  Gosub LockGui
  StringSplit File, files, `n
  Loop %File0% {
    RetCode := ConvertSingleFile( File%A_Index%, outFormat )
    SplitPath File%A_Index%,,,InExtension
    If( RetCode = "Success" ) { 
      If( delSource and InExtension != outFormat ) {
        DelFile( File%A_Index% )
      }
    }
    Else If( RetCode = "Error" ) {
      ErrorMessage( "Failed to convert`n" . File%A_Index% )       
      If( AbortOnError and Not SupressErrors )
        Break
    }
    Else If( RetCode = "NoOverwrite" ) {
      Skipped .= File%A_Index% . "`n"
    }
  }
  
  Gosub UnlockGui 
  Gui +OwnDialogs
  If( Skipped )
    Msgbox 64,Skipped Some Files,The following file(s) were skipped at your request:`n`n%Skipped%
}

ConvertSingleFile( inFileFullName, outFormat ) {
  ; Gets a full filename and an output format and converts the file to its own 
  ; folder.
  ; Returns a string:
  ;   "Error" if unable to convert (encoder error)
  ;   "Success" on successful conversion.
  ;   "NoOverwrite" if the output file exists and the user chose not to overwrite
  ;
  ; This function can also deal with conversions that require two calls to the
  ; external converters (e.g. FLAC2MP3)
  
  Global TmpFilename, DebugMode
  
  Result := "Error"
  
  SplitPath inFileFullName, Filename, Dir, Extension, NameNoExt, Drive
  If( Dir = "" or Filename = "" or outFormat = "" )
    Return Result    

  SetWorkingDir %Dir%
  If( Not OkToOverwrite( NameNoExt . "." . outFormat ) )
    Return "NoOverwrite"
    
  CmdTemplates := GetCommandLine( Extension . "2" . outFormat )
  StringSplit CmdTemplate, CmdTemplates, `n
  
  If( FileExist( Filename ) and CmdTemplate1 <> "" ) {
    Transform CommandLine, Deref, %CmdTemplate1%
    Log( "Run", CommandLine )
    If( DebugMode < 2 )
      RunWait %CommandLine%,, Hide UseErrorLevel
      
    If( Not ErrorLevel ) {
      If( CmdTemplate2 = "" ) {
        Result := "Success"
      }
      Else {
        Filename := NameNoExt . "." . CmdTemplate3 
        Transform CommandLine, Deref, %CmdTemplate2%
        Log( "Run", CommandLine )
        
        If( DebugMode < 2 )
          RunWait %CommandLine%,, Hide UseErrorLevel
        If( Not ErrorLevel ) {
          Result := "Success"
        }
        Log( "Delete", TmpFilename . "." . CmdTemplate3 )
        If( DebugMode < 2 )
          FileDelete %TmpFilename%.%CmdTemplate3% ; Delete the temp output
      }
    }
  }
  SetWorkingDir %A_ScriptDir%
  Return Result
}

;-------------------------------------------------------------------------------
; CONVERSION HELPERS AND FILE LIST HANDLERS
;-------------------------------------------------------------------------------
GetCommandLine( contype ) {
  ; Gets a conversion type string (e.g. "WAV2MP3") and returns the command line
  ; template needed to make the conversion.
  ; The template contains %variables% that are later replaced by the Convert 
  ; function (e.g. InFile)
  ; In some cases, we will return a newline separated string of more than one
  ; command line.

  Global FlacOptions, FlacOptionsDec, FlacLocation, LameLocation, ApeLocation
  Global FaadLocation, FaadOptions
  Global LameOptionsVBR, LameOptionsCBR, LameOptionsDec, EncMode, ApeCompression
  Global OggEncLocation, OggDecLocation, OggOptions, OggOptionsDec
  Global TmpFilename

  LameOptions := LameOptions%EncMode%
  
  ; Native
  clWAV2MP3   = "%FFMpegLocation%" -i "`%Filename`%" -af "pan=7.1|c0=c0-c1+c2+c3-c4+c5+c6|c1=c7-c8+c9+c10+c11+c12|c2=c31+c1-c30|c3=c13+c14|c4=c0+c1+c2-c19+c22+c29|c5=c15+c16+c17-c18|c6=c20+c21-c22+c23+c24+c25|c7=c26+c27-c28+c29+c30-c31" | "%LameLocation%" %LameOptions% - "`%NameNoExt`%.mp3"
  clWAV2OGG   = "%FFMpegLocation%" -i "`%Filename`%" -af "pan=7.1|c0=c0-c1+c2+c3-c4+c5+c6|c1=c7-c8+c9+c10+c11+c12|c2=c31+c1-c30|c3=c13+c14|c4=c0+c1+c2-c19+c22+c29|c5=c15+c16+c17-c18|c6=c20+c21-c22+c23+c24+c25|c7=c26+c27-c28+c29+c30-c31" | "%OggEncLocation%" %OggOptions% -
  clWAV2APE   = "%FFMpegLocation%" -i "`%Filename`%" -af "pan=7.1|c0=c0-c1+c2+c3-c4+c5+c6|c1=c7-c8+c9+c10+c11+c12|c2=c31+c1-c30|c3=c13+c14|c4=c0+c1+c2-c19+c22+c29|c5=c15+c16+c17-c18|c6=c20+c21-c22+c23+c24+c25|c7=c26+c27-c28+c29+c30-c31" | "%ApeLocation%" - "`%NameNoExt`%.ape" -c%ApeCompression%
  clWAV2FLAC  = "%FFMpegLocation%" -i "`%Filename`%" -af "pan=7.1|c0=c0-c1+c2+c3-c4+c5+c6|c1=c7-c8+c9+c10+c11+c12|c2=c31+c1-c30|c3=c13+c14|c4=c0+c1+c2-c19+c22+c29|c5=c15+c16+c17-c18|c6=c20+c21-c22+c23+c24+c25|c7=c26+c27-c28+c29+c30-c31" | "%FlacLocation%" %FlacOptions% -
  clMP32WAV   = "%LameLocation%" %LameOptionsDec% "`%Filename`%" "`%NameNoExt`%.wav"
  clFLAC2WAV  = "%FlacLocation%" %FlacOptionsDec% "`%Filename`%"
  clFLAC2OGG  = "%OggEncLocation%" %OggOptions% "`%Filename`%"
  clOGG2WAV   = "%OggDecLocation%" %OggOptionsDec% "`%Filename`%"
  clAPE2WAV   = "%ApeLocation%" "`%Filename`%" "`%NameNoExt`%.wav" -d
  clM4A2WAV   = "%FaadLocation%" %FaadOptions% -o "`%NameNoExt`%.wav" "`%Filename`%" 
  clAAC2WAV   = "%FaadLocation%" %FaadOptions% -o "`%NameNoExt`%.wav" "`%Filename`%" 

  ; HYBRIDS, return two command lines and the extension of the temporary convert
  ; We could have used a combination of the above, but we want to use a file with 
  ; a temporary name for the first output (and second input)
  clFLAC2MP3  = "%FlacLocation%" %FlacOptionsDec% "`%Filename`%" -o "%TmpFilename%.wav"`n"%LameLocation%" %LameOptions% "%TmpFilename%.wav" "`%NameNoExt`%.mp3"`nWAV
  clFLAC2APE  = "%FlacLocation%" %FlacOptionsDec% "`%Filename`%" -o "%TmpFilename%.wav"`n"%ApeLocation%" "%TmpFilename%.wav" "`%NameNoExt`%.ape" -c%ApeCompression%`nWAV
  
  clMP32FLAC  = "%LameLocation%" %LameOptionsDec% "`%Filename`%" "%TmpFilename%.wav"`n"%FlacLocation%" %FlacOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.flac"`nWAV
  clMP32OGG   = "%LameLocation%" %LameOptionsDec% "`%Filename`%" "%TmpFilename%.wav"`n"%OggEncLocation%" %OggOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.ogg"`nWAV
  clMP32APE   = "%LameLocation%" %LameOptionsDec% "`%Filename`%" "%TmpFilename%.wav"`n"%ApeLocation%" "%TmpFilename%.wav" "`%NameNoExt`%.ape" -c%ApeCompression%`nWAV
  
  clOGG2FLAC  = "%OggDecLocation%" %OggOptionsDec% "`%Filename`%" -o "%TmpFilename%.wav"`n"%FlacLocation%" %FlacOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.flac"`nWAV
  clOGG2MP3   = "%OggDecLocation%" %OggOptionsDec% "`%Filename`%" -o "%TmpFilename%.wav"`n"%LameLocation%" %LameOptions% "%TmpFilename%.wav" "`%NameNoExt`%.mp3"`nWAV
  clOGG2APE   = "%OggDecLocation%" %OggOptionsDec% "`%Filename`%" -o "%TmpFilename%.wav"`n"%ApeLocation%" "%TmpFilename%.wav" "`%NameNoExt`%.ape" -c%ApeCompression%`nWAV
  
  clAPE2MP3   = "%ApeLocation%" "`%Filename`%" "%TmpFilename%.wav" -d`n"%LameLocation%" %LameOptions% "%TmpFilename%.wav" "`%NameNoExt`%.mp3"`nWAV
  clAPE2OGG   = "%ApeLocation%" "`%Filename`%" "%TmpFilename%.wav" -d`n"%OggEncLocation%" %OggOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.ogg"`nWAV
  clAPE2FLAC  = "%ApeLocation%" "`%Filename`%" "%TmpFilename%.wav" -d`n"%FlacLocation%" %FlacOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.flac"`nWAV

  ; M4A2* and AAC2* are the same
  clM4A2FLAC  = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%FlacLocation%" %FlacOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.flac"`nWAV
  clAAC2FLAC  = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%FlacLocation%" %FlacOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.flac"`nWAV
  clM4A2MP3   = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%LameLocation%" %LameOptions% "%TmpFilename%.wav" "`%NameNoExt`%.mp3"`nWAV
  clAAC2MP3   = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%LameLocation%" %LameOptions% "%TmpFilename%.wav" "`%NameNoExt`%.mp3"`nWAV
  clM4A2OGG   = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%OggEncLocation%" %OggOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.ogg"`nWAV
  clAAC2OGG   = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%OggEncLocation%" %OggOptions% "%TmpFilename%.wav" -o "`%NameNoExt`%.ogg"`nWAV
  clM4A2APE   = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%ApeLocation%" "%TmpFilename%.wav" "`%NameNoExt`%.ape" -c%ApeCompression%`nWAV
  clAAC2APE   = "%FaadLocation%" %FaadOptions% -o "%TmpFilename%.wav" "`%Filename`%"`n"%ApeLocation%" "%TmpFilename%.wav" "`%NameNoExt`%.ape" -c%ApeCompression%`nWAV
  
  ; Special Case MP3 to MP3
  clMP32MP3  = "%ComSpec%" /c copy "`%Filename`%" "%TmpFilename%.mp3"`n"%LameLocation%" %LameOptions% "%TmpFilename%.mp3" "`%NameNoExt`%.mp3"`nMP3
  
  Return cl%contype%
}

CleanFileList( list, ext ) { 
  ; Gets a list of newline separated filenames, and bracketed extensions string
  ; (e.g. "[mp3][wav]") and returns a newline separated list of files that have 
  ; the desired extensions.
  
  Result := ""
  StringSplit Item, list, `n
  Loop %Item0% {
    SplitPath Item%A_Index%, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive

    If( OutDir = "" )                   ; Make sure we end up only with a valid 
      Continue                          ; list (i.e. all full names)

    If( InStr( ext, "[" . OutExtension . "]" ) ) {
      Result .= OutDir . "\" . OutFilename . "`n"      
    }
  }
  StringTrimRight Result, Result, 1
  Return Result
}

ExpandFileList( list ) {
  ; Gets a list of newline separated files that may contain folder items and
  ; returns a list of all the files in these folders (like dir /s/b...)
  
  StringSplit Item, list, `n
  
  Result := ""
  Loop %Item0% {
    ThisItem := Item%A_Index%
    AttributeString := FileExist( ThisItem )
    If( InStr( AttributeString, "D" ) )
      Loop %ThisItem%\*.*, 0,1
        Result .= A_LoopFileLongPath . "`n"

    Else
      Result .= ThisItem . "`n"
  }
  StringTrimRight Result, Result, 1 
  Return Result
}


;-------------------------------------------------------------------------------
; GUI HELPERS
;-------------------------------------------------------------------------------
LockGui:
  ; When disabling the main GUI, it also loses its alt-tab icon.
  ; To avoid that, we create a secondary hidden owned GUI - so the result is that
  ; the main GUI is disabled, and still has an alt-yab icon.
  
  GuiControl +0x8,GuiProgress
  SetTimer UpdateProgress, 10 
  CustomColor = EEAA99  ; Can be any RGB color (it will be made transparent below).
  Gui 2:+Owner1
  Gui 2:+LastFound -Caption
  Gui 2:Color, %CustomColor%
  WinSet TransColor, %CustomColor% 255
  Gui 2:Default
  Gui 2:Show, x1 y1 w1 h1
  Gui 1:+Disabled
Return

UnlockGui:
  Gui 1:-Disabled
  Gui 2:Destroy
  Gui 1:Default
  SetTimer UpdateProgress, Off
  GuiControl -0x8,GuiProgress
  GuiControl ,,GuiProgress,0
  If( OpenFolderWhenDone ) 
    Run %BaseDir%
Return

UpdateProgress:
  ; This routine will be called by timer, while we are waiting for the command
  ; line to finish.
  
  GuiControl,,GuiProgress,1
Return

SelectFiles( dir, filter ) {
  ; Opens a Select File dialog with a given file filter, and returns a newline 
  ; separated list of files, using full names.
  
  Global BaseDir

  FileSelectFile FileList, M, %dir%, Select a file to convert, %filter%
  If( ErrorLevel )
    Return false
    
  StringSplit File, FileList, `n
  
  Result := ""
  BaseDir := File1
  Loop %File0% 
    If( A_Index <> 1 )
      Result .= BaseDir . "\" . File%A_Index% . "`n"
    
  Result := ExpandFileList( Result )
  StringTrimRight Result, Result, 1
    
  Return Result
}

ToggleOnTop:
  Gui +LastFound
  WinSet AlwaysOnTop, Toggle
Return

GuiContextMenu:
  Gosub ShowMenu
Return

GuiEscape:
GuiClose:
  Gosub Exit
Return

CMsgBox( title, text, buttons, icon="", owner=0 ) {
  ; Displays a custom message box
  
  Global _CMsg_Result
  
  GuiID := 9      ; If you change, also change the subroutines below
  
  StringSplit Button, buttons, |
  
  If( owner <> 0 ) {
    Gui %owner%:+Disabled
    Gui %GuiID%:+Owner%owner%
  }

  Gui %GuiID%:+Toolwindow +AlwaysOnTop
  
  MyIcon := ( icon = "I" ) or ( icon = "" ) ? 222 : icon = "Q" ? 24 : icon = "E" ? 110 : icon
  
  Gui %GuiID%:Add, Picture, Icon%MyIcon% , Shell32.dll
  Gui %GuiID%:Add, Text, x+12 yp w180 r8 section , %text%
  
  Loop %Button0% 
    Gui %GuiID%:Add, Button, % ( A_Index=1 ? "x+12 ys " : "xp y+3 " ) . ( InStr( Button%A_Index%, "*" ) ? "Default " : " " ) . "w100 gCMsgButton", % RegExReplace( Button%A_Index%, "\*" )

  Gui %GuiID%:Show,,%title%
  
  Loop 
    If( _CMsg_Result )
      Break

  If( owner <> 0 )
    Gui %owner%:-Disabled
    
  Gui %GuiID%:Destroy
  Result := _CMsg_Result
  _CMsg_Result := ""
  Return Result
}

9GuiEscape:
9GuiClose:
  _CMsg_Result := "Close"
Return

CMsgButton:
  StringReplace _CMsg_Result, A_GuiControl, &,, All
Return


;-------------------------------------------------------------------------------
; MENU
;-------------------------------------------------------------------------------
BuildMenu:

  Menu MP3Menu, UseErrorLevel

  SelectedPresetNumber := 0

  StringSplit PresetString, MP3Presets, `,
  Loop %PresetString0% {
    PresetPart1 := ""
    StringSplit PresetPart, PresetString%A_Index%, :
    If( PresetPart1 = "" )
      Menu MP3Menu, Add
    Else
      Menu MP3Menu, Add, %PresetPart1%, MP3MenuClick
    If( PresetPart1 = ActivePreset )
      SelectedPresetNumber := A_Index
  }

  If( SelectedPresetNumber = 0 )
    SelectedPresetNumber := 1
    
  SelectPreset( SelectedPresetNumber )
  
  Menu, ShellMenu, Add, &Enable, InstallContextMenu
  Menu, ShellMenu, Add, &Disable, UninstallContextMenu

  Menu Main, Add, &MP3 Presets, :MP3Menu
  Menu Main, Add
  Menu Main, Add, &Shell Integration, :ShellMenu
  Menu Main, Add, Open &INI File, OpenINI
  Menu Main, Add
  If( FileExist( "Readme.txt" ) )
    Menu Main, Add, View &Readme File, Readme
  Menu Main, Add, &About, About
Return

ShowMenu:
  Menu Main, Show, 156,184
Return

MP3MenuClick:
  SelectPreset( A_ThisMenuItemPos ) 
Return

SelectPreset( presetNumber ) {
  Local PresetPart
  
  ; Handle the menu checkmarks
  StringSplit PresetPart, PresetString%SelectedPresetNumber%, :
  Menu MP3Menu, Uncheck, %PresetPart1%
  StringSplit PresetPart, PresetString%presetNumber%, :
  Menu MP3Menu, Check, %PresetPart1%
  
  SelectedPresetNumber := presetNumber
  
  ; Assign the preset values to our globals
  EncMode := RegExMatch( PresetPart2, "i)vbr|cbr" ) ? PresetPart2 : "CBR"
  IniMp3Kbps := EncMode = "VBR" ? IniMp3Kbps : RegExMatch( PresetPart3, "^\d+$" ) ? PresetPart3 : "192"
  IniMp3VbrLevel:= RegExMatch( PresetPart3, "^\d$" ) ? PresetPart3 : "4"
  IniMp3VbrRate := RegExMatch( PresetPart4, "^\d+-\d+$" ) ? PresetPart4 : "32-320"  
  
  ; Store active preset in INI
  IniWrite %PresetPart1%, %IniFile%, Recent, MP3Preset
}

;-------------------------------------------------------------------------------
; OTHERS
;-------------------------------------------------------------------------------
ErrorMessage( msg ) {
  Global SupressErrors
  
  If( SupressErrors )
    Return
    
  Gui 1:+OwnDialogs
  Msgbox 48,An error has occured,%msg%
}

DelFile( file ) {
  ; Used for deletion of input files. Will be called only when the delete
  ; checkbox is checked.
  ; If configured, we will confirm with the user before deleting.
  ; It will also set the ConfirmDeleteAll variable if the user selected "Yes to 
  ; All" or "No to All" and will use it for subsequent calle.
  ; It is up to the caller to reset this variable when this batch of files is
  ; completed.
  
  Global ConfirmBeforeDelete, ConfirmDeleteAll, DebugMode
  
  SplitPath file, Filename, Dir, Extension, NameNoExt, Drive
  
  If( file = "" or Extension = "" )   ; Just some protection
    Return
  
  NeedToConfirm := ( ConfirmDeleteAll = "" ) and ( RegExMatch( ConfirmBeforeDelete, "i)\b(" . Extension . ")\b", Match ) )
  If( NeedToConfirm ) {
    Answer := CMsgBox( "Confirm Delete", "Delete input " . Match1 . "?`n" . filename , "*&Yes|&No|Yes to &All|No to A&ll", "Q", 1 )
    If( Answer = "Yes" or Answer = "Yes to All" ) {
      Log( "Delete", file )
      If( DebugMode < 2 )
        FileDelete %file%
      If( Answer = "Yes to All" ) {
        ConfirmDeleteAll := "YesAll"
      }
    }
    Else If( Answer = "No to All" )
      ConfirmDeleteAll := "NoAll"
  }
  Else If( ConfirmDeleteAll <> "NoAll" ) {
    Log( "Delete", file )
    If( DebugMode < 2 )
      FileDelete %file%
  }
}

OkToOverwrite( file ) {
  ; Returns true if the file does not exist, or if the user okayed it for
  ; overwriting.
  ; It will also set the ConfirmOverwrite variable if the user selected "Yes to 
  ; All" or "No to All" and will use it for subsequent calle.
  ; It is up to the caller to reset this variable when this batch of files is
  ; completed.

  Global ConfirmBeforeDelete, ConfirmOverwrite

  SplitPath file, Filename, Dir, Extension, NameNoExt, Drive  
  NeedToConfirm := ( RegExMatch( ConfirmBeforeDelete, "i)\b(" . Extension . ")\b", Match ) )

  If( Not NeedToConfirm or ConfirmOverwrite = "YesAll" or Not FileExist( file ) ) 
    Return true
  Else If( ConfirmOverwrite = "NoAll" )
    Return false
  Else {
    Answer := CMsgBox( "Confirm Overwrite", "Overwrite output " . Match1 . "?`n" . file, "*&Yes|&No|Yes to &All|No to A&ll", "Q", 1 )
    
    ConfirmOverwrite := Answer = "Yes" ? "Yes" : Answer = "Yes to All" ? "YesAll" : Answer = "No to All" ? "NoAll" : "No"
    Return ( ConfirmOverwrite = "Yes" ) or ( ConfirmOverwrite = "YesAll" )
  }
  
  Return false
}

OpenINI:
  IfNotExist %IniFile%
    Return
    
  FileGetTime BeforeTime, %IniFile%, M
  RunWait %IniFile%
  FileGetTime AfterTime, %IniFile%, M
  If( BeforeTime <> AfterTime )
    Gosub Reload

Return

About:
  Gui 1:+OwnDialogs
  msg = %NameString% v%VersionString%`nby Danny Ben Shitrit`nSector Seven`n`nwww.sector-seven.com  
  Answer := CMsgBox( "About FlicFlac", msg, "*&Close|&Homepage|&GitHub", "I", 1 )
  
  If( Answer == "Homepage" )
    Run https://www.sector-seven.com/
  Else If( Answer == "GitHub" )
    Run https://github.com/DannyBen

Return

Readme:
  If( FileExist( "Readme.txt" ) )
    Run Readme.txt
Return

FixCoordinates( ByRef WinX, ByRef WinY ) {
  ; Called before we show the window, in order to make sure the coordinates
  ; are in the visible desktop.

  SysGet ScreenTop, 76
  SysGet ScreenLeft, 77
  SysGet ScreenWidth, 78
  SysGet ScreenHeight, 79
  ScreenRight := ScreenLeft + ScreenWidth
  ScreenBottom := ScreenTop + ScreenHeight
  
  If( WinX < ScreenLeft ) 
    or ( WinX > ScreenRight-200 )
    or ( WinY < ScreenTop )
    or ( WinY > ScreenBottom-200 ) {
    WinX := "Center"
    WinY := "Center"
  }
}

ValidateIniVersion( foundVersion ) {
  ; Validates that we have a compatible INI file.
  ; If not, we will ask the user's permission to delete the existing INI and
  ; extract a fresh INI copy from the EXE.
  Global RequiredIniVersion, IniFile, MandatoryIniUpdate
  
  If( foundVersion = "" or foundVersion < RequiredIniVersion ) {
    Gui 1:+OwnDialogs
    Msgbox 36,Outdated INI File,Your configuration INI file seems to be from an older version.`nWould you like to update it now (recommended)?
    IfMsgBox Yes
    {
      If( A_IsCompiled )
        FileDelete %IniFile%
      Else
        Msgbox In the compiled version, the INI fill be deleted here
        
      Reload
      Sleep 2000      ; This is needed since AHK still manages to squeeze
                      ; some time to return, and show the GUI for a second.
    }
    
    IfMsgBox No
    {
      If( MandatoryIniUpdate ) {
        Msgbox 64, INI Update is Mandatory, Configuration file update is mandatory for this version.`nUnable to proceed.
        ExitApp
      }
    }
  }
}


PreExit:
  Gui Submit, NoHide

  IfWinExist %NameString% ahk_Class AutoHotkeyGUI
  {
    Gui +LastFound
    WinGetPos X,Y
    FixCoordinates( X, Y )
    IniWrite %BaseDir%, %IniFile%, Recent, Dir
    IniWrite %X%, %IniFile%, Recent, WinX
    IniWrite %Y%, %IniFile%, Recent, WinY
    IniWrite %GuiDeleteInput%, %IniFile%, Recent, DeleteInputState
    IniWrite %GuiAlwaysOnTop%, %IniFile%, Recent, AlwaysOnTopState
    IniWrite %GuiOutFormat%, %IniFile%, Recent, SelectedFormat
  }
Return

Log( action, string ) {
  Global DebugMode, LogFilename
  If( DebugMode < 1 )
    Return
  action := SubStr( action . "              ", 1, 10 )
  FileAppend %action% %string%`n, %LogFilename%
}

Reload:
  Gosub PreExit
  Reload
Return

Exit:
  Gosub PreExit
  
  ; Clean the temp binaries
  If( A_IsCompiled and CleanupOnExit ) {
    FileDelete %ApeLocation%
    FileDelete %FlacLocation%
    FileDelete %LameLocation%
    FileDelete %OggDecLocation%
    FileDelete %OggEncLocation%
    FileDelete %FaadLocation%
  }
  ExitApp
Return

IsAdmin() {
  if( !A_IsAdmin ) {
    Gui 1:+OwnDialogs
    MsgBox 68,Administrator Rights Needed,This action requires administrator rights.`n`nWould you like to run FlicFlac as Administrator?
    IfMsgBox Yes
    {
      If( A_IsCompiled )
        Run *RunAs "%A_ScriptFullPath%"
      Else
        Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
      ExitApp
    }
    Else
      Return false
  }
  Return true
}


;-------------------------------------------------------------------------------
; CONTEXT MENU FUNCTIONS
;-------------------------------------------------------------------------------
InstallContextMenu:
  If( !IsAdmin() ) {
    Return 
  }
  
  If( A_IsCompiled )
    MenuCommand = "%A_ScriptDir%\%A_ScriptName%" "`%1"
  Else
    MenuCommand = "%A_AhkPath%" "%A_ScriptDir%\%A_ScriptName%" "`%1"
    
  Loop %InFormat0% {
    Success := CM_AddMenuItem( InFormat%A_Index%, "Convert with &FlicFlac", MenuCommand )
    If( !Success ) {
      ErrorMessage( "Unable to install shell integration.`n`nPlease run FlicFlac as administrator." )
      break
    }
  }
  
  If( Success ) {
    Gui 1:+OwnDialogs
    Msgbox 64,Shell Integration Enabled, Shell integration was enabled.`n`nYou may now convert files by right clicking them in Windows Explorer.
  }
  
  
Return

UninstallContextMenu:
  If( !IsAdmin() ) {
    Return 
  }
  
  Loop %OutFormat0% {
    Success := CM_DelMenuItem( OutFormat%A_Index%, "Convert with FlicFlac" )
    If( !Success ) {
      ErrorMessage( "Unable to remove shell integration.`n`nPlease run FlicFlac as administrator." )
      Break
    }
  }
  If( Success ) {
    Gui 1:+OwnDialogs
    MsgBox 64,Shell Integration Disabled, Shell integration was disabled.
  }
Return

;-------------------------------------------------------------------------------
; CONTEXT MENU LIBRARY
;-------------------------------------------------------------------------------
CM_AddMenuItem( ext, label, command ) {
  If( ext = "" or label = "" or command = "" )
    Return false
    
  CleanLabel := RegExReplace( label, "\W", "" )
  FileType := ""
  RegRead FileType, HKCR, .%ext%
  If( FileType == "" ) {
    FileType = %ext% file
    RegWrite REG_SZ, HKCR, .%ext%,,%FileType%
  }
    
  RegWrite REG_SZ, HKCR, %FileType%\shell\%CleanLabel%,, %label%
  RegWrite REG_SZ, HKCR, %FileType%\shell\%CleanLabel%\command,, %command%
  
  If( ErrorLevel )
    Return false
  
  Return true
}


CM_DelMenuItem( ext, label ) {
  If( ext = "" or label = "" )
    Return false
    
  CleanLabel := RegExReplace( label, "\W", "" )
  FileType := ""
  RegRead FileType, HKCR, .%ext%
  If( FileType == "" )
    Return false

  RegRead KeyExists, HKCR, %FileType%\shell\%CleanLabel%
  If( !KeyExists ) 
    Return true
        
  RegDelete HKCR, %FileType%\shell\%CleanLabel%

  If( ErrorLevel )
    Return false

  Return true
}


;-------------------------------------------------------------------------------
; Hotkeys
;-------------------------------------------------------------------------------
#IfWinActive FlicFlac ahk_Class AutoHotkeyGUI
F8::Gosub ShowMenu


;-------------------------------------------------------------------------------

