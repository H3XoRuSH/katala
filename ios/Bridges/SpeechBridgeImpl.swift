import Foundation
import Flutter
import Speech
import AVFoundation

/**
 * Native iOS SpeechBridge implementation using SFSpeechRecognizer with strict on-device enforcement.
 */
public class SpeechBridgeImpl: NSObject, SFSpeechRecognizerDelegate {

    public static let channelName = "com.katala.app/speech"
    private static let maxSessionDurationSec: TimeInterval = 30.0
    private static let defaultSilenceTimeoutSec: TimeInterval = 5.0

    private let channel: FlutterMethodChannel
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var isListening = false
    private var silenceTimer: Timer?
    private var maxSessionTimer: Timer?

    public init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: SpeechBridgeImpl.channelName, binaryMessenger: messenger)
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
        self.speechRecognizer?.delegate = self
        self.channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }
        setupInterruptionObserver()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAvailability":
            result(checkAvailability())
        case "isOnDeviceAvailable":
            result(isOnDeviceRecognitionAvailable())
        case "startListening":
            let args = call.arguments as? [String: Any]
            let silenceTimeout = args?["silenceTimeout"] as? Double
            startListening(silenceTimeoutSec: silenceTimeout, result: result)
        case "stopListening":
            stopListening(result: result)
        case "cancelListening", "cancel":
            cancelListening(result: result)
        case "dispose":
            dispose()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkAvailability() -> String {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            return "restricted"
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return "notSupported"
        }

        if #available(iOS 13.0, *) {
            if recognizer.supportsOnDeviceRecognition {
                return "available"
            } else {
                return "notSupported"
            }
        } else {
            return "notSupported"
        }
    }

    private func isOnDeviceRecognitionAvailable() -> Bool {
        if #available(iOS 13.0, *) {
            return speechRecognizer?.supportsOnDeviceRecognition ?? false
        }
        return false
    }

    private func startListening(silenceTimeoutSec: Double?, result: @escaping FlutterResult) {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Speech recognition permission not granted", details: nil))
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            result(FlutterError(code: "SPEECH_NOT_AVAILABLE", message: "Speech recognition is not available", details: nil))
            return
        }

        if #available(iOS 13.0, *) {
            guard recognizer.supportsOnDeviceRecognition else {
                result(FlutterError(code: "SPEECH_NOT_AVAILABLE", message: "On-device speech recognition is not supported for current locale", details: nil))
                return
            }
        }

        cleanupSession()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            if #available(iOS 13.0, *) {
                // Strict on-device enforcement: zero cloud fallback
                request.requiresOnDeviceRecognition = true
            }
            request.shouldReportPartialResults = true
            self.recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

            let silenceTimeout = silenceTimeoutSec ?? SpeechBridgeImpl.defaultSilenceTimeoutSec
            resetSilenceTimer(timeoutSec: silenceTimeout)

            maxSessionTimer = Timer.scheduledTimer(withTimeInterval: SpeechBridgeImpl.maxSessionDurationSec, repeats: false) { [weak self] _ in
                self?.stopListeningInternal()
            }

            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (recognitionResult, error) in
                guard let self = self else { return }

                if let recognitionResult = recognitionResult {
                    let transcript = recognitionResult.bestTranscription.formattedString
                    let isFinal = recognitionResult.isFinal

                    self.resetSilenceTimer(timeoutSec: silenceTimeout)

                    self.channel.invokeMethod("onSpeechResult", arguments: [
                        "text": transcript,
                        "isFinal": isFinal
                    ])

                    if isFinal {
                        self.cleanupSession()
                    }
                }

                if let error = error {
                    let nsError = error as NSError
                    // Ignore cancellation code 2016
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 2016 {
                        self.cleanupSession()
                        return
                    }

                    self.channel.invokeMethod("onSpeechError", arguments: [
                        "error": "SPEECH_NOT_AVAILABLE",
                        "message": error.localizedDescription
                    ])
                    self.cleanupSession()
                }
            }

            result(true)
        } catch {
            cleanupSession()
            result(FlutterError(code: "SPEECH_NOT_AVAILABLE", message: error.localizedDescription, details: nil))
        }
    }

    private func stopListening(result: @escaping FlutterResult) {
        stopListeningInternal()
        result(true)
    }

    private func stopListeningInternal() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        maxSessionTimer?.invalidate()
        maxSessionTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
        }
    }

    private func cancelListening(result: @escaping FlutterResult) {
        cleanupSession()
        result(true)
    }

    private func resetSilenceTimer(timeoutSec: TimeInterval) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: timeoutSec, repeats: false) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            self.stopListeningInternal()
        }
    }

    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.isListening else { return }
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            if type == .began {
                self.channel.invokeMethod("onSpeechError", arguments: [
                    "error": "AUDIO_INTERRUPTED",
                    "message": "Audio session interrupted by system"
                ])
                self.cleanupSession()
            }
        }
    }

    private func cleanupSession() {
        isListening = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        maxSessionTimer?.invalidate()
        maxSessionTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func dispose() {
        cleanupSession()
        NotificationCenter.default.removeObserver(self)
        channel.setMethodCallHandler(nil)
    }
}
