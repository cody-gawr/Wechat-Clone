//
//  AudioPlayerManager.swift
//  TSWeChat
//
//  Created by Hilen on 12/22/15.
//  Copyright © 2015 Hilen. All rights reserved.
//

import Foundation
import AVFoundation
import Alamofire
import TSVoiceConverter
import RxSwift
import RxBlocking

let AudioPlayInstance = AudioPlayManager.sharedInstance

class AudioPlayManager: NSObject {
    fileprivate var audioPlayer: AVAudioPlayer?
    internal let disposeBag = DisposeBag()
    weak var delegate: PlayAudioDelegate?
    
    class var sharedInstance : AudioPlayManager {
        struct Static {
            static let instance : AudioPlayManager = AudioPlayManager()
        }
        return Static.instance
    }
    
    fileprivate override init() {
        super.init()
        //监听听筒和扬声器
        let center = NotificationCenter.default.rx.notification(Notification.Name(rawValue: UIDevice.proximityStateDidChangeNotification.rawValue), object: UIDevice.current)
        center.subscribe { notification in
            if UIDevice.current.proximityState {
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord)))
                } catch _ {}
            } else {
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
                } catch _ {}
            }
        }.dispose()
    }
    
    func startPlaying(_ audioModel: ChatAudioModel) {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
        } catch _ {}
        
        guard let keyHash = audioModel.keyHash else {
            self.delegate?.audioPlayFailed()
            return
        }
        //已有 wav 文件，直接播放
        let wavFilePath = AudioFilesManager.wavPathWithName(keyHash)
        if FileManager.default.fileExists(atPath: wavFilePath.path) {
            self.playSoundWithPath(wavFilePath.path)
            return
        }
        
        //已有 amr 文件，转换，再进行播放
        let amrFilePath = AudioFilesManager.amrPathWithName(keyHash)
        if FileManager.default.fileExists(atPath: amrFilePath.path) {
            self.convertAmrToWavAndPlaySound(audioModel)
            return
        }
        
        //都没有，就进行下载
        self.downloadAudio(audioModel)
    }
    
    // AVAudioPlayer 只能播放 wav 格式，不能播放 amr
    fileprivate func playSoundWithPath(_ path: String) {
        let fileData = try? Data(contentsOf: URL(fileURLWithPath: path))
        do {
            self.audioPlayer = try AVAudioPlayer(data: fileData!)
            
            guard let player = self.audioPlayer else { return }
            
            player.delegate = self
            player.prepareToPlay()
            
            guard let delegate = self.delegate else {
                log.error("delegate is nil")
                return
            }
            
            if player.play() {
                UIDevice.current.isProximityMonitoringEnabled = true
                delegate.audioPlayStart()
            } else {
                delegate.audioPlayFailed()
            }
        } catch {
            self.destroyPlayer()
        }
    }
    
    func destroyPlayer() {
        self.stopPlayer()
    }
    
    func stopPlayer() {
        if self.audioPlayer == nil {
            return
        }
        self.audioPlayer!.delegate = nil
        self.audioPlayer!.stop()
        self.audioPlayer?.prepareToPlay() //重置AVAudioSession
        self.audioPlayer = nil
        UIDevice.current.isProximityMonitoringEnabled = false
    }
    
    // 转换，并且播放声音
    fileprivate func convertAmrToWavAndPlaySound(_ audioModel: ChatAudioModel) {
        if self.audioPlayer != nil {
            self.stopPlayer()
        }
        
        guard let fileName = audioModel.keyHash, fileName.count > 0 else { return}

        let amrPathString = AudioFilesManager.amrPathWithName(fileName).path
        let wavPathString = AudioFilesManager.wavPathWithName(fileName).path        
        if FileManager.default.fileExists(atPath: wavPathString) {
            self.playSoundWithPath(wavPathString)
        } else {
            if TSVoiceConverter.convertAmrToWav(amrPathString, wavSavePath: wavPathString) {
                self.playSoundWithPath(wavPathString)
            } else {
                if let delegate = self.delegate {
                    delegate.audioPlayFailed()
                }
            }
        }
    }
    
    /**
     使用 Alamofire 下载并且存储文件
     */
    fileprivate func downloadAudio(_ audioModel: ChatAudioModel) {
        let fileName = audioModel.keyHash!
        let filePath = AudioFilesManager.amrPathWithName(fileName)
        let destination: (URL, HTTPURLResponse) -> (URL) = { (temporaryURL, response)  in
            log.info("checkAndDownloadAudio response:\(response)")
            if response.statusCode == 200 {
                if FileManager.default.fileExists(atPath: filePath.path) {
                    try! FileManager.default.removeItem(at: filePath)
                }
                log.info("filePath:\(filePath)")
                return filePath
            } else {
                return temporaryURL
            }
        }
        
        Alamofire.download(audioModel.audioURL!)
            .downloadProgress { progress in
                print("Download Progress: \(progress.fractionCompleted)")
            }
            .responseData { response in
                if let error = response.result.error, let delegate = self.delegate {
                    log.error("Failed with error: \(error)")
                    delegate.audioPlayFailed()
                } else {
                    log.info("Downloaded file successfully")
                    self.convertAmrToWavAndPlaySound(audioModel)
                }
        }
    }
}

// MARK: - @protocol AVAudioPlayerDelegate
extension AudioPlayManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        log.info("Finished playing the song")
        UIDevice.current.isProximityMonitoringEnabled = false
        if flag {
            self.delegate?.audioPlayFinished()
        } else {
            self.delegate?.audioPlayFailed()
        }
        self.stopPlayer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.stopPlayer()
        self.delegate?.audioPlayFailed()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        self.stopPlayer()
        self.delegate?.audioPlayFailed()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        
    }
}



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
