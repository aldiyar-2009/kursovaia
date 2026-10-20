@echo off
chcp 65001 > nul
title StudyPlan Server
echo ===================================================
echo     StudyPlan Backend & Mobile App Server
echo ===================================================
echo.
echo Запуск сервера и раздача мобильного приложения...
echo.
cd /d "%~dp0backend"
npm start
pause
