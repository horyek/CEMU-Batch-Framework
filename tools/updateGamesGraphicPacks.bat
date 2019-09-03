@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!

        exit 1
    )

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "brcPath="!BFW_RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""

    REM : optional second arg
    set "GAME_FOLDER_PATH="NONE""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""

    set "myLog="!BFW_PATH:"=!\logs\updateGamesGraphicPacks.log""

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

    REM : cd to GAMES_FOLDER
    pushd !GAMES_FOLDER!

    REM : flag to create leagcy packs
    set "createLegacyPacks=true"

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"

    @echo ========================================================= > !myLog!

    if %nbArgs% NEQ 2 (
        @echo ERROR ^: on arguments passed ^!  >> !myLog!
        @echo SYNTAXE ^: "!THIS_SCRIPT!" CREATE_LEGACY GAME_FOLDER_PATH  >> !myLog!

        @echo SYNTAXE ^: "!THIS_SCRIPT!" CREATE_LEGACY GAME_FOLDER_PATH

        @echo given {%*}

        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""

    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"

    if not exist !BFW_GP_FOLDER! (
        @echo ERROR ^: !BFW_GP_FOLDER! does not exist ^! >> !myLog!
        @echo ERROR ^: !BFW_GP_FOLDER! does not exist ^!

        exit /b 1
    )
    REM : check if GFX pack folder was treated to be DOS compliant
    call:checkGpFolders

    set "createLegacyPacks=!args[0]!"
    set "createLegacyPacks=%createLegacyPacks:"=%"

    REM : get and check BFW_GP_FOLDER
    set "GAME_FOLDER_PATH=!args[1]!"

    if not exist !GAME_FOLDER_PATH! (
        @echo ERROR ^: !GAME_FOLDER_PATH! does not exist ^!

        exit /b 2
    )

    REM : basename of GAME FOLDER PATH (used to name shorcut)
    for /F "delims=~" %%i in (!GAME_FOLDER_PATH!) do set "GAME_TITLE=%%~nxi"

    @echo Update all graphic packs for !GAME_TITLE! >> !myLog!
    @echo ========================================================= >> !myLog!

    REM : check if BatchFw have to complete graphic packs for this game
    set "completeGP="NONE""
    for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find /I "COMPLETE_GP" 2^>NUL') do set "completeGP="YES""

    REM : get the last version used
    set "newVersion=NOT_FOUND"

    set "pat="!BFW_GP_FOLDER:"=!\graphicPacks*.doNotDelete""

    set "gpl="NOT_FOUND""
    for /F "delims=~" %%a in ('dir /B !pat! 2^>NUL') do set "gpl="%%a""
    if not [!gpl!] == ["NOT_FOUND"] set "zipLogFile="!BFW_GP_FOLDER:"=!\!gpl:"=!""

    if [!gpl!] == ["NOT_FOUND"] (
        @echo WARNING ^: !pat! not found^, force extra pack creation ^! >> !myLog!
        goto:treatOneGame
    )

    for /F "delims=~" %%i in (!zipLogFile!) do (
        set "fileName=%%~nxi"
        set "newVersion=!fileName:.doNotDelete=!"
    )

    REM : get the last version used for launching this game
    set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""

    set "lastVersion=NOT_FOUND"
    if not exist !glogFile! goto:treatOneGame

    for /F "tokens=2 delims=~=" %%i in ('type !glogFile! ^| find /I "!GAME_TITLE!" ^| find /I "graphic packs version" 2^>NUL') do set "lastVersion=%%i"

    if ["!lastVersion!"] == ["NOT_FOUND"] goto:treatOneGame
    set "lastVersion=!lastVersion: =!"
    set "newVersion=!newVersion: =!"

    :treatOneGame

    set "codeFullPath="!GAME_FOLDER_PATH:"=!"\code""

    call:updateGraphicPacks

    REM : log in game library log
    if not ["!newVersion!"] == ["NOT_FOUND"] (

        REM : flush glogFile of !GAME_TITLE! graphic packs version
        if exist !glogFile! for /F "tokens=2 delims=~=" %%i in ('type !glogFile! ^| find "!GAME_TITLE! graphic packs version" 2^>NUL') do call:cleanGameLogFile "!GAME_TITLE! graphic packs version"

        set "msg="!GAME_TITLE! graphic packs version=!newVersion!""
        call:log2GamesLibraryFile !msg!
    )

    @echo Waiting the end of all child processes before ending ^.^.^. >> !myLog!
    if %nbArgs% EQU 0 endlocal && pause && exit 0
    if %ERRORLEVEL% NEQ 0 exit %ERRORLEVEL%

    exit 0
    goto:eof

    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions

    :checkGpFolders

        for /F "delims=~" %%i in ('dir /B /A:D !BFW_GP_FOLDER! ^| find "^!" 2^>NUL') do (
            @echo Treat GFX pack folder to be DOS compliant
            wscript /nologo !StartHiddenWait! !brcPath! /DIR^:!BFW_GP_FOLDER! /REPLACECI^:^^!^:# /REPLACECI^:^^^&^: /REPLACECI^:^^.^: /EXECUTE > NUL 2>&1
            goto:eof
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :cleanGameLogFile
        REM : pattern to ignore in log file
        set "pat=%~1"
        set "logFileTmp="!glogFile:"=!.tmp""

        type !glogFile! | find /I /V "!pat!" > !logFileTmp!

        del /F /S !glogFile! > NUL 2>&1
        move /Y !logFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :updateGraphicPacks

        set "codeFullPath=!codeFullPath:\\=\!"

        REM : not game folder, skip
        if not exist !codeFullPath! goto:eof

        REM : get bigger rpx file present under game folder
        set "RPX_FILE="NONE""
        set "pat="!GAME_FOLDER_PATH:"=!\code\*.rpx""
        for /F "delims=~" %%i in ('dir /B /O:S !pat! 2^>NUL') do set "RPX_FILE="%%i""
        REM : if no rpx file found, ignore GAME
        if [!RPX_FILE!] == ["NONE"] goto:eof

        REM : update game's graphic packs
        set "ggp="!GAME_FOLDER_PATH:"=!\Cemu\graphicPacks""
        if not exist !ggp! mkdir !ggp! > NUL 2>&1

        REM : Get Game information using titleId
        set "META_FILE="!GAME_FOLDER_PATH:"=!\meta\meta.xml""
        REM : get Title Id from meta.xml
        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%i in ('type !META_FILE! ^| find "title_id"') do set "titleLine="%%j""
        if [!titleLine!] == ["NONE"] (
            cscript /nologo !MessageBox! "ERROR ^: unable to find titleId from meta^.xml^, please check ^! exiting^.^.^." 4112
            goto:eof
        )
        for /F "delims=<" %%i in (!titleLine!) do set "titleId=%%i"

        set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

        REM : get information on game using WiiU Library File
        set "libFileLine="NONE""
        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

        REM : strip line to get data
        for /F "tokens=1-11 delims=;" %%a in (!libFileLine!) do (
           set "titleIdRead=%%a"
           set "Desc=%%b"
           set "productCode=%%c"
           set "companyCode=%%d"
           set "notes=%%e"
           set "versions=%%f"
           set "region=%%g"
           set "acdn=%%h"
           set "icoId=%%i"
           set "nativeHeight=%%j"
           set "nativeFps=%%k"
        )

        REM : check if V3 gp exist for this game
        for /F "delims=~" %%i in ('dir /b /a:d !BFW_GP_FOLDER! ^| find /V "_Performance_" ^| find /I /V "_Resolution_" ^| find /I "_Resolution" 2^>NUL') do (

            set "gpFolder="!BFW_GP_FOLDER:"=!\%%i""
            set "rulesFile="!gpFolder:"=!\rules.txt""

            REM : launching the search
            if exist !rulesFile! for /F "tokens=2 delims=~=" %%i in ('type !rulesFile! ^| find /I "%titleId:~3%" 2^>NUL') do if ["!lastVersion!"] == ["!newVersion!"] goto:eof

        )
        call:updateGPFolder !ggp!

        pushd !GAMES_FOLDER!

    goto:eof
    REM : ------------------------------------------------------------------


    :updateGPFolder

        set "GAME_GP_FOLDER="%~1""

        REM : check if V3 graphic pack is present for this game (if the game is not supported
        REM : in Slashiee repo, it was deleted last graphic pack's update) => re-create game's graphic packs

        set "fnrLogUggp="!BFW_PATH:"=!\logs\fnr_updateGamesGraphicPacks.log""
        if exist !fnrLogUggp! del /F !fnrLogUggp!

        REM : launching the search
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !BFW_GP_FOLDER! --fileMask "rules.txt" --includeSubDirectories --find %titleId:~3% --logFile !fnrLogUggp! > NUL

        set /A "resX2=%nativeHeight%*2"

        set "gpfound=0"
        set "v3Gpfound=0"
        set "gameName=NONE"
        set "gpV3Res="NONE""

        for /F "tokens=2-3 delims=." %%i in ('type !fnrLogUggp! ^| find /I /V "^!" ^| find /I /V "p1610" ^| find /I /V "p219" ^| find /I /V "p489" ^| find /I /V "p43" ^| find "File:"') do (
            set "gpfound=1"

            REM : rules.txt
            set "rulesFile="!BFW_GP_FOLDER:"=!%%i.%%j""

            echo !rulesFile! | find "_%resX2%p" | find /I /V "_BatchFW " > NUL 2>&1 && (
                REM : V2 graphic pack
                set "gameName=%%i"
                set "gameName=!gameName:rules=!"
                set "gameName=!gameName:\_graphicPacksV2=!"
                set "gameName=!gameName:\=!"
                set "gameName=!gameName:_%resX2%p=!"
            )

            for /F "delims=~" %%a in ('type !rulesFile! ^| find "version = 3"') do (
                REM : V3 graphic pack
                set "v3Gpfound=1"
                REM : if a V3 gp of BatchFW was found goto:eof (no need to be completed ni createExtra)
                echo !rulesFile! | find /I /V "_Resolution_" | find /V "_Performance_" | find /I "_Resolution" > NUL 2>&1 && type !rulesFile! | find /I "BatchFW" > NUL 2>&1 && goto:eof
                echo !rulesFile! | find /I /V "_Resolution_" | find /V "_Performance_" | find /I "_Resolution" > NUL 2>&1 && set "gpV3Res=!rulesFile:\rules.txt=!"
            )
        )

        REM : if a v3 graphic pack was found get the game's name from it
        if not [!gpV3Res!] == ["NONE"] (
            for /F "delims=~" %%i in (!gpV3Res!) do set "str=%%~nxi"
            set "gameName=!str:_Resolution=!"
        )

        set "argSup=%gameName%"
        if ["%gameName%"] == ["NONE"] set "argSup="

        REM : no V3 Gp were found but other version packs found
        REM   (it is the case when graphic pack folder were updated on games that are not supported in Slashiee repo)

        echo titleId=!titleId! >> !myLog!
        echo gpfound=!gpfound! >> !myLog!
        echo v3Gpfound=!v3Gpfound! >> !myLog!
        echo createLegacyPacks=%createLegacyPacks% >> !myLog!

        if %gpfound% EQU 1 if %v3Gpfound% EQU 1 goto:createExtraGP
        REM : if V3 GP found, get the last update version
        if %v3Gpfound% EQU 1 goto:checkRecentUpdate

        @echo Create BatchFW graphic packs for this game ^.^.^.
        REM : Create game's graphic pack
        set "cgpLogFile="!BFW_PATH:"=!\logs\createGameGraphicPacks.log""
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createGameGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% >> !myLog!
        call !toBeLaunch! !BFW_GP_FOLDER! %titleId% > !cgpLogFile!

        goto:createCapGP

        :checkRecentUpdate

        REM : check if a version were used for this game
        if ["!lastVersion!"] == ["NOT_FOUND"] goto:createExtraGP
        @echo Extra graphic packs for this game was built using !lastVersion!^, !newVersion! is the last downloaded

        :createExtraGP
        if [!completeGP!] == ["NONE"] goto:eof

        if ["!newVersion!"] == ["NOT_FOUND"] @echo Creating Extra graphic packs for !GAME_TITLE! ^.^.^.
        if not ["!newVersion!"] == ["NOT_FOUND"] @echo Creating Extra graphic packs for !GAME_TITLE! based on !newVersion! ^.^.^.

        set "cgpLogFile="!BFW_PATH:"=!\logs\createExtraGraphicPacks.log""
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createExtraGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!
        echo !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup! >> !myLog!

        call !toBeLaunch! !BFW_GP_FOLDER! %titleId% !createLegacyPacks! !argSup! > !cgpLogFile! 2>&1

        :createCapGP

        REM : create FPS cap graphic packs
        set "cfcgpLog="!BFW_PATH:"=!\logs\createCapGraphicPacks.log""
        set "toBeLaunch="!BFW_TOOLS_PATH:"=!\createCapGraphicPacks.bat""
        echo launching !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup!
        echo !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup! >> !myLog!

        call !toBeLaunch! !BFW_GP_FOLDER! %titleId% !argSup! > !cfcgpLog! 2>&1


    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            @echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            @echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get user input in allowed valuesList (beginning with default timeout value) from question and return the choice
    :getUserInput

        REM : arg1 = question
        set "question="%~1""
        REM : arg2 = valuesList
        set "valuesList=%~2"
        REM : arg3 = return of the function (user input value)
        REM : arg4 = timeOutValue (optional : if given set 1st value as default value after timeOutValue seconds)
        set "timeOutValue=%~4"

        set choiceValues=%valuesList:,=%
        set defaultTimeOutValue=%valuesList:~0,1%

        REM : building choice command
        if ["%timeOutValue%"] == [""] (
            set choiceCmd=choice /C %choiceValues% /CS /N /M !question!
        ) else (
            set choiceCmd=choice /C %choiceValues% /CS /N /T %timeOutValue% /D %defaultTimeOutValue% /M !question!
        )

        REM : launching and get return code
        !choiceCmd!
        set /A "cr=!ERRORLEVEL!"

        set j=1
        for %%i in ("%valuesList:,=" "%") do (

            if [%cr%] == [!j!] (
                REM : value found , return function value

                set "%3=%%i"
                goto:eof
            )
            set /A j+=1
        )

    goto:eof
    REM : ------------------------------------------------------------------


    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            @echo Host char codeSet not found ^?^, exiting 1
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2GamesLibraryFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!BFW_PATH:"=!\logs\gamesLibrary.log""
        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2GamesLibraryFile
        )

        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!" 2^>NUL') do goto:eof

        :logMsg2GamesLibraryFile
        echo !msg! >> !glogFile!
        REM : sorting the log
        set "gLogFileTmp="!glogFile:"=!.tmp""
        type !glogFile! | sort > !gLogFileTmp!
        del /F /S !glogFile! > NUL 2>&1
        move /Y !gLogFileTmp! !glogFile! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to log info for current host
    :log2HostFile
        REM : arg1 = msg
        set "msg=%~1"

        if not exist !logFile! (
            set "logFolder="!BFW_PATH:"=!\logs""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof
        :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------
