@echo off
echo ========================================================
echo KHOI DONG FASTAPI LOCAL BACKEND (PORT 5001)
echo ========================================================

cd /d "%~dp0"
call ..\..\Software\.venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 5001

pause
