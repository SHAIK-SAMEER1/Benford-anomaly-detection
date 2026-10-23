@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  RUN_PROJECT.bat
REM  Benford's Law Anomaly Detection Dashboard
REM  BMAT202L / BMAT202P Slot F1 VIT Vellore
REM
REM  Usage:
REM    Double-click this file   - launches the Shiny dashboard
REM    RUN_PROJECT.bat          - launches the Shiny dashboard
REM    RUN_PROJECT.bat test     - runs the test suite
REM    RUN_PROJECT.bat pipeline - rebuilds all tables and figures
REM    RUN_PROJECT.bat install  - installs required R packages
REM    RUN_PROJECT.bat check    - verifies the R environment
REM ============================================================

title Benford Law Dashboard - BMAT202L / BMAT202P

set "PROJ=%~dp0"
if "%PROJ:~-1%"=="\" set "PROJ=%PROJ:~0,-1%"

set "RSCRIPT="

where Rscript >nul 2>&1
if "%errorlevel%"=="0" (
    for /f "delims=" %%i in ('where Rscript 2^>nul') do (
        if not defined RSCRIPT set "RSCRIPT=%%i"
    )
)

if not defined RSCRIPT (
    for /d %%d in ("%ProgramFiles%\R\R-*") do (
        if exist "%%d\bin\Rscript.exe" (
            if not defined RSCRIPT set "RSCRIPT=%%d\bin\Rscript.exe"
        )
    )
)

if not defined RSCRIPT (
    for /d %%d in ("%LOCALAPPDATA%\Programs\R\R-*") do (
        if exist "%%d\bin\Rscript.exe" (
            if not defined RSCRIPT set "RSCRIPT=%%d\bin\Rscript.exe"
        )
    )
)

if not defined RSCRIPT (
    echo.
    echo  ERROR: Rscript.exe not found.
    echo  Please install R 4.1 or newer from https://cran.r-project.org/
    echo  and re-run this script.
    echo.
    pause
    exit /b 1
)

echo  R executable found: %RSCRIPT%
echo  Project folder:    %PROJ%
echo.

set "MODE=dashboard"
if /i "%~1"=="test"     set "MODE=test"
if /i "%~1"=="pipeline" set "MODE=pipeline"
if /i "%~1"=="install"  set "MODE=install"
if /i "%~1"=="check"    set "MODE=check"

echo  Checking required packages ...
"%RSCRIPT%" --no-save "%PROJ%\scripts\check_env.R"
if not "%errorlevel%"=="0" goto :missing_packages

if /i "%MODE%"=="check" goto :do_check
if /i "%MODE%"=="install" goto :do_install
if /i "%MODE%"=="test" goto :do_test
if /i "%MODE%"=="pipeline" goto :do_pipeline
goto :do_dashboard

:missing_packages
echo.
echo  Some packages are missing. Run:
echo    RUN_PROJECT.bat install
echo  or in R:
echo    install.packages(c('shiny','bslib','readr','dplyr','tidyr','ggplot2','DT','testthat','rmarkdown','knitr','jsonlite'))
echo.
if /i "%MODE%"=="install" goto :do_install
pause
exit /b 2

:do_check
echo  Environment check passed successfully.
exit /b 0

:do_install
echo.
echo  Installing required packages from CRAN ...
"%RSCRIPT%" --no-save -e "install.packages(c('shiny','bslib','readr','dplyr','tidyr','ggplot2','DT','testthat','rmarkdown','knitr','jsonlite'), repos='https://cloud.r-project.org')"
echo.
echo  Package installation complete.
pause
exit /b 0

:do_test
echo.
echo  Running test suite (tests/testthat) ...
echo.
cd /d "%PROJ%"
"%RSCRIPT%" --no-save -e "setwd(commandArgs(TRUE)[1]); testthat::test_dir('tests/testthat', reporter='progress')" "%PROJ:\=/%"
set "TEST_EXIT=%errorlevel%"
echo.
echo  Test suite finished with exit code: %TEST_EXIT%
pause
exit /b %TEST_EXIT%

:do_pipeline
echo.
echo  Running full pipeline (tables + figures + reports) ...
echo.
cd /d "%PROJ%"
"%RSCRIPT%" --no-save "%PROJ%\scripts\run_all.R"
set "PIPE_EXIT=%errorlevel%"
echo.
echo  Pipeline finished with exit code: %PIPE_EXIT%
echo  Outputs located in:
echo    %PROJ%\outputs\tables\
echo    %PROJ%\outputs\figures\
echo    %PROJ%\reports\
pause
exit /b %PIPE_EXIT%

:do_dashboard
echo  Launching Shiny dashboard ...
echo  Shiny will print the local URL in this window (a free port is chosen automatically).
echo  Press Ctrl+C or close this window to stop the dashboard.
echo.
cd /d "%PROJ%"
"%RSCRIPT%" --no-save -e "setwd(commandArgs(TRUE)[1]); shiny::runApp('app.R', launch.browser=TRUE)" "%PROJ:\=/%"
set "APP_EXIT=%errorlevel%"
if not "%APP_EXIT%"=="0" (
    echo.
    echo  The dashboard exited with code %APP_EXIT%. The error output is above.
    pause
)
endlocal
