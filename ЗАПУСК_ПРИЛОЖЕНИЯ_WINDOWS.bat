@echo off
chcp 65001 > nul
echo ===================================================
echo     Запуск приложения StudyPlan (Windows)
echo ===================================================
echo.
if exist "mobile\build\windows\x64\runner\Release\studyplan.exe" (
    echo Запуск скомпилированной версии...
    start "" "mobile\build\windows\x64\runner\Release\studyplan.exe"
) else (
    echo Сборка не найдена. Запуск через Flutter...
    cd mobile
    flutter run -d windows
)
