#include "audio_capture_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define AUDIO_CAPTURE_PLUGIN_GET_PRIVATE(obj) \
  (G_TYPE_INSTANCE_GET_PRIVATE((obj), audio_capture_plugin_get_type(), \
                               AudioCapturePluginPrivate))

struct _AudioCapturePluginPrivate {
  FlMethodChannel* channel;
};

G_DEFINE_TYPE_WITH_PRIVATE(AudioCapturePlugin, audio_capture_plugin, G_TYPE_OBJECT)

// Handle method call
static void audio_capture_plugin_handle_method_call(
    AudioCapturePlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getAudioSources") == 0) {
    g_autoptr(FlValue) sources = fl_value_new_list();
    
    // Default microphone
    g_autoptr(FlValue) default_mic = fl_value_new_map();
    fl_value_set_string_take(default_mic, "id", fl_value_new_string("default_microphone"));
    fl_value_set_string_take(default_mic, "name", fl_value_new_string("Default Microphone"));
    fl_value_set_string_take(default_mic, "type", fl_value_new_string("microphone"));
    fl_value_set_string_take(default_mic, "isAvailable", fl_value_new_bool(TRUE));
    fl_value_append_take(sources, default_mic);
    
    // System audio
    g_autoptr(FlValue) system_audio = fl_value_new_map();
    fl_value_set_string_take(system_audio, "id", fl_value_new_string("system_audio"));
    fl_value_set_string_take(system_audio, "name", fl_value_new_string("System Audio"));
    fl_value_set_string_take(system_audio, "type", fl_value_new_string("system"));
    fl_value_set_string_take(system_audio, "isAvailable", fl_value_new_bool(TRUE));
    fl_value_append_take(sources, system_audio);
    
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(sources));
  } else if (strcmp(method, "selectAudioSource") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* source_id_value = fl_value_lookup_string(args, "sourceId");
    
    if (source_id_value != nullptr && fl_value_get_type(source_id_value) == FL_VALUE_TYPE_STRING) {
      const gchar* source_id = fl_value_get_string(source_id_value);
      
      g_autoptr(FlValue) result = fl_value_new_map();
      fl_value_set_string_take(result, "success", fl_value_new_bool(TRUE));
      fl_value_set_string_take(result, "selectedSourceId", fl_value_new_string(source_id));
      
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGUMENTS", "sourceId is required", nullptr));
    }
  } else if (strcmp(method, "startCapture") == 0) {
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "success", fl_value_new_bool(TRUE));
    fl_value_set_string_take(result, "message", fl_value_new_string("Capture started (mock implementation)"));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "stopCapture") == 0) {
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "success", fl_value_new_bool(TRUE));
    fl_value_set_string_take(result, "message", fl_value_new_string("Capture stopped (mock implementation)"));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getAudioConfig") == 0) {
    g_autoptr(FlValue) config = fl_value_new_map();
    fl_value_set_string_take(config, "sampleRate", fl_value_new_int(16000));
    fl_value_set_string_take(config, "channels", fl_value_new_int(1));
    fl_value_set_string_take(config, "bitsPerSample", fl_value_new_int(16));
    fl_value_set_string_take(config, "bufferSize", fl_value_new_int(1600));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(config));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void audio_capture_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(audio_capture_plugin_parent_class)->dispose(object);
}

static void audio_capture_plugin_class_init(AudioCapturePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = audio_capture_plugin_dispose;
}

static void audio_capture_plugin_init(AudioCapturePlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                          gpointer user_data) {
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
  audio_capture_plugin_handle_method_call(plugin, method_call);
}

void audio_capture_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(
      g_object_new(audio_capture_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "meeting_summarizer/audio_capture",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
