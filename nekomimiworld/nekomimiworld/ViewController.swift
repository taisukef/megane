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
        let h2 = w2 * 1080 / 1920
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
    let DETECT_FACE = true
    let FILTER_SUPPORT = false
    func configureCamera() {
        session = AVCaptureSession()
        // iPhone Xで実験
        //session.sessionPreset = AVCaptureSession.Preset.cif352x288 // 34% 荒い
        //session.sessionPreset = AVCaptureSession.Preset.vga640x480 // 47% 4:3 なかなかきれい
        //session.sessionPreset = AVCaptureSession.Preset.iFrame1280x720 // CPU50%　16:9 かわらない？
        session.sessionPreset = AVCaptureSession.Preset.hd1280x720 // CPU50% 16:9 きれい
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
        output?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)] as! [String : Any]
        
        let queue:DispatchQueue = DispatchQueue(label: "myqueue", attributes: .concurrent)
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true // 間に合わないものは処理しない
        
        if (session.canAddOutput(output)) {
            session.addOutput(output)
        }
        
        // filter
        //フィルタのカメラへの追加
//        filterone = CIFilter(name: "CIPhotoEffectTransfer") // 古い写真のように

        var filter:CIFilter?
        filter = CIFilter(name: "CIComicEffect") // おもしろいけど、ちょっと重い VGAなら大丈夫！
        filters.append(filter!)
//        filter = CIFilter(name: kCICategoryHalftoneEffect) // error
        
        filter = CIFilter(name: "CIEdgeWork")
//        filter!.setValue(6, forKey: kCIAttributeTypeDistance)
        filters.append(filter!)

        filter = CIFilter(name: "CIColorPosterize") // おもしろいけど、ちょっと重い VGAなら大丈夫！
        filters.append(filter!)

        //filter = CIFilter(name: "CIPointillize")
//        filter = CIFilter(name: "CILineOverlay") // まっくら？
//        filter = CIFilter(name: "CIGloom") // 変化少ない

        //filter = CIFilter(name: "CIDepthOfField") // 遅い重い、ピンとあわない？
        filter = CIFilter(name: "CIBloom") // ふわっとする
        filters.append(filter!)
        //filter = CIFilter(name: "CISharpenLuminance")
        //filter = CIFilter(name: "CIHoleDistortion") // うごかない
        //filter = CIFilter(name: "CITorusLensDistortion") // トーラスがうつる
        //filter = CIFilter(name: "CITwirlDistortion") // 視界がひずむ
        //filter = CIFilter(name: "CITriangleKaleidoscope") // 万華鏡、エラー
        //filter = CIFilter(name: "CITriangleTile") // エラー
        
        //filter = CIFilter(name: "CIVignette") // 変化がわからない？
        //filter?.setValue(10.0, forKey: kCIInputRadiusKey) // default 1.00
        //filter?.setValue(0.8, forKey: kCIInputIntensityKey) // default 0.0
        
        filter = CIFilter(name: "CIPhotoEffectTransfer") // 古い写真のように
        filters.append(filter!)
        
        filter = CIFilter(name: "CIPhotoEffectTonal") // モノクロ写真のように
        filters.append(filter!)
        
        //filter = CIFilter(name: "CIMedianFilter") // ノイズ除去、きいてる？
        //filter = CIFilter(name: "CISpotLight") // スポットライトがあたるように、しぶい！
        // filter = CIFilter(name: "CISpotColor") // 色変換？おもしろい
        
  //      filter = CIFilter(name: "CISepiaTone")
//        filter?.setValue(0.1, forKey: kCIInputIntensityKey) // default: 1.00 // 強さ
        
        session.startRunning()
    }
    var filters:Array<CIFilter> = []
    var filterone:CIFilter?
    
    var nfilter = 0
    var zoom:CGFloat = 1.0
    func captureOutput(_: AVCaptureOutput, didOutput: CMSampleBuffer, from: AVCaptureConnection) {
        //        from.videoOrientation = .portrait //デバイスの向きを設定、縦の時
        from.videoOrientation = .landscapeLeft //デバイスの向きを設定、landscape left の時
        DispatchQueue.main.sync(execute: {
            var image = self.imageFromSampleBuffer(sampleBuffer: didOutput)
            
            // filter
            if FILTER_SUPPORT {
                if filters.count > 0 {
                    let filter = filters[nfilter]
                    filter.setValue(CIImage(image: image), forKey: kCIInputImageKey)
                    image = UIImage(ciImage: filter.outputImage!)
                }
            }

            image = resizeImage(image: image, ratio: zoom)
            if DETECT_QRCODE {
                image = drawQR(image: image)
            }
            if DETECT_FACE {
                image = drawMegane(image: image)
            }

            if let filter = filterone {
                filter.setValue(CIImage(image: image), forKey: kCIInputImageKey)
                image = UIImage(ciImage: filter.outputImage!)
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
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: UIColor.black,
            NSAttributedStringKey.paragraphStyle: textStyle
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
    var meganeoption = 4
    func drawMegane(image: UIImage) -> UIImage {
        UIGraphicsBeginImageContext(image.size)
        let rect = CGRect(x:0, y:0, width:image.size.width, height:image.size.height)
        image.draw(in: rect)
        let g = UIGraphicsGetCurrentContext()!
        
        // 顔認識
        let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyLow] )!
        let features : NSArray = detector.features(in: CIImage(image: image)!) as NSArray
        if features.count > 0 {
            for feature in features as! [CIFaceFeature] {
                var rect: CGRect = feature.bounds
                rect.origin.y = image.size.height - rect.origin.y - rect.size.height
                
                /*
                 CIFaceFeature
                 bounds    CGRect    顔の大きさ/位置情報
                 faceAngle    float    顔の傾き
                 leftEyePosition    CGPoint    左目の位置
                 rightEyePosition    CGPoint    右目の位置
                 mouthPosition    CGPoint    口の位置
                 hasSmile    BOOL    笑顔かどうか
                 leftEyeClosed    BOOL    左目が閉じているかどうか
                 rightEyeClosed    BOOL    右目が閉じているかどうか
                 */
                
                let left = CGPoint(x: feature.leftEyePosition.x, y:image.size.height - feature.leftEyePosition.y)
                let right = CGPoint(x: feature.rightEyePosition.x, y:image.size.height - feature.rightEyePosition.y)

                if meganeoption < 3 {
                    if meganeoption == 0 {
                        g.setStrokeColor(UIColor.red.cgColor)
                    } else if meganeoption == 1 {
                        g.setStrokeColor(UIColor.black.cgColor)
                    } else if meganeoption == 2 {
                        g.setStrokeColor(UIColor.white.cgColor)
                    }
                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    let r = len / 2 * 0.8
                    let bold = r / 3
                    
                    g.setLineWidth(bold)
                    
                    g.beginPath()
                    g.addArc(center: left, radius: r, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
                    g.strokePath()
                    g.beginPath()
                    g.addArc(center: right, radius: r, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
                    g.strokePath()
                    
                    let bridge = len - r * 2
                    let th = atan2(dy, dx)
                    g.beginPath()
                    let x1 = right.x + cos(th) * r
                    let y1 = right.y + sin(th) * r
                    let x2 = right.x + cos(th) * (r + bridge)
                    let y2 = right.y + sin(th) * (r + bridge)
                    g.move(to:CGPoint(x:x1, y:y1))
                    g.addLine(to:CGPoint(x:x2, y:y2))
                    g.strokePath()
                } else if meganeoption == 3 {
                    g.setStrokeColor(UIColor.black.cgColor)
                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    let bold = len / 2
                    g.setLineWidth(bold)
                    
                    let barlen = len
                    let th = atan2(dy, dx)
                    g.beginPath()
                    let x1 = right.x - cos(th) * barlen
                    let y1 = right.y - sin(th) * barlen
                    let x2 = left.x + cos(th) * barlen
                    let y2 = left.y + sin(th) * barlen
                    g.move(to:CGPoint(x:x1, y:y1))
                    g.addLine(to:CGPoint(x:x2, y:y2))
                    g.strokePath()
                } else if meganeoption == 4 { // nekomimi
                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    let th = atan2(dy, dx);
                    
                    let ox = [ right.x, left.x ]
                    let oy = [ right.y, left.y ]
                    
                    for n in 0...1 {
                        let dir = CGFloat(n == 0 ? 1 : -1)
                        let deg0 = 90 + 20 * dir
                        let th0 = th + CGFloat.pi / 180 * CGFloat(deg0)
                        let len0 = len * 1.3
                        let x0 = ox[n] + cos(th0) * len0
                        let y0 = oy[n] + sin(th0) * len0
                        
                        g.beginPath()
                        g.setLineWidth(4)
                        g.setFillColor(UIColor.white.cgColor)

                        let th1 = th0 + CGFloat.pi / 180 * 20 * dir
                        let len1 = len * 0.4
                        let x1 = x0 + cos(th1) * len1
                        let y1 = y0 + sin(th1) * len1
                        g.move(to:CGPoint(x:x1, y:y1))

                        let th2 = th1 + CGFloat.pi / 180 * 120 * dir
                        let len2 = len * 0.6
                        let x2 = x0 + cos(th2) * len2
                        let y2 = y0 + sin(th2) * len2
                        g.addLine(to:CGPoint(x:x2, y:y2))

                        let th3 = th1 - CGFloat.pi / 180 * 120 * dir
                        let len3 = len * 0.6
                        let x3 = x0 + cos(th3) * len3
                        let y3 = y0 + sin(th3) * len3
                        g.addLine(to:CGPoint(x:x3, y:y3))
                        g.addLine(to:CGPoint(x:x1, y:y1))
                        g.fillPath()
                    }
                }
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
                initialVolume = 0.9
            } else if initialVolume < 0.1 {
                initialVolume = 0.1
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
                if meganeoption == 4 {
                    meganeoption = 0
                } else {
                    meganeoption += 1
                }
                if FILTER_SUPPORT {
                    if nfilter == filters.count - 1 {
                        nfilter = 0
                    } else {
                        nfilter += 1
                    }
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
                if meganeoption == 0 {
                    meganeoption = 4
                } else {
                    meganeoption -= 1
                }
                if FILTER_SUPPORT {
                    if nfilter == 0 {
                        nfilter = filters.count - 1
                    } else {
                        nfilter -= 1
                    }
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
    var flashflg = false
    // save
    private func saveImage(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    // flash LED
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

