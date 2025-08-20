@echo off
echo Applying CORS configuration to Firebase Storage...
echo.
echo Make sure you have Google Cloud SDK installed and authenticated
echo Download from: https://cloud.google.com/sdk/docs/install
echo.
pause

gsutil cors set cors-updated.json gs://annedfinds.firebasestorage.app

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ CORS configuration applied successfully!
    echo ⏱️  Please wait 5-10 minutes for global propagation
    echo 🧹 Clear your browser cache and test: https://annedfinds.web.app
) else (
    echo.
    echo ❌ Failed to apply CORS configuration
    echo Please check your Google Cloud SDK installation and authentication
)

echo.
echo Verifying current CORS configuration...
gsutil cors get gs://annedfinds.firebasestorage.app

pause