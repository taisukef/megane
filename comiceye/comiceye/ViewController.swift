//
//  ViewController.swift
//  megane, QR code detector glass with VR goggle
//
//  CC BY taisukef on 2018/05/24.
//  http://fukuno.jig.jp/2133
//

import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        self.imageView1 = UIImageView()
        self.imageView2 = UIImageView()
        let w = self.view.frame.width
        let h = self.view.frame.height
        let w2 = w / 2
        // AVCaptureSession.Preset. に合わせる
//        let h2 = w2 * 1080 / 1920
        let h2 = w2 / 640 * 480
        let y = (h - h2) / 2
        self.imageView1.frame = CGRect(x:0, y:y, width:w2, height:h2)
        self.imageView2.frame = CGRect(x:self.view.frame.width / 2, y:y, width:w2, height:h2)
        self.view.addSubview(self.imageView1)
        self.view.addSubview(self.imageView2)

        self.initNotificationsFromAppDelegate()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var input:AVCaptureDeviceInput!
    var output:AVCaptureVideoDataOutput!
    var session:AVCaptureSession!
    var camera:AVCaptureDevice!
    
    var imageView1:UIImageView!
    var imageView2:UIImageView!

    override func viewWillAppear(_ animated: Bool) {
        self.configureCamera()
        self.listenVolumeButton()
    }
    // notifications foreground and background
    func initNotificationsFromAppDelegate() {
        NotificationCenter.default.addObserver(self, selector: #selector(type(of: self).viewWillEnterForeground(notification:)), name: NSNotification.Name(rawValue: "applicationWillEnterForeground"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(type(of: self).viewDidEnterBackground(notification:)), name: NSNotification.Name(rawValue: "applicationDidEnterBackground"), object: nil)
    }
    @objc func viewWillEnterForeground(notification: NSNotification?) {
        print("foreground")
        self.listenVolumeButton()
    }
    @objc func viewDidEnterBackground(notification: NSNotification?) {
        print("background")
        self.removeVolumeButton()
    }
    //
    override func viewDidDisappear(_ animated: Bool) {
        session.stopRunning()
        for output in session.outputs {
            session.removeOutput(output)
        }
        for input in session.inputs {
            session.removeInput(input)
        }
        session = nil
        camera = nil
    }
    let DETECT_QRCODE = false
    func configureCamera() {
        session = AVCaptureSession()
        // iPhone Xで実験
        //session.sessionPreset = AVCaptureSession.Preset.cif352x288 // 34% 荒い
        session.sessionPreset = AVCaptureSession.Preset.vga640x480 // 47% 4:3 なかなかきれい
        //session.sessionPreset = AVCaptureSession.Preset.iFrame1280x720 // CPU50%　16:9 かわらない？
        //session.sessionPreset = AVCaptureSession.Preset.hd1280x720 // CPU50% 16:9 きれい
        //session.sessionPreset = AVCaptureSession.Preset.hd1920x1080 // CPU88% 16:9 かわらない？ iPhone6でもQRcode offならOK!
        //session.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160 // CPU93% 16:9 かわらない？ QRcode offなら実用的

        camera = AVCaptureDevice.default(
            AVCaptureDevice.DeviceType.builtInWideAngleCamera,
            for: AVMediaType.video,
            position: .back) // position: .front
        
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch let error as NSError {
            print(error)
        }
        if (session.canAddInput(input)) {
            session.addInput(input)
        }
        
        output = AVCaptureVideoDataOutput() // AVCapturePhotoOutput() 写真用
        output?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)] as? [String : Any]
        
        let queue:DispatchQueue = DispatchQueue(label: "myqueue", attributes: .concurrent)
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true // 間に合わないものは処理しない
        
        if (session.canAddOutput(output)) {
            session.addOutput(output)
        }
        
        // filter
        //フィルタのカメラへの追加
        var filter:CIFilter?
        
        
        filter = CIFilter(name: "CIComicEffect") // おもしろいけど、ちょっと重い VGAなら大丈夫！
        filters.append(filter!)
//        filter = CIFilter(name: kCICategoryHalftoneEffect) // error
        
        // 元画像幅高さ
        let iw: CGFloat = 640
        let ih: CGFloat = 480
        
        // 左右反転
        filter = CIFilter(name: "CIAffineTransform")
        filter!.setValue(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: iw, ty: 0), forKey: kCIInputTransformKey)
        filters.append(filter!)

        // 上下反転
        filter = CIFilter(name: "CIAffineTransform")
        filter!.setValue(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: ih), forKey: kCIInputTransformKey)
        filters.append(filter!)
        
        // 上下左右反転
        filter = CIFilter(name: "CIAffineTransform")
        filter!.setValue(CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: iw, ty: ih), forKey: kCIInputTransformKey)
        filters.append(filter!)

        filter = CIFilter(name: "CIEdgeWork")
//        filter!.setValue(6, forKey: kCIAttributeTypeDistance)
        filters.append(filter!)

        filter = CIFilter(name: "CICMYKHalftone", parameters: [ "inputWidth": 10 ])! // 印刷物っぽく
        filters.append(filter!)

        filter = CIFilter(name: "CICrystallize", parameters: [ "inputRadius": 20 ])! // クリスタル風
        filters.append(filter!)

//        filter = CIFilter(name: "CILineOverlay") // 線画・・・真っ暗になる？
//        filters.append(filter!)

        filter = CIFilter(name: "CIHighlightShadowAdjust") // 線画
        filters.append(filter!)

        //        filter = CIFilter(name: "CIDepthOfField") // 周りがぼける
//        filters.append(filter!)
        
        filter = CIFilter(name: "CIPhotoEffectTransfer") // 古い写真のように
        filters.append(filter!)
        
        filter = CIFilter(name: "CIPhotoEffectTonal") // モノクロ写真のように
        filters.append(filter!)
        
        filter = CIFilter(name: "CIColorPosterize") // 減色モード
        filters.append(filter!)

        //filter = CIFilter(name: "CIPointillize")
//        filter = CIFilter(name: "CILineOverlay") // まっくら？
//        filter = CIFilter(name: "CIGloom") // 変化少ない

        //filter = CIFilter(name: "CIDepthOfField") // 遅い重い、ピンとあわない？
//        filter = CIFilter(name: "CIBloom") // ふわっとする
//        filters.append(filter!)
        //filter = CIFilter(name: "CISharpenLuminance")
        //filter = CIFilter(name: "CIHoleDistortion") // うごかない
        //filter = CIFilter(name: "CITorusLensDistortion") // トーラスがうつる
        //filter = CIFilter(name: "CITwirlDistortion") // 視界がひずむ
        //filter = CIFilter(name: "CITriangleKaleidoscope") // 万華鏡、エラー
        //filter = CIFilter(name: "CITriangleTile") // エラー
        
        //filter = CIFilter(name: "CIVignette") // 変化がわからない？
        //filter?.setValue(10.0, forKey: kCIInputRadiusKey) // default 1.00
        //filter?.setValue(0.8, forKey: kCIInputIntensityKey) // default 0.0
        
        //filter = CIFilter(name: "CIMedianFilter") // ノイズ除去、きいてる？
        //filter = CIFilter(name: "CISpotLight") // スポットライトがあたるように、しぶい！
        // filter = CIFilter(name: "CISpotColor") // 色変換？おもしろい
        
  //      filter = CIFilter(name: "CISepiaTone")
//        filter?.setValue(0.1, forKey: kCIInputIntensityKey) // default: 1.00 // 強さ
        
//        toonFilter.threshold = 1
        
        session.startRunning()
    }
    var filters:Array<CIFilter> = []
    var nfilter = 0
//    var toonFilter = GPUImageSmoothToonFilter()
    var zoom:CGFloat = 1.0
    func captureOutput(_: AVCaptureOutput, didOutput: CMSampleBuffer, from: AVCaptureConnection) {
        //        from.videoOrientation = .portrait //デバイスの向きを設定、縦の時
        from.videoOrientation = .landscapeLeft //デバイスの向きを設定、landscape left の時
        DispatchQueue.main.sync(execute: {
            var image = self.imageFromSampleBuffer(sampleBuffer: didOutput)
            
            // filter
            
            if filters.count > 0 {
                let filter = filters[nfilter]
                filter.setValue(CIImage(image: image), forKey: kCIInputImageKey)
                image = UIImage(ciImage: filter.outputImage!)
            }
 
  //          image = toonFilter.imageByFilteringImage(image)
            
            image = resizeImage(image: image, ratio: zoom)
            if DETECT_QRCODE {
                image = drawQR(image: image)
            }
            self.imageView1.image = image
            self.imageView2.image = image
        })
    }
    func resizeImage(image: UIImage, ratio: CGFloat) -> UIImage {
        if ratio == 1.0 {
            return image
        }
        let iw = image.size.width / ratio
        let ih = image.size.height / ratio
        let size = CGSize(width: iw, height: ih)
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(origin: CGPoint(x:-(image.size.width - iw) / 2, y:-(image.size.height - ih) / 2), size: image.size))
        let resimage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resimage
    }
    func drawQR(image: UIImage) -> UIImage {
        UIGraphicsBeginImageContext(image.size)
        let rect = CGRect(x:0, y:0, width:image.size.width, height:image.size.height)
        image.draw(in: rect)
        let g = UIGraphicsGetCurrentContext()!
        g.setStrokeColor(UIColor.white.cgColor)
        g.setLineWidth(6)

        let font = UIFont.boldSystemFont(ofSize: 14 * 4)
        let textStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        let textFontAttributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.paragraphStyle: textStyle
        ]

        // 顔認識もおもしろい
//        let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyLow] )!
        // 読める四角は今のところひとつだけ
        //            let detector : CIDetector = CIDetector(ofType: CIDetectorTypeRectangle, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorAspectRatio: 1.0] )!
        let detector : CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh] )!
        let features : NSArray = detector.features(in: CIImage(image: image)!) as NSArray
        if features.count > 0 {
//           for feature in features as! [CIFaceFeature] {
                        for feature in features as! [CIQRCodeFeature] {
                var rect: CGRect = (feature as AnyObject).bounds
                rect.origin.y = image.size.height - rect.origin.y - rect.size.height
                
                // QRコードを上書き！
                g.beginPath()
                g.setFillColor(UIColor.white.cgColor)
                g.setStrokeColor(UIColor.white.cgColor)
                g.addRect(rect)
                g.fillPath()
                g.strokePath()

                feature.messageString?.draw(in: rect, withAttributes: textFontAttributes)
            }
        }
        let resimage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resimage!
    }
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        let imageRef = context!.makeImage()
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return UIImage(cgImage: imageRef!)
    }
    // volume switch
    var initialVolume = 0.0
    var volumeView: MPVolumeView?
    func listenVolumeButton() {
        volumeView = MPVolumeView(frame: CGRect(x:-3000, y:0, width:0, height:0))
        view.addSubview(volumeView!)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            let vol = audioSession.outputVolume
            initialVolume = Double(vol.description)!
            if initialVolume > 0.9 {
                initialVolume = 0.8
            } else if initialVolume < 0.1 {
                initialVolume = 0.2
            }
        } catch {
            print("error: \(error)")
        }
        audioSession.addObserver(self, forKeyPath: "outputVolume", options:
            NSKeyValueObservingOptions.new, context: nil)
    }
    func removeVolumeButton() {
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        volumeView?.removeFromSuperview()
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            let volume = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).floatValue
            let newVolume = Double(volume)
            if newVolume > initialVolume + 0.05 {
               // if let view = volumeView?.subviews.first as? UISlider {
                    // volume up pressed
                 //   view.value = Float(initialVolume)
                    
                    /*
                    if zoom < 12.0 {
                        zoom *= 1.2
                    } else {
                        zoom = 1.0
                    }
                    print("zoom: \(zoom)")
 */
                    if nfilter == filters.count - 1 {
                        nfilter = 0
                    } else {
                        nfilter += 1
                    }
               // }
            } else if newVolume < initialVolume - 0.05 {
              //  if let view = volumeView?.subviews.first as? UISlider {
                    // volume down pressed
                //    view.value = Float(initialVolume)
                    
                    /*
                    if zoom > 1.0 {
                        zoom /= 1.2
                    }
 */
                /*
                    flashLED(flg: flashflg)
                    flashflg = !flashflg
 */
                if nfilter == 0 {
                    nfilter = filters.count - 1
                } else {
                    nfilter -= 1
                }

                    /*
                    if let image = self.imageView1.image {
                        saveImage(image: image)
                        print("save image")
                    }
 */
                //}
            }
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //let touch = touches.first!
        //let location = touch.location(in: self.view)
        if let image = self.imageView1.image {
            saveImage(image: image)
            print("save image")
        }
    }
    // save
    private func saveImage(image: UIImage) {
        //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
    }
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
        if let error = error {
            // we got back an error!
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: "Saved!", message: "Your altered image has been saved to your photos.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }
    // flash LED
    var flashflg = false
    func flashLED(flg: Bool) {
        let device = AVCaptureDevice.default(for: AVMediaType.video)!
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                if (flg) {
                    device.torchMode = AVCaptureDevice.TorchMode.on
                } else {
                    device.torchMode = AVCaptureDevice.TorchMode.off
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
}

