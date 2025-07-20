#include "audio_capture_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>

#include <memory>
#include <sstream>
#include <thread>
#include <atomic>
#include <vector>
#include <chrono>
#include <functional>

// Windows WASAPI headers
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <functiondiscoverykeys_devpkey.h>
#include <comdef.h>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")

namespace {

// Simple audio capture implementation for testing
class WindowsAudioCapture {
public:
    WindowsAudioCapture() : isCapturing_(false), captureThread_(nullptr) {
        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    }
    
    ~WindowsAudioCapture() {
        StopCapture();
        CoUninitialize();
    }
    
    bool StartCapture(std::function<void(const std::vector<float>&)> callback) {
        if (isCapturing_) return false;
        
        callback_ = callback;
        isCapturing_ = true;
        captureThread_ = std::make_unique<std::thread>(&WindowsAudioCapture::CaptureWorker, this);
        return true;
    }
    
    void StopCapture() {
        isCapturing_ = false;
        if (captureThread_ && captureThread_->joinable()) {
            captureThread_->join();
        }
        captureThread_.reset();
    }
    
    std::vector<std::string> GetAudioSources() {
        std::vector<std::string> sources;
        sources.push_back("Default Microphone");
        sources.push_back("System Audio (Loopback)");
        return sources;
    }

private:
    void CaptureWorker() {
        // Simple test implementation - generate mock audio data
        while (isCapturing_) {
            if (callback_) {
                // Generate 1600 samples (100ms at 16kHz)
                std::vector<float> samples(1600);
                for (size_t i = 0; i < samples.size(); i++) {
                    // Generate a simple sine wave for testing
                    samples[i] = 0.1f * std::sin(2.0f * 3.14159f * 440.0f * i / 16000.0f);
                }
                callback_(samples);
            }
            
            // Sleep for 100ms to simulate real-time audio
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }
    
    std::atomic<bool> isCapturing_;
    std::unique_ptr<std::thread> captureThread_;
    std::function<void(const std::vector<float>&)> callback_;
};

class AudioCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  AudioCapturePlugin();

  virtual ~AudioCapturePlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
      
  std::unique_ptr<WindowsAudioCapture> audioCapture_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> audioEventSink_;
};

// static
void AudioCapturePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto methodChannel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "meeting_note_summarizer/audio_capture",
          &flutter::StandardMethodCodec::GetInstance());

  auto eventChannel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "meeting_note_summarizer/audio_stream",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AudioCapturePlugin>();

  methodChannel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  eventChannel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [plugin_pointer = plugin.get()](
              const flutter::EncodableValue* arguments,
              std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            plugin_pointer->audioEventSink_ = std::move(events);
            return nullptr;
          },
          [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            plugin_pointer->audioEventSink_.reset();
            return nullptr;
          }));

  registrar->AddPlugin(std::move(plugin));
}

AudioCapturePlugin::AudioCapturePlugin() : audioCapture_(std::make_unique<WindowsAudioCapture>()) {}

AudioCapturePlugin::~AudioCapturePlugin() {}

void AudioCapturePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("getAvailableAudioSources") == 0) {
    auto sources = audioCapture_->GetAudioSources();
    
    flutter::EncodableList flutterSources;
    
    // Add system audio source
    flutter::EncodableMap systemAudio;
    systemAudio[flutter::EncodableValue("id")] = flutter::EncodableValue("system_audio");
    systemAudio[flutter::EncodableValue("name")] = flutter::EncodableValue("System Audio");
    systemAudio[flutter::EncodableValue("type")] = flutter::EncodableValue("system");
    systemAudio[flutter::EncodableValue("isAvailable")] = flutter::EncodableValue(true);
    flutterSources.push_back(flutter::EncodableValue(systemAudio));
    
    // Add discovered audio sources
    for (size_t i = 0; i < sources.size(); i++) {
      flutter::EncodableMap source;
      source[flutter::EncodableValue("id")] = flutter::EncodableValue("device_" + std::to_string(i));
      source[flutter::EncodableValue("name")] = flutter::EncodableValue(sources[i]);
      source[flutter::EncodableValue("type")] = flutter::EncodableValue("microphone");
      source[flutter::EncodableValue("isAvailable")] = flutter::EncodableValue(true);
      flutterSources.push_back(flutter::EncodableValue(source));
    }
    
    result->Success(flutter::EncodableValue(flutterSources));
  } else if (method_call.method_name().compare("selectAudioSource") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto source_id_it = arguments->find(flutter::EncodableValue("sourceId"));
      if (source_id_it != arguments->end()) {
        const auto* source_id = std::get_if<std::string>(&source_id_it->second);
        if (source_id) {
          flutter::EncodableMap response;
          response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
          response[flutter::EncodableValue("selectedSourceId")] = flutter::EncodableValue(*source_id);
          result->Success(flutter::EncodableValue(response));
          return;
        }
      }
    }
    
    result->Error("INVALID_ARGUMENTS", "sourceId is required");
  } else if (method_call.method_name().compare("startCapture") == 0) {
    bool success = audioCapture_->StartCapture([this](const std::vector<float>& samples) {
      if (audioEventSink_) {
        // Convert float samples to int16 bytes for Flutter
        std::vector<uint8_t> audioData;
        audioData.reserve(samples.size() * 2);
        
        for (float sample : samples) {
          int16_t intSample = static_cast<int16_t>(sample * 32767.0f);
          audioData.push_back(intSample & 0xFF);
          audioData.push_back((intSample >> 8) & 0xFF);
        }
        
        flutter::EncodableMap audioChunk;
        audioChunk[flutter::EncodableValue("data")] = flutter::EncodableValue(audioData);
        audioChunk[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(
          static_cast<int64_t>(GetTickCount64()));
        
        audioEventSink_->Success(flutter::EncodableValue(audioChunk));
      }
    });
    
    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(success);
    response[flutter::EncodableValue("message")] = flutter::EncodableValue(
      success ? "Audio capture started" : "Failed to start audio capture");
    result->Success(flutter::EncodableValue(response));
  } else if (method_call.method_name().compare("stopCapture") == 0) {
    audioCapture_->StopCapture();
    
    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    response[flutter::EncodableValue("message")] = flutter::EncodableValue("Audio capture stopped");
    result->Success(flutter::EncodableValue(response));
  } else if (method_call.method_name().compare("getAudioConfig") == 0) {
    flutter::EncodableMap config;
    config[flutter::EncodableValue("sampleRate")] = flutter::EncodableValue(16000);
    config[flutter::EncodableValue("channels")] = flutter::EncodableValue(1);
    config[flutter::EncodableValue("bitsPerSample")] = flutter::EncodableValue(16);
    config[flutter::EncodableValue("bufferSize")] = flutter::EncodableValue(1600);
    result->Success(flutter::EncodableValue(config));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void AudioCapturePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  AudioCapturePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
