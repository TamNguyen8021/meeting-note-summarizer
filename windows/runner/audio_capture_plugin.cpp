#include "audio_capture_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace {

class AudioCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  AudioCapturePlugin();

  virtual ~AudioCapturePlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// static
void AudioCapturePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "meeting_summarizer/audio_capture",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AudioCapturePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AudioCapturePlugin::AudioCapturePlugin() {}

AudioCapturePlugin::~AudioCapturePlugin() {}

void AudioCapturePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("getAudioSources") == 0) {
    flutter::EncodableList sources;
    
    flutter::EncodableMap defaultMic;
    defaultMic[flutter::EncodableValue("id")] = flutter::EncodableValue("default_microphone");
    defaultMic[flutter::EncodableValue("name")] = flutter::EncodableValue("Default Microphone");
    defaultMic[flutter::EncodableValue("type")] = flutter::EncodableValue("microphone");
    defaultMic[flutter::EncodableValue("isAvailable")] = flutter::EncodableValue(true);
    sources.push_back(flutter::EncodableValue(defaultMic));
    
    flutter::EncodableMap systemAudio;
    systemAudio[flutter::EncodableValue("id")] = flutter::EncodableValue("system_audio");
    systemAudio[flutter::EncodableValue("name")] = flutter::EncodableValue("System Audio (What You Hear)");
    systemAudio[flutter::EncodableValue("type")] = flutter::EncodableValue("system");
    systemAudio[flutter::EncodableValue("isAvailable")] = flutter::EncodableValue(true);
    sources.push_back(flutter::EncodableValue(systemAudio));
    
    result->Success(flutter::EncodableValue(sources));
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
    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    response[flutter::EncodableValue("message")] = flutter::EncodableValue("Capture started (mock implementation)");
    result->Success(flutter::EncodableValue(response));
  } else if (method_call.method_name().compare("stopCapture") == 0) {
    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    response[flutter::EncodableValue("message")] = flutter::EncodableValue("Capture stopped (mock implementation)");
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
