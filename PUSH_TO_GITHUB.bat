@echo off
echo ========================================
echo   NEARFO APP - Push to GitHub
echo ========================================
echo.

REM Automatically go to this bat file's folder
cd /d "%~dp0"
echo Current folder: %cd%
echo.

echo [1/6] Removing old git if any...
rmdir /s /q .git 2>nul

echo [2/6] Initializing fresh git repo...
git init
git config user.email "er.akashsmorey@gmail.com"
git config user.name "Akash More"

echo [3/6] Setting up remote...
git remote add origin https://github.com/erakashsmorey-debug/nearfo-app.git

echo [4/6] Adding all files (ignore CRLF warnings)...
git add -A

echo [5/6] Creating commit...
git commit -m "fix: socket reconnection on chat open - realtime messaging fix"

echo [6/6] Pushing to GitHub (login popup aayega - login kar dena)...
git branch -M main
git push -u origin main --force

echo.
echo ========================================
if %errorlevel%==0 (
    echo   SUCCESS! Code pushed to GitHub!
    echo   Check: github.com/erakashsmorey-debug/nearfo-app
) else (
    echo   Push failed. Check the error above.
)
echo ========================================
pause
