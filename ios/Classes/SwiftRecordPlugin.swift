import Flutter
import UIKit
import AVFoundation

public class SwiftRecordPlugin: NSObject, FlutterPlugin, AVAudioRecorderDelegate {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.llfbandit.record", binaryMessenger: registrar.messenger())
        let instance = SwiftRecordPlugin()
        instance.channel = channel;
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    var channel:FlutterMethodChannel!
    var isRecording = false
    var isPaused = false
    var hasPermission = false
    var audioRecorder: AVAudioRecorder?
    var volumeTimer:Timer?//定时器线程，循环监测录音的音量大小
    
    //音量分贝监听
    @objc func volumeListener(){
        if(audioRecorder == nil) {return}
        audioRecorder!.updateMeters() // 刷新音量数据
        var power:Float = audioRecorder!.averagePower(forChannel: 0) //获取音量的平均值
        if(power > 0.0) {return}
        power = power + 60;
        let dB:Float = power*2;
        channel.invokeMethod("onDecibelChange", arguments: dB)
    }
    
    //开始捕捉分贝值
    public func startTimer(){
        volumeTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self,selector: #selector(volumeListener),userInfo: nil, repeats: true)
    }
    
    //结束捕捉分贝值
    public func stopTimer(){
        if(volumeTimer==nil){
            return
        }
        
        volumeTimer!.invalidate()
        volumeTimer = nil
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            let args = call.arguments as! [String : Any]
            start(
                path: args["path"] as? String ?? "",
                encoder: args["encoder"] as? Int ?? 0,
                bitRate: args["bitRate"] as? Int ?? 128000,
                samplingRate: args["samplingRate"] as? Float ?? 44100.0,
                result: result);
            startTimer()
            break
        case "stop":
            stopTimer()
            stop(result)
            break
        case "pause":
            stopTimer()
            pause(result)
            break
        case "resume":
            resume(result)
            startTimer()
            break
        case "isPaused":
            result(isPaused)
            break
        case "isRecording":
            result(isRecording)
            break
        case "hasPermission":
            hasPermission(result);
            break
        default:
            result(FlutterMethodNotImplemented)
            break
        }
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
        stopRecording()
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        stopRecording()
    }
    
    fileprivate func hasPermission(_ result: @escaping FlutterResult) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSession.RecordPermission.granted:
            hasPermission = true
            break
        case AVAudioSession.RecordPermission.denied:
            hasPermission = false
            break
        case AVAudioSession.RecordPermission.undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    self.hasPermission = allowed
                }
            }
            break
        default:
            break
        }
        
        result(hasPermission)
    }
    
    fileprivate func start(path: String, encoder: Int, bitRate: Int, samplingRate: Float, result: @escaping FlutterResult) {
        stopRecording()
        
        let settings = [
            AVFormatIDKey: getEncoder(encoder),
            AVEncoderBitRateKey: bitRate,
            AVSampleRateKey: samplingRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ] as [String : Any]
        
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: options)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let url = URL(string: path) ?? URL(fileURLWithPath: path)
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder!.delegate = self
            audioRecorder!.isMeteringEnabled = true
            audioRecorder!.record()
            
            isRecording = true
            isPaused = false
            result(nil)
        } catch {
            result(FlutterError(code: "", message: "Failed to start recording", details: nil))
        }
    }
    
    fileprivate func stop(_ result: @escaping FlutterResult) {
        stopRecording()
        result(nil)
    }
    
    fileprivate func pause(_ result: @escaping FlutterResult) {
        audioRecorder?.pause()
        isPaused = true
        result(nil)
    }
    
    fileprivate func resume(_ result: @escaping FlutterResult) {
        if isPaused {
            audioRecorder?.record()
            isPaused = false
        }
        
        result(nil)
    }
    
    fileprivate func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        isPaused = false
    }
    
    // https://developer.apple.com/documentation/coreaudiotypes/coreaudiotype_constants/1572096-audio_data_format_identifiers
    fileprivate func getEncoder(_ encoder: Int) -> Int {
        switch(encoder) {
        case 1:
            return Int(kAudioFormatMPEG4AAC_ELD)
        case 2:
            return Int(kAudioFormatMPEG4AAC_HE)
        case 3:
            return Int(kAudioFormatAMR)
        case 4:
            return Int(kAudioFormatAMR_WB)
        case 5:
            return Int(kAudioFormatOpus)
        default:
            return Int(kAudioFormatMPEG4AAC)
        }
    }
}
