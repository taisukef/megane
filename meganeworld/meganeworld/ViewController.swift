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

extension UIColor {
    convenience init(value: Int, alpha: CGFloat) {
        let r = CGFloat(((value >> 16) & 255)) / 255
        let g = CGFloat(((value >> 8) & 255)) / 255
        let b = CGFloat(value & 255) / 255
        self.init(red: r, green: g, blue: b, alpha: min(max(alpha, 0), 1))
    }
    convenience init(value: Int) {
        self.init(value: value, alpha: 1.0)
    }
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        let cw:CGFloat = 1280
        let ch:CGFloat = 720
        //        let h2 = w2 * 1080 / 1920
        //let h2 = w2 * 480 / 640

        self.imageView1 = UIImageView()
        self.imageView2 = UIImageView()
        let w = self.view.frame.width
        let h = self.view.frame.height
        
        let w2 = w / 2
        let h2 = w2 / cw * ch
        let y = (h - h2) / 2
        
        let h1 = w / cw * ch
        let y1 = (h - h1) / 2
        
//        self.imageView1.frame = CGRect(x:0, y:y, width:w2, height:h2)
        self.imageView1.frame = CGRect(x:0, y:y1, width:w, height:h1)
        self.imageView2.frame = CGRect(x:w2, y:y, width:w2, height:h2)
        self.view.addSubview(self.imageView1)
        //self.view.addSubview(self.imageView2)

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
        session.sessionPreset = AVCaptureSession.Preset.iFrame1280x720 // CPU50%　16:9 かわらない？
        //session.sessionPreset = AVCaptureSession.Preset.hd1280x720 // CPU50% 16:9 きれい
        //session.sessionPreset = AVCaptureSession.Preset.hd1920x1080 // CPU88% 16:9 かわらない？ iPhone6でもQRcode offならOK!
        //session.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160 // CPU93% 16:9 かわらない？ QRcode offなら実用的

        camera = AVCaptureDevice.default(
            AVCaptureDevice.DeviceType.builtInWideAngleCamera,
            for: AVMediaType.video,
            position: .back
//            position: .front
        )
        
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
        //filterone = CIFilter(name: "CIPhotoEffectTransfer") // 古い写真のように

        var filter:CIFilter?
        filter = CIFilter(name: "CITwirlDistortion") // 視界がひずむ
        filters.append(filter!)

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
    var meganeoption = 6
    let nmeganeoption = 7
    var imgmegane = UIImage(named:"megane")!
    func drawMegane(image: UIImage) -> UIImage {
        UIGraphicsBeginImageContext(image.size)
        let rect = CGRect(x:0, y:0, width:image.size.width, height:image.size.height)
        image.draw(in: rect)
        let g = UIGraphicsGetCurrentContext()!
        
        // 顔認識
        /*
        let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyLow] )!
        let features : NSArray = detector.features(in: CIImage(image: image)!) as NSArray
*/
        let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        // 取得するパラメーターを指定する
        let options = [CIDetectorSmile : true, CIDetectorEyeBlink : true]
        
        // 画像から特徴を抽出する
        let features = detector!.features(in: CIImage(image: image)!, options: options)

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
                } else if (meganeoption == 4) {
                    // SDGs Megane
                    let SDGS_COLORS = [
                        UIColor.init(value: 0xE5243B),
                        UIColor.init(value: 0xDDA63A),
                        UIColor.init(value: 0x4C9F38),
                        UIColor.init(value: 0xC5192D),
                        UIColor.init(value: 0xFF3A21),
                        UIColor.init(value: 0x26BDE2),
                        UIColor.init(value: 0xFCC30B),
                        UIColor.init(value: 0xA21942),
                        UIColor.init(value: 0xFD6925),
                        UIColor.init(value: 0xDD1367),
                        UIColor.init(value: 0xFD9D24),
                        UIColor.init(value: 0xBF8B2E),
                        UIColor.init(value: 0x3F7E44),
                        UIColor.init(value: 0x0A97D9),
                        UIColor.init(value: 0x56C02B),
                        UIColor.init(value: 0x00689D),
                        UIColor.init(value: 0x19486A),
                    ]
                    let COLORS = [ 14,15,16,17,1,2,3,4,5,10,11,12,13,6,7,8,9 ]
                    
                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    let r = len / 3
                    let bold = r / 2
                    
                    g.setLineWidth(bold)
                    
                    let thgap = Double.pi * 2 / 360
                    
                    // bridge
                    g.setStrokeColor(SDGS_COLORS[COLORS[8] - 1].cgColor)
                    let cx = (left.x + right.x) / 2
                    let cy = (left.y + right.y) / 2
                    let bridge = r * 0.35
                    let th = atan2(dy, dx)
                    let bth = th - CGFloat(Double.pi / 2)
                    let x1 = cx + cos(bth) * bridge
                    let y1 = cy + sin(bth) * bridge
                    //let dth = Double.pi * 2 / 8
                    let dth = Double.pi * 2.5 / 8
                    let th1 = Double.pi - dth / 2 + Double(bth) + thgap
                    let th2 = th1 + dth - thgap * 2
                    g.beginPath()
                    g.addArc(center: CGPoint(x: x1, y: y1), radius: r, startAngle: CGFloat(th1), endAngle: CGFloat(th2), clockwise: false)
                    g.strokePath()
                    
                    // left
                    let gth = th - CGFloat(Double.pi)
                    for i in 0..<8 {
                        g.setStrokeColor(SDGS_COLORS[COLORS[i] - 1].cgColor)
                        g.beginPath()
                        let th1 = Double.pi * 2 / 8 * Double(i) + thgap + Double(gth)
                        let th2 = th1 + Double.pi * 2 / 8 - thgap * 2
                        g.addArc(center: left, radius: r, startAngle: CGFloat(th1), endAngle: CGFloat(th2), clockwise: false)
                        g.strokePath()
                    }
                    // right
                    for i in 0..<8 {
                        g.setStrokeColor(SDGS_COLORS[COLORS[i + 9] - 1].cgColor)
                        let th1 = Double.pi * 2 / 8 * Double(i) + thgap + Double(gth)
                        let th2 = th1 + Double.pi * 2 / 8 - thgap * 2
                        g.beginPath()
                        g.addArc(center: right, radius: r, startAngle: CGFloat(th1), endAngle: CGFloat(th2), clockwise: false)
                        g.strokePath()
                    }
                } else if (meganeoption == 5) {
                    // Choco
                    let CHOCO_COLORS = [
                        UIColor.init(value: 0xF8F365),
                        UIColor.init(value: 0xD98A8A),
                        UIColor.init(value: 0xE59B47),
                        UIColor.init(value: 0xC8C573),
                        UIColor.init(value: 0xBA7665),
                    ]
                    let BG_COLOR = UIColor.init(value: 0x9BA3AF)
                    let HIGHLIGHT_COLOR = UIColor.init(value: 0xF0F0F0)

                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    let r = len / 3 * 1.1
                    let bold = r
                    let th = atan2(dy, dx)

                    
                    let gth = th - CGFloat(Double.pi)

                    // left
                    var nch = 0
                    for j in 0..<2 {
                        let center = j == 0 ? left : right
                        g.setLineWidth(bold)
                        g.setStrokeColor(BG_COLOR.cgColor)
                        g.beginPath()
                        g.addArc(center: center, radius: r, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
                        g.strokePath()
                    }
                    for j in 0..<2 {
                        let center = j == 0 ? left : right
                        let cr = r / 6
                        for i in 0..<7 {
                            let n = nch % CHOCO_COLORS.count
                            nch += 1
                            g.setStrokeColor(CHOCO_COLORS[n].cgColor)
                            var th1 = Double.pi * 2 / 7 * Double(i) + Double(gth)
                            if j == 0 {
                                th1 += Double.pi * 2 / 7 / 2
                            }
                            let cx = center.x + CGFloat(cos(th1)) * r
                            let cy = center.y + CGFloat(sin(th1)) * r
                            g.setLineWidth(cr * 2)
                            g.beginPath()
                            g.addArc(center: CGPoint(x: cx, y: cy), radius: cr, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: false)
                            g.strokePath()
                            
                            let thh = Double.pi * 15 / 8
                            g.setStrokeColor(HIGHLIGHT_COLOR.cgColor)
                            let cx2 = cx + CGFloat(cos(thh)) * CGFloat(cr)
                            let cy2 = cy + CGFloat(sin(thh)) * CGFloat(cr)
                            g.setLineWidth(cr / 2)
                            g.beginPath()
                            g.addArc(center: CGPoint(x: cx2, y: cy2), radius: cr / 4, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: false)
                            g.strokePath()

                        }

                    }
                } else if (meganeoption == 6) {
                    // Katapan
                    
                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    let th = atan2(dy, dx)
                    let cx = (left.x + right.x) / 2
                    let cy = (left.y + right.y) / 2
                    
                    let mw = len * 2.2
                    let mh = mw / imgmegane.size.width * imgmegane.size.height
                    let px = cx - mw / 2
                    let py = cy - mh / 2
                    
                    g.saveGState()
                    g.translateBy(x: cx, y: cy)
                    g.scaleBy(x: 1.0, y: -1.0)
                    g.rotate(by: CGFloat(-th))
                    g.translateBy(x: -cx, y: -cy)
                    imgmegane.draw(in: CGRect(x: px, y: py, width: mw, height: mh))
                    g.restoreGState()
                    
                } else {
                    /*
                    g.setStrokeColor(UIColor.black.cgColor)
                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    g.setLineWidth(4)
                    
                    let th = atan2(dy, dx)
                    g.beginPath()
                    let x1 = right.x
                    let y1 = right.y
                    let x2 = right.x + cos(th) * len
                    let y2 = right.y + sin(th) * len
                    g.move(to:CGPoint(x:x1, y:y1))
                    g.addLine(to:CGPoint(x:x2, y:y2))
                    g.strokePath()

                    g.setStrokeColor(UIColor.red.cgColor)
                    g.beginPath()
                    g.move(to:right)
                    g.addLine(to:left)
                    g.strokePath()
*/
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
                if meganeoption == nmeganeoption - 1 {
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
                    meganeoption = nmeganeoption - 1
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

