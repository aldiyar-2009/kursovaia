@echo off
chcp 65001 > nul
title StudyPlan - Astana IT University
echo ===================================================
echo     Запуск приложения StudyPlan / Astana IT University
echo ===================================================
echo.

set PATH=C:\Users\aldia\flutter\bin;%PATH%

echo Выберите способ запуска:
echo [1] Открыть в браузере (Chrome / Edge) [Рекомендуется]
echo [2] Открыть локальный веб-сервер (http://localhost:3000)
echo [3] Запустить как Windows Desktop приложение
echo.
set /p choice="Ваш выбор (1, 2 или 3, по умолчанию 1): "

if "%choice%"=="2" (
    start http://localhost:3000
    exit /b
)

if "%choice%"=="3" (
    cd mobile
    flutter run -d windows
    exit /b
)

echo Запуск приложения в Chrome...
cd mobile
flutter run -d chrome --web-port=5000
