@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color F0
    set "THIS_SCRIPT=%~0"

    REM : checking THIS_SCRIPT path
    call:checkPathForDos "!THIS_SCRIPT!" > NUL 2>&1
    set /A "cr=!ERRORLEVEL!"
    if !cr! NEQ 0 (
        echo ERROR ^: Remove DOS reserved characters from the path "!THIS_SCRIPT!" ^(such as ^&^, %% or ^^!^)^, cr=!cr!
        goto:eof
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
    set "MessageBox="!BFW_RESOURCES_PATH:"=!\vbs\MessageBox.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "createV2GraphicPacks="!BFW_TOOLS_PATH:"=!\createV2GraphicPacks.bat""

    set "StartHiddenWait="!BFW_RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartHidden="!BFW_RESOURCES_PATH:"=!\vbs\StartHidden.vbs""

    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "logFile="!BFW_PATH:"=!\logs\Host_!USERDOMAIN!.log""
    set "cgpLogFile="!BFW_PATH:"=!\logs\createGameGraphicPacks.log""
    set "fnrLogFolder="!BFW_PATH:"=!\logs\fnr""
    if not exist !fnrLogFolder! mkdir !fnrLogFolder! > NUL 2>&1

    REM : checking GAMES_FOLDER folder
    call:checkPathForDos !GAMES_FOLDER!

    REM : set current char codeset
    call:setCharSet

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
    set "startingDate=%ldt%"
    REM : starting DATE

    if %nbArgs% NEQ 0 goto:getArgsValue

    REM : with no arguments to this script, activating user inputs
    set /A "QUIET_MODE=0"

    REM : check if exist external Graphic pack folder
    set "BFW_GP_FOLDER="!GAMES_FOLDER:"=!\_BatchFw_Graphic_Packs""
    if exist !BFW_GP_FOLDER! (
        goto:getTitleId
    )
    echo Please select a reference graphicPacks folder

    :askGpFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a graphic packs folder"') do set "folder=%%b" && set "BFW_GP_FOLDER=!folder:?= !"
    if [!BFW_GP_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askGpFolder
    )
    REM : check if folder name contains forbiden character for batch file
    set "tobeLaunch="!BFW_PATH:"=!\tools\detectAndRenameInvalidPath.bat""
    call !tobeLaunch! !BFW_GP_FOLDER!
    set /A "cr=!ERRORLEVEL!"
    if !cr! GTR 1 (
        echo Path to !BFW_GP_FOLDER! is not DOS compatible^!^, please choose another location
        pause
        goto:askGpFolder
    )
    :getTitleId
    set "checkLenght="
    set "titleId="

    set /P "input=Enter title Id : "
    set "titleId=%input: =%"

    REM : check too short
    set "checkLenght=!titleId:~15,1!"

    if ["x!checkLenght!x"] == ["xx"] (
        echo Bad titleId ^^! must have at least 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )
    REM : check too long
    set "checkLenght=!titleId:~16,1!"

    if not ["x!checkLenght!x"] == ["xx"] (
        echo Bad titleId ^^! must have 16 hexadecimal characters^, given %titleId%
        goto:getTitleId
    )
    set "titleId=%titleId%"

    goto:inputsAvailables

    REM : titleID and BFW_GP_FOLDER
    :getArgsValue
    echo. > !cgpLogFile!
    if %nbArgs% NEQ 2 (
        echo ERROR ^: on arguments passed ^!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID >> !cgpLogFile!
        echo SYNTAXE ^: "!THIS_SCRIPT!" BFW_GP_FOLDER TITLE_ID
        echo given {%*}
        exit /b 99
    )

    REM : get and check BFW_GP_FOLDER
    set "BFW_GP_FOLDER=!args[0]!"

    if not exist !BFW_GP_FOLDER! (
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^! >> !cgpLogFile!
        echo ERROR ^: !BFW_GP_FOLDER! does not exist ^!
        exit /b 1
    )
    REM : get titleId
    set "titleId=!args[1]!"

    REM : with arguments to this script, deactivating user inputs
    set /A "QUIET_MODE=1"

    :inputsAvailables
    set "BFW_GP_FOLDER=!BFW_GP_FOLDER:\\=\!"

    set "gfxPacksV2Folder="!BFW_GP_FOLDER:"=!\_graphicPacksV2""

    set "titleId=%titleId:"=%"

    REM : check if game is recognized
    call:checkValidity %titleId%

    set "wiiTitlesDataBase="!BFW_RESOURCES_PATH:"=!\WiiU-Titles-Library.csv""

    REM : get information on game using WiiU Library File
    set "libFileLine="NONE""
    for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I "'%titleId%';"') do set "libFileLine="%%i""

    if not [!libFileLine!] == ["NONE"] goto:stripLine


    if !QUIET_MODE! EQU 1 (
        cscript /nologo !MessageBox! "Unable to get informations on the game for titleId %titleId% in !wiiTitlesDataBase:"=!" 4112
        exit /b 3
    )
    echo createGameGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^? >> !cgpLogFile!
    echo createGameGraphicPacks ^: unable to get informations on the game for titleId %titleId% ^?
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase! >> !cgpLogFile!
    echo Check your entry or if you sure^, add a row for this game in !wiiTitlesDataBase!

    goto:getTitleId

    :stripLine
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

    set "title=%Desc:"=%"
    set "GAME_TITLE=%title: =%"

    REM get all title Id for this game
    set "titleIdList="
    call:getAllTitleIds

    echo ========================================================= >> !cgpLogFile!
    echo =========================================================
    echo Create graphic packs for !GAME_TITLE! >> !cgpLogFile!
    echo Create graphic packs for !GAME_TITLE!
    echo ========================================================= >> !cgpLogFile!
    echo =========================================================
    if !QUIET_MODE! EQU 1 goto:begin
    echo Launching in 30s
    echo     ^(y^) ^: launch now
    echo     ^(n^) ^: cancel
    echo ---------------------------------------------------------
    choice /C yn /T 6 /D y /N /M "Enter your choice ? : "
    if !ERRORLEVEL! EQU 2 (
        echo Cancelled by user ^!
        goto:eof
    )
    cls
    :begin


    REM : windowing scale factor
    set "wsf=1.07638888888889"
    pushd !BFW_TOOLS_PATH!
    for /F %%r in ('multiplyLongInteger.bat !nativeHeight! 1777777') do set "result=%%r"
    call:removeDecimals !result! nativeWidth

    REM : force even integer
    set /A "isEven=!nativeWidth!%%2"
    if !isEven! NEQ 0 set /A "nativeWidth=!nativeWidth!+1"

    REM : create resolution graphic packs
    call:createResGP

    REM : waiting all children processes ending
    if exist !BFW_GPV2_FOLDER! call:waitChildrenProcessesEnd

    set "fnrFolder="!BFW_PATH:"=!\logs\fnr""
    if exist !fnrFolder! rmdir /Q /S !fnrFolder! > NUL 2>&1

    REM : ending DATE
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "endingDate=%ldt%"
    REM : starting DATE

    echo starting date = %startingDate% >> !cgpLogFile!
    echo starting date = %startingDate%
    echo ending date = %endingDate% >> !cgpLogFile!
    echo ending date = %endingDate%
    
    if %nbArgs% EQU 0 endlocal && pause
    exit /b 0

    goto:eof

    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :removeDecimals

        set "r=%~1"
        set "del=%r:~-6%"
        set "%2=!r:%del%=!"

    goto:eof
    REM : ------------------------------------------------------------------

    :strLen
        set /A "len=0"
        :strLen_Loop
           if not ["!%1:~%len%!"] == [""] set /A len+=1 & goto:strLen_Loop
            set %2=%len%
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function for dividing integers
    :divIntegers

        REM : get a
        set /A "fpA=%~1"
        REM : get b
        set /A "fpB=%~2"
        REM : get number of decimals asked
        set /A "nbDec=%~3"

        call:strLen fpA strLenA
        call:strLen fpB strLenB

        set /A "nlA=!strLenA!"
        set /A "nlB=!strLenB!"

        set /A "max=%nlA%"
        if %nlB% GTR %nlA% set /A "max=%nlB%"
        set /A "decimals=9-%max%"

        set /A "one=1"
        for /L %%i in (1,1,%decimals%) do set "one=!one!0"

        REM : a / b
        set /A div=fpA*one/fpB

        set "intPart="!div:~0,-%decimals%!""
        if [!intPart!] == [""] set "intPart=0"
        set "intPart=%intPart:"=%"

        if %nbDec% LSS %decimals% (
            set "decPart=!div:~-%nbDec%!"
        ) else (
            set "decPart=!div:~-%decimals%!"
        )
        set "result=!intPart!.!decPart!"
        if %nbDec% EQU 0 set /A "result=!intPart!"


        REM : output
        set "%4=!result!"

    goto:eof
    REM : ------------------------------------------------------------------

    :waitChildrenProcessesEnd

        REM : waiting all children processes ending
        :waitingLoop
        wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "createV2GraphicPacks" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (
            timeout /T 1 > NUL 2>&1
            goto:waitingLoop
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :dosToUnix
    REM : convert CRLF -> LF (WINDOWS-> UNIX)
        set "uTdLog="!fnrLogFolder:"=!\dosToUnix.log""

        REM : replace all \n by \n
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !newGp! --fileMask "rules.txt" --includeSubDirectories --useEscapeChars --find "\r\n" --replace "\n" --logFile !uTdLog!

    goto:eof
    REM : ------------------------------------------------------------------

    :initResGraphicPack

        echo [Definition] > !bfwRulesFile!
        echo titleIds = !titleIdList! >> !bfwRulesFile!

        echo name = Resolution >> !bfwRulesFile!
        echo path = "!GAME_TITLE!/Graphics/Resolution" >> !bfwRulesFile!
        if !nativeHeight! EQU 720 (
            echo description = Created by BatchFW considering that the native resolution is 720p^. ^
Check Debug^/View texture cache info in CEMU ^: 1280x720 must be overrided ^. ^
If it is not^, change the native resolution to 1080p in ^
_BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        ) else (
            echo description = Created by BatchFW considering that the native resolution is 1080p. ^
Check Debug^/View texture cache info in CEMU ^: 1920x1080 must be overrided ^. ^
If it is not^, change the native resolution to 720p in ^
_BatchFw_Install^/resources^/WiiU-Titles-Library^.csv >> !bfwRulesFile!
        )
        echo version = 3 >> !bfwRulesFile!
        echo. >> !bfwRulesFile!
        echo. >> !bfwRulesFile!
    goto:eof
    REM : ------------------------------------------------------------------

    :fillResGraphicPack
        set "overwriteWidth=%~1"
        set "overwriteHeight=%~2"
        set "descToWrite=%~3"

        echo [Preset] >> !bfwRulesFile!
        echo name = %overwriteWidth%x%overwriteHeight% %descToWrite% >> !bfwRulesFile!
        echo $width = %overwriteWidth% >> !bfwRulesFile!
        echo $height = %overwriteHeight% >> !bfwRulesFile!
        echo $gameWidth = !nativeWidth! >> !bfwRulesFile!
        echo $gameHeight = !nativeHeight! >> !bfwRulesFile!
        echo. >> !bfwRulesFile!

    goto:eof
    REM : ------------------------------------------------------------------

    :finalizeResGraphicPack


        REM : res ratios instructions ------------------------------------------------------
        set /A "resRatio=1"

        REM : loop to create res res/2 res/3 .... res/8
        :beginLoopRes

        set /A "r=!nativeHeight!%%!resRatio!"
        REM : check if result is an integer
        if !r! NEQ 0 set /A "resRatio+=1" & goto:beginLoopRes

        REM : compute targetHeight
        set /A "targetHeight=!nativeHeight!/!resRatio!"

        REM : compute targetWidth
        set /A "targetWidth=!nativeWidth!/!resRatio!"

        REM : force even integer
        set /A "isEven=!targetWidth!%%2"
        if !isEven! NEQ 0 set /A "targetWidth=!targetWidth!+1"

        REM 1^/%resRatio% res : %targetWidth%x%targetHeight%
        call:writeRoundedFilters >> !bfwRulesFile!

        if !targetHeight! LEQ 8 goto:formatUtf8
        if !resRatio! GEQ 12 goto:formatUtf8
        set /A "resRatio+=1"
        goto:beginLoopRes

        :formatUtf8

        REM : Windows formating (LF -> CRLF)
        call:dosToUnix

        REM : add commonly used 16/9 res filters
        echo # add commonly used 16/9 res filters >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        if !nativeHeight! EQU 720 (
            REM : (1080/2 = 540, for 1080 treated when resRatio = 2)

            echo # 960 x 540 Res >> !bfwRulesFile!
            echo [TextureRedefine] >> !bfwRulesFile!
            echo width = 960 >> !bfwRulesFile!
            echo height = 540 >> !bfwRulesFile!
            echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
            echo formatsExcluded = 0x431 >> !bfwRulesFile!
            echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !bfwRulesFile!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* 540 >> !bfwRulesFile!
            echo #  >> !bfwRulesFile!

            echo # 960 x 544 Res >> !bfwRulesFile!
            echo [TextureRedefine] >> !bfwRulesFile!
            echo width = 960 >> !bfwRulesFile!
            echo height = 544 >> !bfwRulesFile!
            echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
            echo formatsExcluded = 0x431 >> !bfwRulesFile!
            echo overwriteWidth = ^($width^/$gameWidth^) ^* 960 >> !bfwRulesFile!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* 544 >> !bfwRulesFile!
            echo #  >> !bfwRulesFile!
        )

        echo # 1137 x 640 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 1137 >> !bfwRulesFile!
        echo height = 640 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 1137 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 1152 x 640 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 1152 >> !bfwRulesFile!
        echo height = 640 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 1152 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 640 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 896 x 504 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 896 >> !bfwRulesFile!
        echo height = 504 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 896 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 504 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 768 x 432 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 768 >> !bfwRulesFile!
        echo height = 432 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 768 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 432 >> !bfwRulesFile!
        echo #  >> !bfwRulesFile!

        echo # 512 x 288 Res >> !bfwRulesFile!
        echo [TextureRedefine] >> !bfwRulesFile!
        echo width = 512 >> !bfwRulesFile!
        echo height = 288 >> !bfwRulesFile!
        echo tileModesExcluded = 0x001 # For Video Playback >> !bfwRulesFile!
        echo formatsExcluded = 0x431 >> !bfwRulesFile!
        echo overwriteWidth = ^($width^/$gameWidth^) ^* 512 >> !bfwRulesFile!
        echo overwriteHeight = ^($height^/$gameHeight^) ^* 288 >> !bfwRulesFile!

        REM : force UTF8 format
        set "utf8=!bfwRulesFile:rules.txt=rules.bfw_tmp!"
        copy /Y !bfwRulesFile! !utf8! > NUL 2>&1
        type !utf8! > !bfwRulesFile!
        del /F !utf8! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------

    :writeRoundedFilters

        REM : loop on -8,-4,0,4,12 (rounded values)
        set /A "rh=0"
        for /L %%i in (-8,4,12) do (

            echo # 1/!resRatio! Res rounded at %%i
            echo [TextureRedefine]
            echo width = !targetWidth!

            set /A "rh=!targetHeight!+%%i"
            echo height = !rh!
            echo tileModesExcluded = 0x001 # For Video Playback
            echo formatsExcluded = 0x431
            echo overwriteWidth = ^($width^/$gameWidth^) ^* !targetWidth!
            echo overwriteHeight = ^($height^/$gameHeight^) ^* !rh!
            echo #
        )
        echo #

    goto:eof
    REM : ------------------------------------------------------------------



    REM : function to add an extra 16/9 preset in graphic pack of the game
    :addGfxPacks
        set "suffixGp=%~1"

        echo Creating !wc!x!hc!!desc! GFX packs >> !cgpLogFile!
        echo Creating !wc!x!hc!!desc! GFX packs

        REM : V2 packs
        if exist !gfxPacksV2Folder! wscript /nologo !StartHidden! !createV2GraphicPacks! !nativeWidth! !nativeHeight! !wc! !hc! "!GAME_TITLE!" "!desc!" "!titleIdList!"

        REM : V3 and up
        set "descUpdated=!desc!"
        if !hc! EQU !nativeHeight! if !wc! EQU !nativeWidth! (
            set "descUpdated=!desc:)=! Default)"
        )
        call:fillResGraphicPack !wc! !hc! "!descUpdated!"

    goto:eof
    REM : ------------------------------------------------------------------


    :addResolution

        set "hc=!hi!"
        set "wc=!wi!"

        if ["!suffix!"] == [""] (

            REM : fullscreen resolutions

            REM : force even integer
            set /A "isEven=!wc!%%2"
            if !isEven! NEQ 0 set /A "wc=!wc!+1"

            call:addGfxPacks

        ) else (

            REM : windowed resolutions
            set "intRatio=!winRatio:.=!"
            for /F %%r in ('multiplyLongInteger.bat !hc! !intRatio!') do set "result=%%r"

            call:removeDecimals !result! wc

            REM : force even integer
            set /A "isEven=!wc!%%2"
            if !isEven! NEQ 0 set /A "wc=!wc!+1"

            call:addGfxPacks windowed
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :setPresets

        set "suffix=%~1"

        if ["!suffix!"] == [""] (
            set "desc= (!wr!/!hr!)"
            goto:treatEd
        )
        set "desc= (!wr!/!hr! %suffix%)"

        if !winRatio! EQU 0 (
            REM : compute new aspect ratio value
            call:divIntegers !wr! !hr! 8 fsRatio

            set "f1=!fsRatio:.=!
            set "f2=!wsf:.=!

            for /F %%r in ('multiplyLongInteger.bat !f1! !f2!') do set "result=%%r"

            set "winRatio=!result:~0,1!.!result:~1,6!"
        )
        echo ^> windowed winRatio=!winRatio!

        :treatEd
        set /A "end=5760/!hr!"
        set /A "start=360/!hr!"

        set /A "previous=6000
        for /L %%i in (%end%,-1,%start%) do (

            set /A "wi=!wr!*%%i"
            set /A "hi=!hr!*%%i"
            set /A "offset=!previous!-!hi!"
            if !hi! NEQ 0 if !offset! GEQ 180 (
                call:addResolution
                set /A "previous=!hi!"
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------


    :createGfxPacks
        REM : desc, ex 16-9
        set "desc=%~1"
        set /A "StockRatio=0"
        set /A "winRatio=0"

        REM : compute Width and Height using desc
        for /F "delims=- tokens=1-2" %%a in ("!desc!") do set "wr=%%a" & set "hr=%%b"

        REM : GFX packs
        call:setPresets

        if ["!screenMode!"] == ["fullscreen"] goto:eof

        REM : windowed GFX packs
        call:setPresets windowed

    goto:eof
    REM : ------------------------------------------------------------------

    :getAllTitleIds

        REM now searching using icoId
        set "line="NONE""

        for /F "delims=~" %%i in ('type !wiiTitlesDataBase! ^| find /I ";%icoId%;"') do (
            for /F "tokens=1-11 delims=;" %%a in ("%%i") do (
               set "titleIdRead=%%a"
               set "titleIdList=!titleIdList!^,!titleIdRead:'=!"
             )
        )
        set "titleIdList=!titleIdList:~1!"
    goto:eof

    :createResGP

        REM : SCREEN_MODE
        set "screenMode=fullscreen"
        set "ARLIST="
        
        REM : if not defined, here fix it to 16/9
        if ["!ARLIST!"] == [""] set "ARLIST=169"

        REM : search in all Host_*.log
        set "pat="!BFW_PATH:"=!\logs\Host_*.log""
        for /F "delims=~" %%i in ('dir /S /B !pat! 2^>NUL') do (
            set "currentLogFile="%%i""

            REM : get aspect ratio to produce from HOSTNAME.log (asked during setup)

            for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "DESIRED_ASPECT_RATIO" 2^>NUL') do (
                REM : add to the list if not already present
                if not ["!ARLIST!"] == [""] echo !ARLIST! | find /V "%%j" > NUL 2>&1 && set "ARLIST=%%j !ARLIST!"
                if ["!ARLIST!"] == [""] set "ARLIST=%%j !ARLIST!"
            )
            REM : get the SCREEN_MODE
            for /F "tokens=2 delims=~=" %%j in ('type !currentLogFile! ^| find /I "SCREEN_MODE" 2^>NUL') do set "screenMode=%%j"
        )

        REM : initialize graphic pack
        set "newGp="!BFW_GP_FOLDER:"=!\!GAME_TITLE!_Resolution""
        if exist !newGp! (
            echo ^^! !GAME_TITLE! already exists, skipped ^^! >> !cgpLogFile!
            echo ^^! !GAME_TITLE! already exists, skipped ^^!
            goto:eof
        )
        if not exist !newGp! mkdir !newGp! > NUL 2>&1
        set "bfwRulesFile="!newGp:"=!\rules.txt""

        call:initResGraphicPack !nativeHeight! !nativeWidth! !GAME_TITLE!

        REM : create 16/9 fullscreen graphic packs
        call:createGfxPacks "16-9"

        for %%a in (!ARLIST!) do (
            REM : waiting all children processes ending
            if exist !BFW_GPV2_FOLDER! call:waitChildrenProcessesEnd
            if ["%%a"] == ["1610"] call:createGfxPacks "16-10"
            if ["%%a"] == ["219"]  call:createGfxPacks "21-9"
            if ["%%a"] == ["329"]  call:createGfxPacks "32-9"
            if ["%%a"] == ["43"]   call:createGfxPacks "4-3"
            if ["%%a"] == ["489"]  call:createGfxPacks "48-9"
            REM : treating user defined aspect ratio W-H
            echo "%%a" | find "-" > NUL 2>&1 && call:createGfxPacks "%%a"
        )

        call:finalizeResGraphicPack

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to check unrecognized game
    :checkValidity
        set "id=%~1"

        REM : check if titleId correspond to a game wihtout meta\meta.xml file
        set "begin=%id:~0,8%"
        call:check8hexValue %begin%
        set "end=%id:~8,8%"
        call:check8hexValue %end%

    goto:eof

    :check8hexValue
        set "halfId=%~1"

        if ["%halfId:ffffffff=%"] == ["%halfId%"] goto:eof
        if ["%halfId:FFFFFFFF=%"] == ["%halfId%"] goto:eof

        echo Ooops it look like your game have a problem ^:
        echo - if no meta^\meta^.xml file exist^, CEMU give an id BEGINNING with ffffffff
        echo   using the BATCH framework ^(wizardFirstSaving.bat^) on the game
        echo   will help you to create one^.
        echo - if CEMU not recognized the game^, it give an id ENDING with ffffffff
        echo   you might have made a mistake when applying a DLC over game^'s files
        echo   to fix^, overwrite game^'s file with its last update or if no update
        echo   are available^, re-dump the game ^!
        exit /b 2
    goto:eof
    REM : ------------------------------------------------------------------

    REM : ------------------------------------------------------------------
    REM : function to detect DOS reserved characters in path for variable's expansion : &, %, !
    :checkPathForDos

        set "toCheck=%1"

        REM : if implicit expansion failed (when calling this script)
        if ["!toCheck!"] == [""] (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 13
            exit /b 13
        )

        REM : try to resolve
        if not exist !toCheck! (
            echo Remove DOS reserved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 11
            exit /b 11
        )

        REM : try to list
        dir !toCheck! > NUL 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo Remove DOS reverved characters from the path %1 ^(such as ^&^, %% or ^^!^)^, exiting 12
            exit /b 12
        )

        exit /b 0
    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found ^?^, exiting 1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1
        call:log2HostFile "charCodeSet=%CHARSET%"

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


