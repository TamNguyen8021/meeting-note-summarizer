import Cocoa
import FlutterMacOS

public class AudioCapturePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "meeting_summarizer/audio_capture", binaryMessenger: registrar.messenger)
    let instance = AudioCapturePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAudioSources":
      let sources = [
        [
          "id": "default_microphone",
          "name": "Default Microphone",
          "type": "microphone",
          "isAvailable": true
        ],
        [
          "id": "system_audio",
          "name": "System Audio",
          "type": "system",
          "isAvailable": true
        ]
      ]
      result(sources)
    case "selectAudioSource":
      if let args = call.arguments as? [String: Any],
         let sourceId = args["sourceId"] as? String {
        let response = [
          "success": true,
          "selectedSourceId": sourceId
        ]
        result(response)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "sourceId is required", details: nil))
      }
    case "startCapture":
      let response = [
        "success": true,
        "message": "Capture started (mock implementation)"
      ]
      result(response)
    case "stopCapture":
      let response = [
        "success": true,
        "message": "Capture stopped (mock implementation)"
      ]
      result(response)
    case "getAudioConfig":
      let config = [
        "sampleRate": 16000,
        "channels": 1,
        "bitsPerSample": 16,
        "bufferSize": 1600
      ]
      result(config)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
