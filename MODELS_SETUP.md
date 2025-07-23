# AI Models Setup

This document describes how to set up AI models for the Meeting Summarizer app.

## Bundled Models Approach

The app is configured to load AI models from bundled assets instead of downloading them at runtime. This provides faster initialization and better user experience.

### Current Setup

The app uses two lightweight models:
- **Whisper Tiny**: ~39MB (Speech Recognition)
- **TinyLlama Q4**: ~640MB (Text Summarization)
- **Total Size**: ~680MB

### Development vs Production

#### Development (Current)
- Placeholder files are included in `assets/models/`
- Models will fall back to mock implementations
- Good for development and testing UI/UX

#### Production Setup
To enable real AI processing:

1. **Download Models** (choose one method):
   
   **Windows:**
   ```cmd
   download_models.bat
   ```
   
   **Linux/macOS:**
   ```bash
   chmod +x download_models.sh
   ./download_models.sh
   ```
   
   **Manual Download:**
   - Download [Whisper Tiny](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin) → `assets/models/whisper-tiny.bin`
   - Download [TinyLlama](https://huggingface.co/QuantFactory/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf) → `assets/models/tinyllama-q4.gguf`

2. **Rebuild App:**
   ```bash
   flutter clean
   flutter pub get
   flutter build [platform]
   ```

### Model Selection Rationale

- **Whisper Tiny**: Fastest speech recognition, supports multiple languages including English and Vietnamese
- **TinyLlama**: Smallest viable text summarization model, good enough for meeting summaries

### Performance Characteristics

| Model | Size | RAM Usage | Processing Speed | Quality |
|-------|------|-----------|------------------|---------|
| Whisper Tiny | 39MB | ~64MB | Very Fast | Good |
| TinyLlama Q4 | 640MB | ~512MB | Fast | Acceptable |

### Future Improvements

For better quality, consider upgrading to:
- **Whisper Base**: ~147MB (better accuracy)
- **Llama 3.2 1B**: ~976MB (better summaries)

Total with upgraded models: ~1.1GB

## Troubleshooting

### Models Not Loading
- Ensure model files are in `assets/models/` directory
- Check file sizes match expected values
- Verify files are not corrupted

### Memory Issues
- Monitor RAM usage during processing
- Consider using smaller models on constrained devices
- Implement model switching based on device capabilities

### Performance Issues
- Check if models are properly quantized
- Verify hardware acceleration is enabled
- Monitor CPU usage during processing
