@echo off
REM Script to download real AI models for the Meeting Summarizer app
REM Run this script to replace placeholder files with actual models

echo Downloading AI models for Meeting Summarizer...

set MODELS_DIR=assets\models

REM Create models directory if it doesn't exist
if not exist %MODELS_DIR% mkdir %MODELS_DIR%

REM Download Whisper Tiny model (~39MB)
echo Downloading Whisper Tiny model...
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin" -o "%MODELS_DIR%\whisper-tiny.bin"

if %errorlevel% equ 0 (
    echo ✓ Whisper Tiny model downloaded successfully
) else (
    echo ✗ Failed to download Whisper Tiny model
)

REM Download TinyLlama model (~640MB)
echo Downloading TinyLlama model...
curl -L "https://huggingface.co/QuantFactory/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf" -o "%MODELS_DIR%\tinyllama-q4.gguf"

if %errorlevel% equ 0 (
    echo ✓ TinyLlama model downloaded successfully
) else (
    echo ✗ Failed to download TinyLlama model
)

echo Model download complete!
echo Total size: ~680MB
echo.
echo To use real AI processing:
echo 1. Run 'flutter clean && flutter pub get'
echo 2. Build and run the app
echo.
echo Note: The app will automatically detect and use these models
pause
