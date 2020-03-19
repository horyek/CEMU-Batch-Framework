@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    set "THIS_SCRIPT=%~0"

    title Search and download a game
    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "BFW_TOOLS_PATH=!SCRIPT_FOLDER:\"="!"

    for %%a in (!BFW_TOOLS_PATH!) do set "parentFolder="%%~dpa""
    set "BFW_PATH=!parentFolder:~0,-2!""
    for %%a in (!BFW_PATH!) do set "parentFolder="%%~dpa""
    for %%a in (!BFW_PATH!) do set "drive=%%~da"
    set "GAMES_FOLDER=!parentFolder!"
    if not [!GAMES_FOLDER!] == ["!drive!\"] set "GAMES_FOLDER=!parentFolder:~0,-2!""

    set "BFW_RESOURCES_PATH="!BFW_PATH:"=!\resources""
    set "BFW_LOGS="!BFW_PATH:"=!\logs""
    set "logFile="!BFW_LOGS:"=!\Host_!USERDOMAIN!.log""

    set "cmdOw="!BFW_RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "JNUSFolder="!BFW_RESOURCES_PATH:"=!\JNUST""

    set "Start="!BFW_RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartWait="!BFW_RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartMinimized="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimized.vbs""
    set "StartMinimizedWait="!BFW_RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "browseFolder="!BFW_RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "fnrPath="!BFW_RESOURCES_PATH:"=!\fnr.exe""

    set "download="!BFW_TOOLS_PATH:"=!\downloadTitleId.bat""

    set "notePad="%windir%\System32\notepad.exe""
    set "explorer="%windir%\explorer.exe""

    REM : output folder
    set "targetFolder=!GAMES_FOLDER!"

    REM : check if java is installed
    java -version > NUL 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR^: java is not installed^, exiting
        pause
        exit 50
    )

    set "ACTIVE_ADAPTER=NOT_FOUND"
    for /F "tokens=1 delims=~=" %%f in ('wmic nic where "NetConnectionStatus=2" get NetConnectionID /value 2^>NUL ^| find "="') do set "ACTIVE_ADAPTER=%%f"
    if ["!ACTIVE_ADAPTER!"] == ["NOT_FOUND"] (
        echo ERROR^: no active network connection found^, exiting
        pause
        exit 51
    )

    REM : set current char codeset
    call:setCharSet

    set "titleKeysDataBase="!JNUSFolder:"=!\titleKeys.txt""

    if not exist !titleKeysDataBase! call:createKeysFile

    if not exist !titleKeysDataBase! (
        echo ERROR^: no keys file found^, exiting
        pause
        exit 52
    )

    :askKeyWord
    cls
    set /P  "pat=Enter a key word to search for the game (part of the title, titleId...): "
    echo.
    echo =========================== Matches ===========================
    REM : get userArray
    set /A "nbRes=0"

    for /F "delims=~	 tokens=1-4" %%a in ('type !titleKeysDataBase! ^| find /I "!pat!" ^| find /I "00050000" ^| find /I /V "Demo" 2^>NUL') do (
        set "titleIds[!nbRes!]=%%a"
        set "titleKeys[!nbRes!]=%%b"
        set "titles[!nbRes!]="%%c""
        set "regions[!nbRes!]=%%d"
        set /A "nbRes+=1"
        echo !nbRes! ^: %%c [%%d] %%a
    )

    echo ===============================================================
    echo s ^: to relaunch your search
    echo c ^: to cancel
    echo ---------------------------------------------------------------
    echo.
    echo If your search failed^, check the format of
    echo !titleKeysDataBase!
    echo.
    echo The text file must use the following format ^:
    echo.
    echo [TitleID]^\t[TitleKey]^\t[Name]^\t[Region]^\t[Type]^\t[Ticket]
    echo ^(use TAB as separator^)
    echo.
    echo.
    echo If your search failed on a ^"recent game^"^, try to update
    echo !titleKeysDataBase!
    echo with a newer database^.
    echo.
    echo.

    :askChoice
    set /p "answer=Enter your choice : "

    if ["!answer!"] == ["s"] goto:askKeyWord
    if ["!answer!"] == ["c"] (
        echo.
        echo Cancelled by user
        pause
        exit 55
    )

    echo !answer! | findstr /R "^[0-9]*.$" > NUL 2>&1 && goto:checkInteger
    goto:askChoice

    :checkInteger
    set /A "index=answer-1"
    if !index! GEQ !nbRes! goto:askChoice

    set /A "decryptMode=0"

    title Download !titles[%index%]! [!regions[%index%]!]
    cls
    echo ===============================================================
    echo !titles[%index%]! [!regions[%index%]!] ^(!titleIds[%index%]!^)
    echo ===============================================================
    echo.
    echo You can download a WUP package for the game to be installed on
    echo your Wii-U using WUP Installer GX2^. You^'ll have to browse to the
    echo target location in this case ^(for example^: %%SD_CARD%%\install^)
    echo.
    echo If you choose to extract the game ^(for CEMU^)^, game will be
    echo extracted and prepared for emulation^.
    echo.
    choice /C yn /N /M "Extract games (= RPX format for CEMU)? :"
    if !ERRORLEVEL! EQU 1 set /A "decryptMode=1" && goto:begin

    :askOutputFolder
    set "targetFolder="NONE""
    for /F %%b in ('cscript /nologo !browseFolder! "Please, browse to the output folder"') do set "folder=%%b" && set "targetFolder=!folder:?= !"
    if [!targetFolder!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 1 > NUL 2>&1 && exit 75
        goto:askOutputFolder
    )

    REM : copy JNUSFolder content in !targetFolder!
    robocopy !JNUSFolder! !targetFolder! /S /IS /IT  > NUL 2>&1

    REM : override JNUSFolder path
    set "JNUSFolder=!targetFolder!"

    :begin

    REM : compute update and DLC titleId
    set "titleId=!titleIds[%index%]!"
    set "endTitleId=%titleId:~8,8%"

    set "utid=0005000e!endTitleId!"
    set "dtid=0005000c!endTitleId!"

    cls
    echo ===============================================================
    echo Temporary folder ^: !JNUSFolder!
    echo ---------------------------------------------------------------
    set "titleKeysDataBase="!JNUSFolder:"=!\titleKeys.txt""
    set "jnusTool="!JNUSFolder:"=!\JNUSTool.jar""

    REM : download meta/meta.xml to get the title name
    pushd !JNUSFolder!

    set "str="Total Size of Content Files""
    if !decryptMode! EQU 1 set "str="Total Size of Decrypted Files""

    set /A "totalSize=0"
    call:getSize !titleId! !str! "Game  "

    type !titleKeysDataBase! | find "!utid!" > NUL 2>&1 && call:getSize !utid! !str! Update

    type !titleKeysDataBase! | find "!dtid!" > NUL 2>&1 && call:getSize !dtid! !str! "DLC   "

    for %%a in (!JNUSFolder!) do set "targetDrive=%%~da"

    REM : get size left on !targetDrive! in Gb
    for /F "tokens=1" %%i in ('wmic logicaldisk get Name^,FreeSpace ^| find "!targetDrive!" 2^>NUL') do set "leftBytes=%%i"
    set /A "leftKb=%leftBytes:~0,-3%"

    set /A "intSizeLeft=!leftKb!/1024"
    echo.
    if !intSizeLeft! GTR !totalSize! (
        echo !totalSize! Mb needed on !targetDrive! ^(!intSizeLeft! Mb left^)^.
    ) else (
        echo ERROR ^: not enought space left on !targetDrive!
        echo Needed !totalSize! Mb ^/ available !intSizeLeft!
        pause
        exit 78
    )
    echo.
    set /P "answer=Continue (y/n)? : "
    if not ["!answer!"] == ["y"] (
        echo Cancelled by user^.
        timeout /T 2 > NUL 2>&1
        exit 95
    )
    echo ---------------------------------------------------------------
    
    REM : get the last modified folder in
    set "initialGameFolderName="NOT_FOUND""
    for /F "delims=~" %%x in ('dir /A:D /O:D /T:W /B * 2^>NUL') do set "initialGameFolderName="%%x""
    if [!initialGameFolderName!] == ["NOT_FOUND"] (
        echo ERROR^: failed to download meta^.xlm
        echo Check security policy
        pause
        exit 60
    )
    set "gameFolderName=!initialGameFolderName:?=!"

    REM : secureGameTitle
    call:secureGameTitle !gameFolderName! gameFolderName
    echo "!gameFolderName!" | find "[" > NUL 2>&1 && for /F "tokens=1-2 delims=[" %%i in (!gameFolderName!) do set "gameFolderName="%%~nxi""


    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "date=%ldt%"
    REM : starting DATE

    echo Starting at !date!
    echo.

    if !decryptMode! EQU 0 (
        echo ^> Downloading WUP of !titles[%index%]! [!regions[%index%]!]^.^.^.
        title Downloading WUP of !titles[%index%]! [!regions[%index%]!]
    ) else (

        set "finalPath="!GAMES_FOLDER:"=!\!gameFolderName:"=!"

        if exist !finalPath! (
            echo ERROR^: Game already exist in !finalPath!^, exiting
            rmdir /Q /S !initialGameFolderName! > NUL 2>&1
            pause
            exit 61
        )

        echo ^> Downloading RPX package of !titles[%index%]! [!regions[%index%]!]^.^.^.
        title Downloading RPX package of !titles[%index%]! [!regions[%index%]!]
    )

    REM : download the game
    wscript /nologo !StartMinimized! !download! !JNUSFolder! !titleIds[%index%]! !decryptMode! !titleKeys[%index%]!


    REM : if a update exist, download it
    type !titleKeysDataBase! | find /I "!utid!" > NUL 2>&1 && (
        echo ^> Downloading update found for !titles[%index%]! [!regions[%index%]!]^.^.^.
        wscript /nologo !StartMinimized! !download! !JNUSFolder! !utid! !decryptMode!
    )

    REM : if a DLC exist, download it
    type !titleKeysDataBase! | find /I "!dtid!" > NUL 2>&1 && (
        echo ^> Downloading DLC found !titles[%index%]! [!regions[%index%]!]^.^.^.
        wscript /nologo !StartMinimized! !download! !JNUSFolder! !dtid! !decryptMode!
    )

    call:monitorTransfert

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "date=%ldt%"

    REM : ending DATE
    echo.
    echo Ending at !date!
    echo ===============================================================

    REM : update and DLC target folder names
    set "uName="!gameFolderName:"=! (UPDATE DATA)""
    set "dName="!gameFolderName:"=! (DLC)""

    if !decryptMode! EQU 0 (
        REM : WUP format (saved in tmp_%titleId% folder)

        set "folder=tmp_!titleId!"
        if not exist !folder! (
            echo ERROR^: failed to download !titleId!^?
            echo ERROR^: tmp_!titleId! was not found
            pause
            exit 70
        )

        move /Y !folder! !gameFolderName! > NUL 2>&1

        set "folder=tmp_!utid!"
        if exist !folder! move /Y !folder! !uName! > NUL 2>&1

        set "folder=tmp_!dtid!"
        if exist !folder! move /Y !folder! !dName! > NUL 2>&1

        REM : clean targetFolder from JNUSFolder files
        call:cleanTargetFolder

        echo WUP packages created in !JNUSFolder:"=!

    ) else (
     
        REM : moving GAME_TITLE, GAME_TITLE (UPDATE DATA), GAME_TITLE (DLC) to !GAMES_FOLDER!
        if not [!initialGameFolderName!] == [!gameFolderName!] move /Y !initialGameFolderName! !gameFolderName! > NUL 2>&1

        REM : if exist "GAME_TITLE [XXXXXX]\updates"
        set "folder="!gameFolderName:"=!\updates""

        REM : move "GAME_TITLE [XXXXXX]\updates" to "GAME_TITLE [XXXXXX] (UPDATE DATA)"
        if exist !folder! (
            for /F "delims=~" %%x in ('dir /b !folder! 2^>NUL') do set "version=%%x"
            set "updatePath="!gameFolderName:"=!\updates\!version!""

            move /Y !updatePath! !uName! > NUL 2>&1
            rmdir /Q /S !folder!
            move /Y !uName! ..\..\.. > NUL 2>&1
        )

        REM : if exist "GAME_TITLE [XXXXXX]\aoc0005000C101D6000"
        set "dlcPath="!gameFolderName:"=!\aoc!dtid!""
        REM : move "GAME_TITLE [XXXXXX]\updates" to "GAME_TITLE [XXXXXX] (DLC)" in !GAMES_FOLDER!
        if exist !dlcPath! (
            move /Y !dlcPath! !dName! > NUL 2>&1
            move /Y !dName! ..\..\.. > NUL 2>&1
        )

        move /Y !gameFolderName! ..\..\.. > NUL 2>&1

        echo.
        echo.

        echo New Games were added to your library^, launching setup^.bat^.^.^.
        set "setup="!BFW_PATH:"=!\setup.bat""
        timeout /T 3 > NUL 2>&1

        REM : last loaction used for batchFw outputs

        REM : get the last location from logFile
        set "OUTPUT_FOLDER="NONE""
        for /F "tokens=2 delims=~=" %%i in ('type !logFile! ^| find "Create" 2^>NUL') do set "OUTPUT_FOLDER="%%i""
        if not [!OUTPUT_FOLDER!] == ["NONE"] (
            set "pf=!OUTPUT_FOLDER:\Wii-U Games=!"
            wscript /nologo !Start! !setup! !pf!
        ) else (
            wscript /nologo !Start! !setup!
        )
    )

    rmdir /Q /S !initialGameFolderName! > NUL 2>&1

    endlocal
    exit 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions

    :endAllTransferts

        for /F "delims=~" %%p in ('wmic path Win32_Process where ^"CommandLine like ^'%%downloadTitleId%%^'^" get ProcessID^,commandline') do (
            set "line=%%p"
            set "line2=!line:""="!"
            set "pid=NOT_FOUND"
            echo !line2! | find /V "wmic" | find /V "ProcessID"  > NUL 2>&1 && for %%d in (!line2!) do set "pid=%%d"
            if not ["!pid!"] == ["NOT_FOUND"] taskkill /F /pid !pid! /T > NUL 2>&1
        )
    goto:eof
    REM : ------------------------------------------------------------------

    :monitorTransfert

        REM : wait until all transferts are done
        :waitingLoop
        timeout /T 3 > NUL 2>&1
        wmic process get Commandline 2>NUL | find "cmd.exe" | find  /I "downloadTitleId.bat" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && (

            REM : get the JNUSTools folder size
            call:getFolderSizeInMb !initialGameFolderName! sizeDl

            REM : progression
            set /A "curentSize=!sizeDl!

            if !curentSize! LSS !totalSize! (
                set /A "progression=(!curentSize!*100)/!totalSize!"
            ) else (
                set /A "progression=100"
                call:endAllTransferts
                echo.
                echo downloaded successfully
            )
            
            if !decryptMode! EQU 0 title Downloading WUP of !titles[%index%]! [!regions[%index%]!] ^: !progression!%%
            if !decryptMode! EQU 1 title Downloading RPX package of !titles[%index%]! [!regions[%index%]!] ^: !progression!%%

            goto:waitingLoop
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :getSmb
        set "sr=%~1"
        set /A "d=%~2"

        set /A "%3=!sr:~0,%d%!+1"
    goto:eof
    REM : ------------------------------------------------------------------

    :strLength
        Set "s=#%~1"
        Set "len=0"
        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )
        set /A "%2=%len%"
    goto:eof
    REM : ------------------------------------------------------------------

    :getFolderSizeInMb

        set "folder="%~1""
        REM : prevent path to be stripped if contain '
        set "folder=!folder:'=`'!"
        set "folder=!folder:[=`[!"
        set "folder=!folder:]=`]!"
        set "folder=!folder:)=`)!"
        set "folder=!folder:(=`(!"

        set "psCommand=-noprofile -command "ls -r '!folder:"=!' | measure -s Length""

        set "line=NONE"
        for /F "usebackq tokens=2 delims=:" %%a in (`powershell !psCommand! ^| find /I "Sum"`) do set "line=%%a"
        REM : powershell call always return %ERRORLEVEL%=0

        if ["!line!"] == ["NONE"] (
            set "%2=0"
            goto:eof
        )

        set "sizeRead=%line: =%"

        if ["!sizeRead!"] == [" ="] (
            set "%2=0"
            goto:eof
        )

        set /A "im=0"
        if not ["!sizeRead!"] == ["0"] (

            REM : compute length before switching to 32bits integers
            call:strLength !sizeRead! len
            REM : forcing Mb unit
            if !len! GTR 6 (
                set /A "dif=!len!-6"
                call:getSmb %sizeRead% !dif! smb
                set "%2=!smb!"
                goto:eof
            ) else (
                set "%2=1"
                goto:eof
            )
        )
        set "%2=0.0"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : fetch size of download
    :getSize
        set "tid=%~1"
        set "pat=%~2"
        set "type=%~3"

        set "key=NOT_FOUND"
        for /F "delims=~	 tokens=1-4" %%a in ('type !titleKeysDataBase! ^| find /I "!tid!" 2^>NUL') do set "key=%%b"

        if ["!key!"] == ["NOT_FOUND"] (
            echo ERROR^: why key is not found ^?
            pause
            goto:eof
        )

        set "logMetaFile="!BFW_LOGS:"=!\jnust_Meta.log""
        del /F !logMetaFile! > NUL 2>&1
        java -jar JNUSTool.jar !tid! !key! -file /meta/meta.xml > !logMetaFile! 2>&1

        set "strRead="
        for /F "delims=~: tokens=2" %%i in ('type !logMetaFile! ^| find "!pat!" 2^>NUL') do set "strRead=%%i"

        set "strSize="
        for /F "tokens=1" %%i in ("!strRead!") do set "strSize=%%i"

        set /A "intSize=0"
        for /F "delims=~. tokens=1" %%i in ("!strSize!") do set /A "intSize=%%i"

        set /A "totalSize=!totalSize!+!intSize!+1"

        echo !type! size =!strRead!

        del /F !logMetaFile! > NUL 2>&1
    goto:eof

    REM : create keys file
    :createKeysFile

        echo To use this feature^, obviously you^'ll have to setup JNUSTool
        echo and get the files requiered by yourself^.
        echo.

        set "config="!JNUSFolder:"=!\config""
        type !config! | find "[COMMONKEY]" > NUL 2>&1 && (
            echo First you need to find the ^'Wii U common key^' with google
            echo It should be 32 chars long and start with ^'D7^'^.
            echo.

            echo Then replace ^'[COMMONKEY]^' with the ^'Wii U common key^' in JNUST^\config
            echo and save^.
            echo.
            timeout /T 3 > NUL 2>&1
            wscript /nologo !StartWait! !notePad! !config!
        )

        echo You need to create the title keys file^.
        echo.
        echo Use Chrome browser to have less hand work to do^.
        echo Google to find ^'Open Source WiiU Title Key^'
        echo Select and paste all in notepad
        echo.
        timeout /T 4 > NUL 2>&1
        wscript /nologo !StartWait! !notePad! "!JNUSFolder:"=!\titleKeys.txt"
        echo.
        echo.
        echo Save and relaunch this script when done^.
        pause
        exit 80
    goto:eof
    REM : ------------------------------------------------------------------

    REM : JNUSTools file in targetFolder
    :cleanTargetFolder

        pushd !targetFolder!

        del /F config > NUL 2>&1
        del /F JNUSTool.* > NUL 2>&1
        del /F titleKeys.txt"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : check if a string contain *
    :checkStr

        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed

            set "%2=KO"
            goto:eof
        )
        set "%2=OK"

    goto:eof
    REM : ------------------------------------------------------------------

    REM : remove DOS forbiden character from a string
    :secureGameTitle

        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed

            set "%2=KO"
            goto:eof
        )

        REM : str is expected protected with double quotes
        set "string=%~1"

        call:checkStr "!string!" status
        if ["!status!"] == ["KO"] (
            echo string is not valid
            pause
        )

        set "string=!string:&=!"
        set "string=!string:?=!"
        set "string=!string:\!=!"
        set "string=!string:%%=!"
        set "string=!string:^=!"
        set "string=!string:\=!"
        set "string=!string:/=!"
        set "string=!string:>=!"
        set "string=!string:<=!"
        set "string=!string::=!"
        set "string=!string:|=!"

        REM : WUP restrictions
        set "string=!string:?=!"
        set "string=!string:?=!"
        set "string=!string:?=!"

        set "%2="!string!""

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found ^?^, exiting 1
            pause
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

        REM : build a relative path in case of software is installed also in games folders
        echo msg=!msg! | find %GAMES_FOLDER% > NUL 2>&1 && set "msg=!msg:%GAMES_FOLDER:"=%=%%GAMES_FOLDER:"=%%!"

        if not exist !logFile! (
            set "logFolder="!BFW_LOGS:"=!""
            if not exist !logFolder! mkdir !logFolder! > NUL 2>&1
            goto:logMsg2HostFile
        )
        REM : check if the message is not already entierely present
        for /F %%i in ('type !logFile! ^| find /I "!msg!"') do goto:eof

       :logMsg2HostFile
        echo !msg!>> !logFile!

    goto:eof
    REM : ------------------------------------------------------------------

