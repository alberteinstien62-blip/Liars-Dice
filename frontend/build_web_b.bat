@echo off
echo Building Liars-Dice Player B for Conway Testnet...

REM Copy web_b config to main config location
copy /Y web_b\config.json config.json

REM Build Flutter web
flutter build web --web-renderer html --output=build\web_b

echo.
echo Build complete! Output in build\web_b\
echo Ready to deploy to Vercel!
pause
