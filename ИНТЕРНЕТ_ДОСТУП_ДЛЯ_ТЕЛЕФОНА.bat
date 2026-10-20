@echo off
chcp 65001 > nul
title StudyPlan Mobile Internet Tunnel
echo ==============================================================
echo     StudyPlan: Доступ для смартфона через Интернет (4G/5G)
echo ==============================================================
echo.
echo Создание туннеля для подключения смартфона без общего Wi-Fi...
echo Скопируйте полученную ссылку "your url is: https://..."
echo и откройте ее в браузере смартфона.
echo.
npx -y localtunnel --port 3000
pause
