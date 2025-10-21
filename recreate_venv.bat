@echo off
set "VENV=myenv"
set "ROOT=%~dp0"
set "VPATH=%ROOT%%VENV%"

echo Project root: %ROOT%
echo Virtualenv path: %VPATH%

if exist "%VPATH%\" (
  echo Removing existing venv: %VPATH%
  rmdir /s /q "%VPATH%"
)

where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  where python3 >nul 2>&1
  if %ERRORLEVEL% NEQ 0 (
    echo No python or python3 found in PATH. Install Python or add it to PATH.
    pause
    exit /b 1
  ) else (
    for /f "delims=" %%p in ('where python3') do set PY=%%p
  )
) else (
  for /f "delims=" %%p in ('where python') do set PY=%%p
)

echo Using Python: %PY%
"%PY%" -m venv "%VPATH%"
if %ERRORLEVEL% NEQ 0 (
  echo Failed to create virtualenv.
  pause
  exit /b 1
)

echo Upgrading pip...
"%VPATH%\Scripts\python.exe" -m pip install --upgrade pip setuptools wheel

if exist "%ROOT%requirements.txt" (
  echo Installing requirements...
  "%VPATH%\Scripts\python.exe" -m pip install -r "%ROOT%requirements.txt"
) else (
  echo No requirements.txt found - skipping.
)

echo.
echo Virtualenv recreated at %VPATH%
echo To activate (cmd): %VENV%\Scripts\activate.bat
echo Then run: python manage.py runserver 10.88.206.108:8000
pause
