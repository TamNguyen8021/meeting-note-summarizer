#ifndef FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#define AUDIO_CAPTURE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), audio_capture_plugin_get_type(), \
                              AudioCapturePlugin))

#define AUDIO_CAPTURE_PLUGIN_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), audio_capture_plugin_get_type(), \
                           AudioCapturePluginClass))

#define IS_AUDIO_CAPTURE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), audio_capture_plugin_get_type()))

#define IS_AUDIO_CAPTURE_PLUGIN_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), audio_capture_plugin_get_type()))

#define AUDIO_CAPTURE_PLUGIN_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS((obj), audio_capture_plugin_get_type(), \
                             AudioCapturePluginClass))

typedef struct _AudioCapturePlugin AudioCapturePlugin;
typedef struct _AudioCapturePluginClass AudioCapturePluginClass;

struct _AudioCapturePlugin {
  GObject parent_instance;
};

struct _AudioCapturePluginClass {
  GObjectClass parent_class;
};

GType audio_capture_plugin_get_type(void) G_GNUC_CONST;

void audio_capture_plugin_register_with_registrar(FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_
