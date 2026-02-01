@echo off
echo Building Liars-Dice Player A for Conway Testnet...

REM Copy web_a config to main config location
copy /Y web_a\config.json config.json

REM Build Flutter web
flutter build web --web-renderer html --output=build\web_a

echo.
echo Build complete! Output in build\web_a\
echo Ready to deploy to Vercel!
pause
