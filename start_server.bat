@echo off
echo Starting Flask Server...
cd backend
call .\venv\Scripts\activate.bat
python app.py
pause
