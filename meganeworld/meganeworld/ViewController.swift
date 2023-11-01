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
import CoreML
import Vision
import ImageIO

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

extension UIImage {
    //上下反転
    func flipVertical() -> UIImage {
        let scale = 1.0
        UIGraphicsBeginImageContextWithOptions(size, false, CGFloat(scale))
        let imageRef = self.cgImage
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0, y:  0)
        context?.scaleBy(x: 1.0, y: 1.0)
        context?.draw(imageRef!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let flipHorizontalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return flipHorizontalImage!
    }

    //左右反転
    func flipHorizontal() -> UIImage {
        let scale = 1.0
        UIGraphicsBeginImageContextWithOptions(size, false, CGFloat(scale))
        let imageRef = self.cgImage
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: size.width, y:  size.height)
        context?.scaleBy(x: -1.0, y: -1.0)
        context?.draw(imageRef!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let flipHorizontalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return flipHorizontalImage!
    }
    
    // resize
    func resize(w: Int, h: Int) -> UIImage {
        let origRef = self.cgImage
        let origWidth = Int(origRef!.width)
        let origHeight = Int(origRef!.height)
        var resizeWidth:Int = 0, resizeHeight:Int = 0

        if (origWidth < origHeight) {
            resizeWidth = w
            resizeHeight = origHeight * resizeWidth / origWidth
        } else {
            resizeHeight = h
            resizeWidth = origWidth * resizeHeight / origHeight
        }

        let resizeSize = CGSize.init(width: CGFloat(resizeWidth), height: CGFloat(resizeHeight))

        UIGraphicsBeginImageContext(resizeSize)

        self.draw(in: CGRect.init(x: 0, y: 0, width: CGFloat(resizeWidth), height: CGFloat(resizeHeight)))

        let res = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return res!
    }
    // 切り抜き処理
    func cropCenter(w: Int, h: Int) -> UIImage {
        let iw = self.cgImage!.width
        let ih = self.cgImage!.height
        let rect  = CGRect.init(x: CGFloat((iw - w) / 2), y: CGFloat((ih - h) / 2), width: CGFloat(w), height: CGFloat(h))
        let cgimg = self.cgImage!.cropping(to: rect)
        let res = UIImage(cgImage: cgimg!)
        return res
    }
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let CAMERA_FRONT = true
    let DETECT_QRCODE = false
    let DETECT_FACE = true
    let FILTER_SUPPORT = false
    let MEGANE_MODE = false
    let CLASSIFY_IMAGE = false

    var imageView1: UIImageView!
    var imageView2: UIImageView!
    var classficationLabel1: UILabel!
    var classficationLabel2: UILabel!
    
    var orgimage: UIImage!

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
        
        if MEGANE_MODE {
            self.imageView1.frame = CGRect(x: 0, y: y, width: w2, height: h2)
            self.imageView2.frame = CGRect(x: w2, y: y, width: w2, height: h2)
            self.view.addSubview(self.imageView1)
            self.view.addSubview(self.imageView2)
        } else {
            self.imageView1.frame = CGRect(x:0, y: y1, width: w, height: h1)
            self.view.addSubview(self.imageView1)
        }
        if CAMERA_FRONT {
            self.view.transform = self.view.transform.scaledBy(x: -1, y: 1)
        }
        
        if CLASSIFY_IMAGE {
            self.classficationLabel1 = UILabel()
            self.classficationLabel2 = UILabel()
            self.classficationLabel1.textAlignment = NSTextAlignment.center
            self.classficationLabel2.textAlignment = NSTextAlignment.center

            if MEGANE_MODE {
                let lh = y / 10
                let ly = y + h2 * 0.8 - lh
                self.classficationLabel1.frame = CGRect(x: 0, y: ly, width: w2, height: lh)
                self.view.addSubview(self.classficationLabel1)
                self.classficationLabel2.frame = CGRect(x: w2, y: ly, width: w2, height: lh)
                self.view.addSubview(self.classficationLabel2)

            } else {
                let lh = y / 10
                let ly = h * 0.8 - lh
                self.classficationLabel1.frame = CGRect(x: 0, y: ly, width: w, height: lh)
                self.view.addSubview(self.classficationLabel1)
            }
        }
        
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
    func configureCamera() {
        session = AVCaptureSession()
        // iPhone Xで実験
        //session.sessionPreset = AVCaptureSession.Preset.cif352x288 // 34% 荒い
        //session.sessionPreset = AVCaptureSession.Preset.vga640x480 // 47% 4:3 なかなかきれい
        
        // for iPhone11
        session.sessionPreset = AVCaptureSession.Preset.iFrame1280x720 // CPU50%　16:9 かわらない？、iPhone11 44% 解像度 8 750x1334, 8+ 1080x1920, XR/11 828×1792ドット, X/11Pro 1125×2436, 11ProMax 1242×2688
        //session.sessionPreset = AVCaptureSession.Preset.hd1280x720 // CPU50% 16:9 きれい
        //session.sessionPreset = AVCaptureSession.Preset.hd1920x1080 // CPU88% 16:9 かわらない？ iPhone6でもQRcode offならOK! iPhone11 44%
        //session.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160 // CPU93% 16:9 かわらない？ QRcode offなら実用的
        
        var deviceType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
        if #available(iOS 13.0, *) {
            deviceType = AVCaptureDevice.DeviceType.builtInUltraWideCamera
        }
        camera = AVCaptureDevice.default(
            deviceType,
            for: AVMediaType.video,
            position: CAMERA_FRONT ? .front : .back
        )
        if camera == nil {
            camera = AVCaptureDevice.default(
                AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                for: AVMediaType.video,
                position: CAMERA_FRONT ? .front : .back
            )
        }
        
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
        
        //session.startRunning()
        let backgroundQueue = DispatchQueue(label: "background_queue",
                                             qos: .background)
         
        backgroundQueue.async {
            self.session.startRunning()
        }
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
            self.orgimage = image

            image = resizeImage(image: image, ratio: zoom)
            if DETECT_QRCODE {
                image = drawQR(image: image)
            }
            if DETECT_FACE {
                image = drawMegane(image: image)
            }
            if CLASSIFY_IMAGE {
                updateClassifications(for: image)
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
    var meganeoption = 11
    let nmeganeoption = 12
    
    var imgmegane = UIImage(named:"megane")!
    var imgmayer = UIImage(named:"mayer")!
    var imgpumpkin = UIImage(named:"halloween_pumpkin7")!
    var imgwhowatch = UIImage(named:"whowatch")!
    var imgprocon = UIImage(named:"procon")!
    func drawImageFace(g: CGContext, img: UIImage, right: CGPoint, left: CGPoint, ratio: CGFloat, adjusty: CGFloat = 0) {
        let dx = left.x - right.x
        let dy = left.y - right.y
        let len = sqrt(dx * dx + dy * dy)
        let th = atan2(dy, dx)
        let cx = (left.x + right.x) / 2
        let cy = (left.y + right.y) / 2
        
        let mw = len * ratio
        let mh = mw / img.size.width * img.size.height
        let px = cx - mw / 2
        let py = cy - mh / 2 + (mh * adjusty)
        
        g.saveGState()
        g.translateBy(x: cx, y: cy)
        g.scaleBy(x: 1.0, y: -1.0)
        g.rotate(by: CGFloat(-th))
        g.translateBy(x: -cx, y: -cy)
        img.draw(in: CGRect(x: px, y: py, width: mw, height: mh))
        g.restoreGState()
    }
    
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
        //let options = [ CIDetectorSmile : true, CIDetectorEyeBlink : true ]
        let options = [ CIDetectorSmile : false, CIDetectorEyeBlink : false ]
        
        // 画像から特徴を抽出する
        let features = detector!.features(in: CIImage(image: image)!, options: options)

        if features.count > 0 {
            /*
            var faces : [CIFaceFeature] = []
            for feature in features as! [CIFaceFeature] {
                faces.append(feature)
            }
            let faces2 : [CIFaceFeature] = faces.sort { $0.bounds.width < $1.bounds.width }
             //for feature in faces2 {
            */
            //for feature in features as! [CIFaceFeature] {
            for i in (0..<features.count).reversed() { // 小さい顔から順に描画
                let feature: CIFaceFeature = features[i] as! CIFaceFeature
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
                    drawImageFace(g: g, img: imgmegane, right: right, left: left, ratio: 2.2)
                } else if (meganeoption == 7) {
                    // Mayer
                    drawImageFace(g: g, img: imgmayer, right: right, left: left, ratio: 8)
                } else if (meganeoption == 8) {
                    // Pumpkin
                    drawImageFace(g: g, img: imgpumpkin, right: right, left: left, ratio: 5, adjusty: -0.1)
                } else if (meganeoption == 9) {
                    // Whowatch
                    drawImageFace(g: g, img: imgwhowatch, right: right, left: left, ratio: 5, adjusty: -0.1)
                } else if (meganeoption == 10) {
                    // Whowatch
                    let imgprocon2 = CAMERA_FRONT ? imgprocon : imgprocon.flipHorizontal()
                    drawImageFace(g: g, img: imgprocon2, right: right, left: left, ratio: 4.1, adjusty: 0.15)
                } else if (meganeoption == 11) {
                    // Red rings
                    let COLOR = UIColor.init(value: 0xf80000)
                    
                    let dx = left.x - right.x
                    let dy = left.y - right.y
                    let len = sqrt(dx * dx + dy * dy)
                    let th = atan2(dy, dx)
                    let r = len * 1.4
                    let n = 17
                    let cx = (left.x + right.x) / 2
                    let cy = (left.y + right.y) / 2
                    let formatter = DateFormatter()
                    formatter.dateFormat = "ss.SSS"
                    let t = Double(formatter.string(from: Date())) ?? 0.0
                    for i in 0..<n {
                        let div = 10.0 // must be the divisor of 60
                        let dt = (fmod(t, div) / div) * (Double.pi * 2)
                        let th0 = Double.pi * 2 / Double(n) * Double(i) + dt
                        let bth = th0 + th
                        let r0 = r + abs(sin(th0)) * r * 0.3
                        let x1 = cx + cos(bth) * r0
                        let y1 = cy + sin(bth) * r0
                        let r2 = Float(r) * (0.2 + Float(i % 3) * 0.12)
                        g.setFillColor(COLOR.cgColor)
                        g.beginPath()
                        g.addArc(center: CGPoint(x: x1, y: y1), radius: CGFloat(r2), startAngle: CGFloat(0), endAngle: CGFloat(Double.pi * 2), clockwise: false)
                        g.fillPath()
                    }
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
            if CAMERA_FRONT {
                let image2 = image.flipHorizontal()
                saveImage(image: image2)
            } else {
                saveImage(image: image)
            }
            if let image = self.orgimage {
                if CAMERA_FRONT {
                    let image2 = image.flipHorizontal()
                    saveImage(image: image2)
                } else {
                    saveImage(image: image)
                }
            }
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
    // CoreML
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let config = MLModelConfiguration()
            let model = try VNCoreMLModel(for: MobileNet(configuration: config).model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    /// - Tag: PerformRequests
    func updateClassifications(for image: UIImage) {
        //print("Classifying...")
        guard let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)) else {
            return
        }
        
        let img = image.cropCenter(w: image.cgImage!.width / 2, h: image.cgImage!.height / 2)
        
        guard let ciImage = CIImage(image: img) else {
            fatalError("Unable to create \(CIImage.self) from \(image).")
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                if error != nil {
                    //print("Unable to classify image. \(error!.localizedDescription)")
                } else {
                    //print("Unable to classify image.")
                }
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
        
            if classifications.isEmpty {
                //print("Nothing recognized.")
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(1) // how many get?
                let descriptions = topClassifications.map { classification in
                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
                    return String(format: "   %@ (%.2f)", self.en2ja(s: classification.identifier), classification.confidence)
                }
//                print("Classification:\n" + descriptions.joined(separator: "\n"))
                let s = descriptions.joined(separator: "\n")
                //let astr = NSAttributedString(string: s, attributes: [ .foregroundColor: UIColor.white, .strokeColor: UIColor.black, .strokeWidth: -3 ])
                let shadow = NSShadow()
                //shadow.shadowOffset = CGSize(width: 5, height: 5)
                shadow.shadowBlurRadius = 5
                shadow.shadowColor = UIColor.black
                let astr = NSAttributedString(string: s, attributes: [ .foregroundColor: UIColor.white, .shadow: shadow ])
                self.classficationLabel1.attributedText = astr
                self.classficationLabel2.attributedText = astr
            }
        }
    }
    let MOBILENET_EN2JA = [
    "tench, Tinca tinca": "テンチ",
    "goldfish, Carassius auratus": "金魚",
    "great white shark, white shark, man-eater, man-eating shark, Carcharodon carcharias": "ホオジロザメ",
    "tiger shark, Galeocerdo cuvieri": "イタチザメ",
    "hammerhead, hammerhead shark": "ハンマー",
    "electric ray, crampfish, numbfish, torpedo": "電気線",
    "stingray": "えい",
    "cock": "コック",
    "hen": "編",
    "ostrich, Struthio camelus": "ダチョウ",
    "brambling, Fringilla montifringilla": "アトリ",
    "goldfinch, Carduelis carduelis": "ゴールドフィンチ",
    "house finch, linnet, Carpodacus mexicanus": "家フィンチ",
    "junco, snowbird": "スノーバード",
    "indigo bunting, indigo finch, indigo bird, Passerina cyanea": "ルリノジコ",
    "robin, American robin, Turdus migratorius": "ロビン",
    "bulbul": "ヒヨドリ",
    "jay": "かけす",
    "magpie": "かささぎ",
    "chickadee": "四十雀",
    "water ouzel, dipper": "ひしゃく",
    "kite": "カイト",
    "bald eagle, American eagle, Haliaeetus leucocephalus": "白頭ワシ",
    "vulture": "禿鷹",
    "great grey owl, great gray owl, Strix nebulosa": "カラフトフクロウ",
    "European fire salamander, Salamandra salamandra": "欧州のファイアサラマンダー",
    "common newt, Triturus vulgaris": "共通イモリ",
    "eft": "EFT",
    "spotted salamander, Ambystoma maculatum": "サンショウウオを発見し",
    "axolotl, mud puppy, Ambystoma mexicanum": "アホロートル",
    "bullfrog, Rana catesbeiana": "ウシガエル",
    "tree frog, tree-frog": "木のカエル",
    "tailed frog, bell toad, ribbed toad, tailed toad, Ascaphus trui": "尾カエル",
    "loggerhead, loggerhead turtle, Caretta caretta": "アカウミガメ",
    "leatherback turtle, leatherback, leathery turtle, Dermochelys coriacea": "オサガメ",
    "mud turtle": "鼈",
    "terrapin": "スッポン",
    "box turtle, box tortoise": "ボックスのカメ",
    "banded gecko": "バンドヤモリ",
    "common iguana, iguana, Iguana iguana": "共通イグアナ",
    "American chameleon, anole, Anolis carolinensis": "アメリカンカメレオン",
    "whiptail, whiptail lizard": "です：whiptailトカゲ",
    "agama": "アガマ",
    "frilled lizard, Chlamydosaurus kingi": "フリルのついたトカゲ",
    "alligator lizard": "ワニトカゲ",
    "Gila monster, Heloderma suspectum": "アメリカドクトカゲ",
    "green lizard, Lacerta viridis": "緑のトカゲ",
    "African chameleon, Chamaeleo chamaeleon": "アフリカのカメレオン",
    "Komodo dragon, Komodo lizard, dragon lizard, giant lizard, Varanus komodoensis": "コモドドラゴン",
    "African crocodile, Nile crocodile, Crocodylus niloticus": "アフリカワニ",
    "American alligator, Alligator mississipiensis": "アメリカワニ",
    "triceratops": "トリケラトプス",
    "thunder snake, worm snake, Carphophis amoenus": "雷ヘビ",
    "ringneck snake, ring-necked snake, ring snake": "リング首ヘビ",
    "hognose snake, puff adder, sand viper": "パフ加算器",
    "green snake, grass snake": "緑のヘビ",
    "king snake, kingsnake": "キングヘビ",
    "garter snake, grass snake": "ガーターヘビ",
    "water snake": "水ヘビ",
    "vine snake": "つるヘビ",
    "night snake, Hypsiglena torquata": "夜のヘビ",
    "boa constrictor, Constrictor constrictor": "ボアコンストリクター",
    "rock python, rock snake, Python sebae": "岩ヘビ",
    "Indian cobra, Naja naja": "インドコブラ",
    "green mamba": "グリーンマンバ",
    "sea snake": "海ヘビ",
    "horned viper, cerastes, sand viper, horned asp, Cerastes cornutus": "角状の毒蛇",
    "diamondback, diamondback rattlesnake, Crotalus adamanteus": "ダイヤ",
    "sidewinder, horned rattlesnake, Crotalus cerastes": "サイドワインダー",
    "trilobite": "三葉虫",
    "harvestman, daddy longlegs, Phalangium opilio": "Phalangiumズワイガニ",
    "scorpion": "蠍",
    "black and gold garden spider, Argiope aurantia": "黒と金の庭のクモ",
    "barn spider, Araneus cavaticus": "納屋スパイダー",
    "garden spider, Aranea diademata": "庭のクモ",
    "black widow, Latrodectus mactans": "黒の未亡人",
    "tarantula": "タランチュラ",
    "wolf spider, hunting spider": "コモリグモ",
    "tick": "ダニ",
    "centipede": "百足",
    "black grouse": "クロライチョウ",
    "ptarmigan": "雷鳥",
    "ruffed grouse, partridge, Bonasa umbellus": "エリマキライチョウ",
    "prairie chicken, prairie grouse, prairie fowl": "草原鶏",
    "peacock": "孔雀",
    "quail": "ウズラ",
    "partridge": "鷓鴣",
    "African grey, African gray, Psittacus erithacus": "アフリカのグレー",
    "macaw": "こんごういんこ",
    "sulphur-crested cockatoo, Kakatoe galerita, Cacatua galerita": "キバタン",
    "lorikeet": "lorikeet",
    "coucal": "バンケン属",
    "bee eater": "蜂食べる人",
    "hornbill": "サイチョウ",
    "hummingbird": "ハチドリ",
    "jacamar": "jacamar",
    "toucan": "大嘴鳥",
    "drake": "ドレイク",
    "red-breasted merganser, Mergus serrator": "ウミアイサ",
    "goose": "ガチョウ",
    "black swan, Cygnus atratus": "黒い白鳥",
    "tusker": "タスカー",
    "echidna, spiny anteater, anteater": "ハリモグラ",
    "platypus, duckbill, duckbilled platypus, duck-billed platypus, Ornithorhynchus anatinus": "カモノハシ",
    "wallaby, brush kangaroo": "ワラビー",
    "koala, koala bear, kangaroo bear, native bear, Phascolarctos cinereus": "コアラ",
    "wombat": "ウォンバット",
    "jellyfish": "クラゲ",
    "sea anemone, anemone": "イソギンチャク",
    "brain coral": "脳珊瑚",
    "flatworm, platyhelminth": "扁形動物",
    "nematode, nematode worm, roundworm": "線虫",
    "conch": "法螺貝",
    "snail": "巻き貝",
    "slug": "ナメクジ",
    "sea slug, nudibranch": "ウミウシ",
    "chiton, coat-of-mail shell, sea cradle, polyplacophore": "キトン",
    "chambered nautilus, pearly nautilus, nautilus": "チェンバードノーチラス",
    "Dungeness crab, Cancer magister": "ダンジネスカニ",
    "rock crab, Cancer irroratus": "岩カニ",
    "fiddler crab": "シオマネキ",
    "king crab, Alaska crab, Alaskan king crab, Alaska king crab, Paralithodes camtschatica": "タラバガニ",
    "American lobster, Northern lobster, Maine lobster, Homarus americanus": "アメリカンロブスター",
    "spiny lobster, langouste, rock lobster, crawfish, crayfish, sea crawfish": "イセエビ",
    "crayfish, crawfish, crawdad, crawdaddy": "ザリガニ",
    "hermit crab": "ヤドカリ",
    "isopod": "isopod",
    "white stork, Ciconia ciconia": "白コウノトリ",
    "black stork, Ciconia nigra": "ナベコウ",
    "spoonbill": "ヘラサギ",
    "flamingo": "フラミンゴ",
    "little blue heron, Egretta caerulea": "スミレサギ",
    "American egret, great white heron, Egretta albus": "アメリカの白鷺",
    "bittern": "にがり",
    "crane": "クレーン",
    "limpkin, Aramus pictus": "ツルモドキ科の鳥",
    "European gallinule, Porphyrio porphyrio": "Porphyrio porphyrio",
    "American coot, marsh hen, mud hen, water hen, Fulica americana": "アメリカオオバン",
    "bustard": "ノガン科",
    "ruddy turnstone, Arenaria interpres": "キョウジョシギ",
    "red-backed sandpiper, dunlin, Erolia alpina": "赤担保サンドパイパー",
    "redshank, Tringa totanus": "Tringa totanus",
    "dowitcher": "dowitcher",
    "oystercatcher, oyster catcher": "ミヤコドリ属",
    "pelican": "ペリカン",
    "king penguin, Aptenodytes patagonica": "キングペンギン",
    "albatross, mollymawk": "アホウドリ",
    "grey whale, gray whale, devilfish, Eschrichtius gibbosus, Eschrichtius robustus": "コククジラ",
    "killer whale, killer, orca, grampus, sea wolf, Orcinus orca": "シャチ",
    "dugong, Dugong dugon": "ジュゴン",
    "sea lion": "アシカ",
    "Chihuahua": "チワワ",
    "Japanese spaniel": "狆",
    "Maltese dog, Maltese terrier, Maltese": "マルチーズ犬",
    "Pekinese, Pekingese, Peke": "狆",
    "Shih-Tzu": "シーズー",
    "Blenheim spaniel": "ブレナムスパニエル",
    "papillon": "パピヨン",
    "toy terrier": "おもちゃテリア",
    "Rhodesian ridgeback": "ローデシアン・リッジバック",
    "Afghan hound, Afghan": "アフガンハウンド",
    "basset, basset hound": "バセット",
    "beagle": "ビーグル",
    "bloodhound, sleuthhound": "ブラッドハウンド",
    "bluetick": "bluetick",
    "black-and-tan coonhound": "日焼けがblack-and-coonhound",
    "Walker hound, Walker foxhound": "ウォーカーハウンド",
    "English foxhound": "英語フォックスハウンド",
    "redbone": "redbone",
    "borzoi, Russian wolfhound": "ボルゾイ",
    "Irish wolfhound": "アイリッシュウルフハウンド",
    "Italian greyhound": "イタリアグレイハウンド",
    "whippet": "ウィペット",
    "Ibizan hound, Ibizan Podenco": "イビサハウンド",
    "Norwegian elkhound, elkhound": "ノルウェジアン・エルクハウンド・グレー",
    "otterhound, otter hound": "オッターハウンド",
    "Saluki, gazelle hound": "サルーキ",
    "Scottish deerhound, deerhound": "スコティッシュ・ディアハウンド",
    "Weimaraner": "ワイマラナー",
    "Staffordshire bullterrier, Staffordshire bull terrier": "スタッフォードシャーブル・テリア",
    "American Staffordshire terrier, Staffordshire terrier, American pit bull terrier, pit bull terrier": "アメリカン・スタッフォードシャーテリア",
    "Bedlington terrier": "ベドリントンテリア",
    "Border terrier": "ボーダーテリア",
    "Kerry blue terrier": "ケリーブルーテリア",
    "Irish terrier": "アイリッシュテリア",
    "Norfolk terrier": "ノーフォークテリア",
    "Norwich terrier": "ノーリッチ・テリア",
    "Yorkshire terrier": "ヨークシャーテリア",
    "wire-haired fox terrier": "ワイヤー髪のフォックス・テリア",
    "Lakeland terrier": "レイクランドテリア",
    "Sealyham terrier, Sealyham": "Sealyham",
    "Airedale, Airedale terrier": "エアデール",
    "cairn, cairn terrier": "ケルン",
    "Australian terrier": "オーストラリアテリア",
    "Dandie Dinmont, Dandie Dinmont terrier": "ダンディ・ディンモント・テリア",
    "Boston bull, Boston terrier": "ボストンブル",
    "miniature schnauzer": "ミニチュア・シュナウザー",
    "giant schnauzer": "ジャイアントシュナウザー",
    "standard schnauzer": "スタンダード・シュナウザー",
    "Scotch terrier, Scottish terrier, Scottie": "スコッチテリア",
    "Tibetan terrier, chrysanthemum dog": "チベットテリア",
    "silky terrier, Sydney silky": "シルキーテリア",
    "soft-coated wheaten terrier": "ソフトコーテッド・ウィートン・テリア",
    "West Highland white terrier": "ウエスト・ハイランド・ホワイト・テリア",
    "Lhasa, Lhasa apso": "ラサ",
    "flat-coated retriever": "フラットコーテッド・レトリーバー",
    "curly-coated retriever": "カーリーコーティングされたレトリバー",
    "golden retriever": "ゴールデンレトリバー",
    "Labrador retriever": "ラブラドール・レトリバー",
    "Chesapeake Bay retriever": "チェサピーク湾レトリーバー",
    "German short-haired pointer": "ドイツの短毛のポインタ",
    "vizsla, Hungarian pointer": "ショートヘアード・ハンガリアン・ビズラ",
    "English setter": "英語セッター",
    "Irish setter, red setter": "アイリッシュセッター",
    "Gordon setter": "ゴードンセッター",
    "Brittany spaniel": "ブルターニュスパニエル",
    "clumber, clumber spaniel": "クランバー",
    "English springer, English springer spaniel": "英語スプリンガー",
    "Welsh springer spaniel": "ウェルシュスプリンガースパニエル",
    "cocker spaniel, English cocker spaniel, cocker": "コッカースパニエル",
    "Sussex spaniel": "サセックススパニエル",
    "Irish water spaniel": "アイルランドのウォータースパニエル",
    "kuvasz": "クーバース",
    "schipperke": "スキッパーキ",
    "groenendael": "ベルジアン・シェパード・ドッグ・グローネンダール",
    "malinois": "マリノア",
    "briard": "ブリアード",
    "kelpie": "ケルピー",
    "komondor": "コモンドール",
    "Old English sheepdog, bobtail": "オールド・イングリッシュ・シープドッグ",
    "Shetland sheepdog, Shetland sheep dog, Shetland": "シェットランドシープドッグ",
    "collie": "コリー",
    "Border collie": "ボーダーコリー",
    "Bouvier des Flandres, Bouviers des Flandres": "ブーヴィエデフランドル",
    "Rottweiler": "ロットワイラー",
    "German shepherd, German shepherd dog, German police dog, alsatian": "シェパード",
    "Doberman, Doberman pinscher": "ドーベルマン",
    "miniature pinscher": "ミニチュアピンシャー",
    "Greater Swiss Mountain dog": "グレーター・スイス・マウンテン・ドッグ",
    "Bernese mountain dog": "バーニーズマウンテンドッグ",
    "Appenzeller": "アッペンツェル",
    "EntleBucher": "EntleBucher",
    "boxer": "ボクサー",
    "bull mastiff": "ブルマスティフ",
    "Tibetan mastiff": "チベタン・マスティフ",
    "French bulldog": "フレンチ・ブルドッグ",
    "Great Dane": "グレートデーン",
    "Saint Bernard, St Bernard": "セントバーナード",
    "Eskimo dog, husky": "エスキモー犬",
    "malamute, malemute, Alaskan malamute": "マラミュート",
    "Siberian husky": "シベリアンハスキー",
    "dalmatian, coach dog, carriage dog": "ダルメシアン",
    "affenpinscher, monkey pinscher, monkey dog": "アーフェンピンシャー",
    "basenji": "バセンジー",
    "pug, pug-dog": "パグ",
    "Leonberg": "レオンバーグ",
    "Newfoundland, Newfoundland dog": "ニューファンドランド",
    "Great Pyrenees": "グレートピレニーズ",
    "Samoyed, Samoyede": "サモエド",
    "Pomeranian": "スピッツ",
    "chow, chow chow": "餌",
    "keeshond": "キースホンド",
    "Brabancon griffon": "Brabanconのグリフォン",
    "Pembroke, Pembroke Welsh corgi": "ペンブローク",
    "Cardigan, Cardigan Welsh corgi": "カーディガン",
    "toy poodle": "トイプードル",
    "miniature poodle": "ミニチュアプードル",
    "standard poodle": "標準プードル",
    "Mexican hairless": "ヘアレスメキシコ",
    "timber wolf, grey wolf, gray wolf, Canis lupus": "木材オオカミ",
    "white wolf, Arctic wolf, Canis lupus tundrarum": "白いオオカミ",
    "red wolf, maned wolf, Canis rufus, Canis niger": "レッドウルフ",
    "coyote, prairie wolf, brush wolf, Canis latrans": "コヨーテ",
    "dingo, warrigal, warragal, Canis dingo": "ディンゴ",
    "dhole, Cuon alpinus": "ドール",
    "African hunting dog, hyena dog, Cape hunting dog, Lycaon pictus": "アフリカの狩猟犬",
    "hyena, hyaena": "ハイエナ",
    "red fox, Vulpes vulpes": "赤キツネ",
    "kit fox, Vulpes macrotis": "キットギツネ",
    "Arctic fox, white fox, Alopex lagopus": "北極キツネ",
    "grey fox, gray fox, Urocyon cinereoargenteus": "灰色のキツネ",
    "tabby, tabby cat": "トラ",
    "tiger cat": "虎猫",
    "Persian cat": "ペルシャ猫",
    "Siamese cat, Siamese": "シャム猫",
    "Egyptian cat": "エジプトの猫",
    "cougar, puma, catamount, mountain lion, painter, panther, Felis concolor": "クーガー",
    "lynx, catamount": "オオヤマネコ",
    "leopard, Panthera pardus": "ヒョウ",
    "snow leopard, ounce, Panthera uncia": "ユキヒョウ",
    "jaguar, panther, Panthera onca, Felis onca": "ジャガー",
    "lion, king of beasts, Panthera leo": "ライオン",
    "tiger, Panthera tigris": "タイガー",
    "cheetah, chetah, Acinonyx jubatus": "チーター",
    "brown bear, bruin, Ursus arctos": "ヒグマ",
    "American black bear, black bear, Ursus americanus, Euarctos americanus": "アメリカグマ",
    "ice bear, polar bear, Ursus Maritimus, Thalarctos maritimus": "氷のクマ",
    "sloth bear, Melursus ursinus, Ursus ursinus": "ナマケグマ",
    "mongoose": "マングース",
    "meerkat, mierkat": "ミーアキャット",
    "tiger beetle": "ハンミョウ科",
    "ladybug, ladybeetle, lady beetle, ladybird, ladybird beetle": "てんとう虫",
    "ground beetle, carabid beetle": "グランドカブトムシ",
    "long-horned beetle, longicorn, longicorn beetle": "長い角状のカブトムシ",
    "leaf beetle, chrysomelid": "ハムシ",
    "dung beetle": "フンコロガシ",
    "rhinoceros beetle": "サイハムシ",
    "weevil": "ゾウムシ",
    "fly": "飛ぶ",
    "bee": "蜂",
    "ant, emmet, pismire": "アリ",
    "grasshopper, hopper": "バッタ",
    "cricket": "クリケット",
    "walking stick, walkingstick, stick insect": "スティック",
    "cockroach, roach": "ゴキブリ",
    "mantis, mantid": "カマキリ",
    "cicada, cicala": "蝉",
    "leafhopper": "ヨコバイ",
    "lacewing, lacewing fly": "クサカゲロウ",
    "dragonfly, darning needle, devil''s darning needle, sewing needle, snake feeder, snake doctor, mosquito hawk, skeeter hawk": "トンボ",
    "damselfly": "イトトンボ",
    "admiral": "提督",
    "ringlet, ringlet butterfly": "リングレット",
    "monarch, monarch butterfly, milkweed butterfly, Danaus plexippus": "君主",
    "cabbage butterfly": "モンシロチョウ",
    "sulphur butterfly, sulfur butterfly": "硫黄蝶",
    "lycaenid, lycaenid butterfly": "lycaenid蝶",
    "starfish, sea star": "ヒトデ",
    "sea urchin": "うに",
    "sea cucumber, holothurian": "ナマコ",
    "wood rabbit, cottontail, cottontail rabbit": "木製のウサギ",
    "hare": "野ウサギ",
    "Angora, Angora rabbit": "アンゴラ",
    "hamster": "ハムスター",
    "porcupine, hedgehog": "ヤマアラシ",
    "fox squirrel, eastern fox squirrel, Sciurus niger": "キツネ",
    "marmot": "モルモット",
    "beaver": "ビーバー",
    "guinea pig, Cavia cobaya": "モルモット",
    "sorrel": "栗色",
    "zebra": "シマウマ",
    "hog, pig, grunter, squealer, Sus scrofa": "豚",
    "wild boar, boar, Sus scrofa": "イノシシ",
    "warthog": "イボイノシシ",
    "hippopotamus, hippo, river horse, Hippopotamus amphibius": "カバ",
    "ox": "牛",
    "water buffalo, water ox, Asiatic buffalo, Bubalus bubalis": "水牛",
    "bison": "バイソン",
    "ram, tup": "ラム",
    "bighorn, bighorn sheep, cimarron, Rocky Mountain bighorn, Rocky Mountain sheep, Ovis canadensis": "ビッグホーン",
    "ibex, Capra ibex": "アイベックス",
    "hartebeest": "ハーテビースト",
    "impala, Aepyceros melampus": "インパラ",
    "gazelle": "ガゼル",
    "Arabian camel, dromedary, Camelus dromedarius": "アラビアラクダ",
    "llama": "ラマ",
    "weasel": "イタチ",
    "mink": "ミンク",
    "polecat, fitch, foulmart, foumart, Mustela putorius": "フィッチ",
    "black-footed ferret, ferret, Mustela nigripes": "黒足のフェレット",
    "otter": "獺",
    "skunk, polecat, wood pussy": "スカンク",
    "badger": "狸",
    "armadillo": "アルマジロ",
    "three-toed sloth, ai, Bradypus tridactylus": "3ユビナマケモノ",
    "orangutan, orang, orangutang, Pongo pygmaeus": "オランウータン",
    "gorilla, Gorilla gorilla": "ゴリラ",
    "chimpanzee, chimp, Pan troglodytes": "チンパンジー",
    "gibbon, Hylobates lar": "テナガザル",
    "siamang, Hylobates syndactylus, Symphalangus syndactylus": "フクロテナガザル",
    "guenon, guenon monkey": "guenon猿",
    "patas, hussar monkey, Erythrocebus patas": "パタス",
    "baboon": "ヒヒ",
    "macaque": "マカク",
    "langur": "ラングール",
    "colobus, colobus monkey": "コロブス",
    "proboscis monkey, Nasalis larvatus": "テングザル",
    "marmoset": "マーモセット",
    "capuchin, ringtail, Cebus capucinus": "オマキザル",
    "howler monkey, howler": "ホエザル",
    "titi, titi monkey": "ティティ",
    "spider monkey, Ateles geoffroyi": "クモザル",
    "squirrel monkey, Saimiri sciureus": "リスザル",
    "Madagascar cat, ring-tailed lemur, Lemur catta": "マダガスカル猫",
    "indri, indris, Indri indri, Indri brevicaudatus": "インドリ",
    "Indian elephant, Elephas maximus": "インド象",
    "African elephant, Loxodonta africana": "アフリカゾウ",
    "lesser panda, red panda, panda, bear cat, cat bear, Ailurus fulgens": "レッサーパンダ",
    "giant panda, panda, panda bear, coon bear, Ailuropoda melanoleuca": "ジャイアントパンダ",
    "barracouta, snoek": "バラクータ",
    "eel": "ウナギ",
    "coho, cohoe, coho salmon, blue jack, silver salmon, Oncorhynchus kisutch": "ギンザケ",
    "rock beauty, Holocanthus tricolor": "岩の美しさ",
    "anemone fish": "クマノミ",
    "sturgeon": "チョウザメ",
    "gar, garfish, garpike, billfish, Lepisosteus osseus": "ガー",
    "lionfish": "ミノカサゴ",
    "puffer, pufferfish, blowfish, globefish": "フグ",
    "abacus": "ソロバン",
    "abaya": "アバヤ",
    "academic gown, academic robe, judge''s robe": "アカデミックガウン",
    "accordion, piano accordion, squeeze box": "アコーディオン",
    "acoustic guitar": "アコースティックギター",
    "aircraft carrier, carrier, flattop, attack aircraft carrier": "空母",
    "airliner": "旅客機",
    "airship, dirigible": "飛行船",
    "altar": "祭壇",
    "ambulance": "救急車",
    "amphibian, amphibious vehicle": "両生類",
    "analog clock": "アナログ時計",
    "apiary, bee house": "養蜂場",
    "apron": "エプロン",
    "ashcan, trash can, garbage can, wastebin, ash bin, ash-bin, ashbin, dustbin, trash barrel, trash bin": "アッシュカン",
    "assault rifle, assault gun": "アサルトライフル",
    "backpack, back pack, knapsack, packsack, rucksack, haversack": "バックパック",
    "bakery, bakeshop, bakehouse": "ベーカリー",
    "balance beam, beam": "バランスビーム",
    "balloon": "バルーン",
    "ballpoint, ballpoint pen, ballpen, Biro": "ボールペン",
    "Band Aid": "バンドエイド",
    "banjo": "バンジョー",
    "bannister, banister, balustrade, balusters, handrail": "バニスター",
    "barbell": "バーベル",
    "barber chair": "バーバーチェア",
    "barbershop": "理髪店",
    "barn": "納屋",
    "barometer": "バロメーター",
    "barrel, cask": "樽",
    "barrow, garden cart, lawn cart, wheelbarrow": "手押し車",
    "baseball": "野球",
    "basketball": "バスケットボール",
    "bassinet": "バシネット",
    "bassoon": "ファゴット",
    "bathing cap, swimming cap": "入浴キャップ",
    "bath towel": "バスタオル",
    "bathtub, bathing tub, bath, tub": "バスタブ",
    "beach wagon, station wagon, wagon, estate car, beach waggon, station waggon, waggon": "ビーチワゴン",
    "beacon, lighthouse, beacon light, pharos": "ビーコン",
    "beaker": "ビーカー",
    "bearskin, busby, shako": "ベアスキン",
    "beer bottle": "ビール瓶",
    "beer glass": "ビールグラス",
    "bell cote, bell cot": "ベルコート",
    "bib": "よだれかけ",
    "bicycle-built-for-two, tandem bicycle, tandem": "自転車の内蔵用-2",
    "bikini, two-piece": "ビキニ",
    "binder, ring-binder": "バインダー",
    "binoculars, field glasses, opera glasses": "双眼鏡",
    "birdhouse": "巣箱",
    "boathouse": "艇庫",
    "bobsled, bobsleigh, bob": "ボブスレー",
    "bolo tie, bolo, bola tie, bola": "ポーラー・タイ",
    "bonnet, poke bonnet": "ボンネット",
    "bookcase": "本棚",
    "bookshop, bookstore, bookstall": "本屋",
    "bottlecap": "瓶のキャップ",
    "bow": "弓",
    "bow tie, bow-tie, bowtie": "ネクタイ",
    "brass, memorial tablet, plaque": "真鍮",
    "brassiere, bra, bandeau": "ブラジャー",
    "breakwater, groin, groyne, mole, bulwark, seawall, jetty": "防波堤",
    "breastplate, aegis, egis": "胸当て",
    "broom": "帚",
    "bucket, pail": "バケツ",
    "buckle": "バックル",
    "bulletproof vest": "防弾チョッキ",
    "bullet train, bullet": "新幹線",
    "butcher shop, meat market": "精肉店",
    "cab, hack, taxi, taxicab": "タクシー",
    "caldron, cauldron": "大釜",
    "candle, taper, wax light": "ろうそく",
    "cannon": "大砲",
    "canoe": "カヌー",
    "can opener, tin opener": "",
    "cardigan": "カーディガン",
    "car mirror": "車のミラー",
    "carousel, carrousel, merry-go-round, roundabout, whirligig": "カルーセル",
    "carpenter''s kit, tool kit": "大工のキット",
    "carton": "カートン",
    "car wheel": "車のホイール",
    "cash machine, cash dispenser, automated teller machine, automatic teller machine, automated teller, automatic teller, ATM": "現金自動預け払い機",
    "cassette": "カセット",
    "cassette player": "カセット・プレーヤー",
    "castle": "城",
    "catamaran": "カタマラン",
    "CD player": "CDプレーヤー",
    "cello, violoncello": "チェロ",
    "cellular telephone, cellular phone, cellphone, cell, mobile phone": "携帯電話",
    "chain": "鎖",
    "chainlink fence": "金網フェンス",
    "chain mail, ring mail, mail, chain armor, chain armour, ring armor, ring armour": "チェーンメール",
    "chain saw, chainsaw": "チェーンソー",
    "chest": "胸",
    "chiffonier, commode": "便器",
    "chime, bell, gong": "チャイム",
    "china cabinet, china closet": "中国のキャビネット",
    "Christmas stocking": "クリスマスの靴下",
    "church, church building": "教会",
    "cinema, movie theater, movie theatre, movie house, picture palace": "映画館",
    "cleaver, meat cleaver, chopper": "包丁",
    "cliff dwelling": "崖の住居",
    "cloak": "クローク",
    "clog, geta, patten, sabot": "詰まり",
    "cocktail shaker": "カクテルシェーカー",
    "coffee mug": "コーヒーマグカップ",
    "coffeepot": "コーヒーポット",
    "coil, spiral, volute, whorl, helix": "コイル",
    "combination lock": "組み合わせ錠",
    "computer keyboard, keypad": "コンピュータのキーボード",
    "confectionery, confectionary, candy store": "菓子",
    "container ship, containership, container vessel": "コンテナ船",
    "convertible": "コンバーチブル",
    "corkscrew, bottle screw": "コルク抜き",
    "cornet, horn, trumpet, trump": "コルネット",
    "cowboy boot": "カウボーイブーツ",
    "cowboy hat, ten-gallon hat": "カウボーイハット",
    "cradle": "発祥地",
    "crane_": "クレーン", // duplicated
    "crash helmet": "ヘルメット",
    "crate": "クレート",
    "crib, cot": "ベビーベッド",
    "Crock Pot": "廃人ポット",
    "croquet ball": "クロケットボール",
    "crutch": "松葉杖",
    "cuirass": "cuirass",
    "dam, dike, dyke": "ダム",
    "desk": "机",
    "desktop computer": "デスクトップコンピューター",
    "dial telephone, dial phone": "電話をダイヤルし",
    "diaper, nappy, napkin": "おむつ",
    "digital clock": "デジタル時計",
    "digital watch": "デジタル腕時計",
    "dining table, board": "ダイニングテーブル",
    "dishrag, dishcloth": "布巾",
    "dishwasher, dish washer, dishwashing machine": "食器洗い機",
    "disk brake, disc brake": "ディスクブレーキ",
    "dock, dockage, docking facility": "ドック",
    "dogsled, dog sled, dog sleigh": "犬ぞり",
    "dome": "ドーム",
    "doormat, welcome mat": "玄関マット",
    "drilling platform, offshore rig": "掘削プラットフォーム",
    "drum, membranophone, tympan": "ドラム",
    "drumstick": "バチ",
    "dumbbell": "ダンベル",
    "Dutch oven": "ダッチオーブン",
    "electric fan, blower": "電動ファン",
    "electric guitar": "エレキギター",
    "electric locomotive": "電気機関車",
    "entertainment center": "エンターテイメントセンター",
    "envelope": "封筒",
    "espresso maker": "エスプレッソメーカー",
    "face powder": "フェースパウダー",
    "feather boa, boa": "羽ボア",
    "file, file cabinet, filing cabinet": "ファイル",
    "fireboat": "消防艇",
    "fire engine, fire truck": "消防車",
    "fire screen, fireguard": "火災画面",
    "flagpole, flagstaff": "旗竿",
    "flute, transverse flute": "フルート",
    "folding chair": "折り畳みいす",
    "football helmet": "フットボールヘルメット",
    "forklift": "フォークリフト",
    "fountain": "噴水",
    "fountain pen": "万年筆",
    "four-poster": "四柱",
    "freight car": "貨車",
    "French horn, horn": "フレンチホルン",
    "frying pan, frypan, skillet": "フライパン",
    "fur coat": "毛皮のコート",
    "garbage truck, dustcart": "ごみ収集車",
    "gasmask, respirator, gas helmet": "人工呼吸器",
    "gas pump, gasoline pump, petrol pump, island dispenser": "ガスポンプ",
    "goblet": "ゴブレット",
    "go-kart": "ゴーカート",
    "golf ball": "ゴルフボール",
    "golfcart, golf cart": "ゴルフカート",
    "gondola": "ゴンドラ",
    "gong, tam-tam": "ゴング",
    "gown": "ガウン",
    "grand piano, grand": "グランドピアノ",
    "greenhouse, nursery, glasshouse": "温室",
    "grille, radiator grille": "グリル",
    "grocery store, grocery, food market, market": "食料品店",
    "guillotine": "ギロチン",
    "hair slide": "髪のスライド",
    "hair spray": "ヘアスプレー",
    "half track": "半トラック",
    "hammer": "ハンマー",
    "hamper": "妨げます",
    "hand blower, blow dryer, blow drier, hair dryer, hair drier": "手ブロワー",
    "hand-held computer, hand-held microcomputer": "手持ちコンピュータ",
    "handkerchief, hankie, hanky, hankey": "ハンカチ",
    "hard disc, hard disk, fixed disk": "ハードディスク",
    "harmonica, mouth organ, harp, mouth harp": "ハーモニカ",
    "harp": "ハープ",
    "harvester, reaper": "ハーベスタ",
    "hatchet": "斧",
    "holster": "ホルスター",
    "home theater, home theatre": "ホームシアター",
    "honeycomb": "蜂の巣",
    "hook, claw": "フック",
    "hoopskirt, crinoline": "クリノリン",
    "horizontal bar, high bar": "水平バー",
    "horse cart, horse-cart": "馬車",
    "hourglass": "砂時計",
    "iPod": "iPodの",
    "iron, smoothing iron": "鉄",
    "jack-o''-lantern": "ジャックの -  o ' - ランタン",
    "jean, blue jean, denim": "ジーンズ",
    "jeep, landrover": "ジープ",
    "jersey, T-shirt, tee shirt": "ジャージ",
    "jigsaw puzzle": "ジグソーパズル",
    "jinrikisha, ricksha, rickshaw": "人力車",
    "joystick": "ジョイスティック",
    "kimono": "着物",
    "knee pad": "膝パッド",
    "knot": "結び目",
    "lab coat, laboratory coat": "白衣",
    "ladle": "ひしゃく",
    "lampshade, lamp shade": "ランプシェード",
    "laptop, laptop computer": "ノートパソコン",
    "lawn mower, mower": "芝刈り機",
    "lens cap, lens cover": "レンズキャップ",
    "letter opener, paper knife, paperknife": "レターオープナー",
    "library": "図書館",
    "lifeboat": "救命ボート",
    "lighter, light, igniter, ignitor": "軽い",
    "limousine, limo": "リムジン",
    "liner, ocean liner": "ライナー",
    "lipstick, lip rouge": "口紅",
    "Loafer": "ルンペン",
    "lotion": "ローション",
    "loudspeaker, speaker, speaker unit, loudspeaker system, speaker system": "拡声器",
    "loupe, jeweler''s loupe": "ルーペ",
    "lumbermill, sawmill": "製材所",
    "magnetic compass": "方位磁針",
    "mailbag, postbag": "メールバッグ",
    "mailbox, letter box": "メールボックス",
    "maillot": "マイヨ",
    "maillot, tank suit": "マイヨ",
    "manhole cover": "マンホールの蓋",
    "maraca": "マラカス",
    "marimba, xylophone": "マリンバ",
    "mask": "マスク",
    "matchstick": "マッチ棒",
    "maypole": "メイポール",
    "maze, labyrinth": "迷路",
    "measuring cup": "計量カップ",
    "medicine chest, medicine cabinet": "薬箱",
    "megalith, megalithic structure": "巨石",
    "microphone, mike": "マイク",
    "microwave, microwave oven": "電子レンジ",
    "military uniform": "軍服",
    "milk can": "ミルク缶",
    "minibus": "ミニバス",
    "miniskirt, mini": "ミニスカート",
    "minivan": "ミニバン",
    "missile": "ミサイル",
    "mitten": "ミトン",
    "mixing bowl": "ミキシングボウル",
    "mobile home, manufactured home": "モバイルホーム",
    "Model T": "モデルT",
    "modem": "モデム",
    "monastery": "修道院",
    "monitor": "モニター",
    "moped": "モペット",
    "mortar": "モルタル",
    "mortarboard": "モルタルボード",
    "mosque": "モスク",
    "mosquito net": "蚊帳",
    "motor scooter, scooter": "スクーター",
    "mountain bike, all-terrain bike, off-roader": "マウンテンバイク",
    "mountain tent": "山のテント",
    "mouse, computer mouse": "マウス",
    "mousetrap": "ネズミ捕り",
    "moving van": "移動バン",
    "muzzle": "銃口",
    "nail": "爪",
    "neck brace": "ネックブレース",
    "necklace": "ネックレス",
    "nipple": "乳首",
    "notebook, notebook computer": "ノートブック",
    "obelisk": "オベリスク",
    "oboe, hautboy, hautbois": "オーボエ",
    "ocarina, sweet potato": "オカリナ",
    "odometer, hodometer, mileometer, milometer": "オドメーター",
    "oil filter": "オイルフィルター",
    "organ, pipe organ": "オルガン",
    "oscilloscope, scope, cathode-ray oscilloscope, CRO": "オシロスコープ",
    "overskirt": "オーバースカート",
    "oxcart": "牛車",
    "oxygen mask": "酸素マスク",
    "packet": "パケット",
    "paddle, boat paddle": "パドル",
    "paddlewheel, paddle wheel": "パドルホイール",
    "padlock": "南京錠",
    "paintbrush": "絵筆",
    "pajama, pyjama, pj''s, jammies": "パジャマ",
    "palace": "宮殿",
    "panpipe, pandean pipe, syrinx": "鳴管",
    "paper towel": "ペーパータオル",
    "parachute, chute": "パラシュート",
    "parallel bars, bars": "平行棒",
    "park bench": "公園のベンチ",
    "parking meter": "パーキングメーター",
    "passenger car, coach, carriage": "乗用車",
    "patio, terrace": "パティオ",
    "pay-phone, pay-station": "有料電話",
    "pedestal, plinth, footstall": "台座",
    "pencil box, pencil case": "鉛筆ボックス",
    "pencil sharpener": "鉛筆削り",
    "perfume, essence": "香水",
    "Petri dish": "ペトリ皿",
    "photocopier": "コピー機",
    "pick, plectrum, plectron": "バチ",
    "pickelhaube": "ピッケルハウベ",
    "picket fence, paling": "ピケットフェンス",
    "pickup, pickup truck": "ピックアップ",
    "pier": "橋脚",
    "piggy bank, penny bank": "貯金箱",
    "pill bottle": "錠剤瓶",
    "pillow": "枕",
    "ping-pong ball": "ピンポン玉",
    "pinwheel": "風車",
    "pirate, pirate ship": "海賊",
    "pitcher, ewer": "ピッチャー",
    "plane, carpenter''s plane, woodworking plane": "飛行機",
    "planetarium": "プラネタリウム",
    "plastic bag": "ビニール袋",
    "plate rack": "プレートラック",
    "plow, plough": "プラウ",
    "plunger, plumber''s helper": "プランジャー",
    "Polaroid camera, Polaroid Land camera": "ポラロイドカメラ",
    "pole": "ポール",
    "police van, police wagon, paddy wagon, patrol wagon, wagon, black Maria": "警察のバン",
    "poncho": "ポンチョ",
    "pool table, billiard table, snooker table": "プールテーブル",
    "pop bottle, soda bottle": "ポップボトル",
    "pot, flowerpot": "ポット",
    "potter''s wheel": "ポッターのホイール",
    "power drill": "電動ドリル",
    "prayer rug, prayer mat": "祈りの敷物",
    "printer": "プリンタ",
    "prison, prison house": "刑務所",
    "projectile, missile": "発射",
    "projector": "プロジェクター",
    "puck, hockey puck": "パック",
    "punching bag, punch bag, punching ball, punchball": "パンチングバッグ",
    "purse": "財布",
    "quill, quill pen": "クイル",
    "quilt, comforter, comfort, puff": "キルト",
    "racer, race car, racing car": "レーサー",
    "racket, racquet": "ラケット",
    "radiator": "ラジエーター",
    "radio, wireless": "ラジオ",
    "radio telescope, radio reflector": "電波望遠鏡",
    "rain barrel": "天水桶",
    "recreational vehicle, RV, R.V.": "RV車",
    "reel": "リール",
    "reflex camera": "レフレックスカメラ",
    "refrigerator, icebox": "冷蔵庫",
    "remote control, remote": "リモコン",
    "restaurant, eating house, eating place, eatery": "レストラン",
    "revolver, six-gun, six-shooter": "リボルバー",
    "rifle": "ライフル",
    "rocking chair, rocker": "ロッキングチェア",
    "rotisserie": "ロティサリー",
    "rubber eraser, rubber, pencil eraser": "消しゴム",
    "rugby ball": "ラグビーボール",
    "rule, ruler": "ルール",
    "running shoe": "ランニングシューズ",
    "safe": "安全",
    "safety pin": "安全ピン",
    "saltshaker, salt shaker": "塩シェーカー",
    "sandal": "サンダル",
    "sarong": "サロン",
    "sax, saxophone": "サックス",
    "scabbard": "鞘",
    "scale, weighing machine": "スケール",
    "school bus": "スクールバス",
    "schooner": "スクーナー",
    "scoreboard": "スコアボード",
    "screen, CRT screen": "画面",
    "screw": "スクリュー",
    "screwdriver": "ドライバー",
    "seat belt, seatbelt": "シートベルト",
    "sewing machine": "ミシン",
    "shield, buckler": "シールド",
    "shoe shop, shoe-shop, shoe store": "靴屋",
    "shoji": "障子",
    "shopping basket": "買い物カゴ",
    "shopping cart": "ショッピングカート",
    "shovel": "シャベル",
    "shower cap": "シャワーキャップ",
    "shower curtain": "シャワーカーテン",
    "ski": "スキー",
    "ski mask": "目出し帽",
    "sleeping bag": "寝袋",
    "slide rule, slipstick": "計算尺",
    "sliding door": "引き戸",
    "slot, one-armed bandit": "スロット",
    "snorkel": "スノーケル",
    "snowmobile": "スノーモービル",
    "snowplow, snowplough": "除雪機",
    "soap dispenser": "ソープディスペンサー",
    "soccer ball": "サッカーボール",
    "sock": "靴下",
    "solar dish, solar collector, solar furnace": "ソーラーディッシュ",
    "sombrero": "ソンブレロ",
    "soup bowl": "スープボウル",
    "space bar": "スペースキー",
    "space heater": "スペースヒーター",
    "space shuttle": "スペースシャトル",
    "spatula": "スパーテル",
    "speedboat": "スピードボート",
    "spider web, spider''s web": "クモの巣",
    "spindle": "スピンドル",
    "sports car, sport car": "スポーツカー",
    "spotlight, spot": "スポットライト",
    "stage": "ステージ",
    "steam locomotive": "蒸気機関車",
    "steel arch bridge": "鋼アーチ橋",
    "steel drum": "スチールドラム",
    "stethoscope": "聴診器",
    "stole": "ストール",
    "stone wall": "石垣",
    "stopwatch, stop watch": "ストップウォッチ",
    "stove": "レンジ",
    "strainer": "濾過器",
    "streetcar, tram, tramcar, trolley, trolley car": "路面電車",
    "stretcher": "担架",
    "studio couch, day bed": "スタジオのソファ",
    "stupa, tope": "仏舎利塔",
    "submarine, pigboat, sub, U-boat": "潜水艦",
    "suit, suit of clothes": "服のスーツ",
    "sundial": "日時計",
    "sunglass": "サングラス",
    "sunglasses, dark glasses, shades": "サングラス",
    "sunscreen, sunblock, sun blocker": "日焼け止め",
    "suspension bridge": "つり橋",
    "swab, swob, mop": "綿棒",
    "sweatshirt": "トレーナー",
    "swimming trunks, bathing trunks": "水泳パンツ",
    "swing": "スイング",
    "switch, electric switch, electrical switch": "スイッチ",
    "syringe": "注射器",
    "table lamp": "電気スタンド",
    "tank, army tank, armored combat vehicle, armoured combat vehicle": "タンク",
    "tape player": "テーププレーヤー",
    "teapot": "ティーポット",
    "teddy, teddy bear": "テディベア",
    "television, television system": "テレビ",
    "tennis ball": "テニスボール",
    "thatch, thatched roof": "わらぶき",
    "theater curtain, theatre curtain": "劇場カーテン",
    "thimble": "指貫",
    "thresher, thrasher, threshing machine": "脱穀",
    "throne": "王位",
    "tile roof": "瓦屋根",
    "toaster": "トースター",
    "tobacco shop, tobacconist shop, tobacconist": "タバコ店",
    "toilet seat": "便座",
    "torch": "松明",
    "totem pole": "トーテムポール",
    "tow truck, tow car, wrecker": "レッカー車",
    "toyshop": "玩具屋",
    "tractor": "トラクター",
    "trailer truck, tractor trailer, trucking rig, rig, articulated lorry, semi": "トレーラートラック",
    "tray": "トレイ",
    "trench coat": "トレンチコート",
    "tricycle, trike, velocipede": "三輪車",
    "trimaran": "トリマラン",
    "tripod": "三脚",
    "triumphal arch": "凱旋門",
    "trolleybus, trolley coach, trackless trolley": "トロリーバス",
    "trombone": "トロンボーン",
    "tub, vat": "浴槽",
    "turnstile": "改札口",
    "typewriter keyboard": "タイプライターのキーボード",
    "umbrella": "傘",
    "unicycle, monocycle": "一輪車",
    "upright, upright piano": "アップライト",
    "vacuum, vacuum cleaner": "真空",
    "vase": "花瓶",
    "vault": "ボールト",
    "velvet": "ベルベット",
    "vending machine": "自動販売機",
    "vestment": "法衣",
    "viaduct": "高架橋",
    "violin, fiddle": "バイオリン",
    "volleyball": "バレーボール",
    "waffle iron": "ワッフル焼き型",
    "wall clock": "壁時計",
    "wallet, billfold, notecase, pocketbook": "財布",
    "wardrobe, closet, press": "ワードローブ",
    "warplane, military plane": "軍用機",
    "washbasin, handbasin, washbowl, lavabo, wash-hand basin": "洗面台",
    "washer, automatic washer, washing machine": "洗濯機",
    "water bottle": "水筒",
    "water jug": "水差し",
    "water tower": "給水塔",
    "whiskey jug": "ウイスキーの水差し",
    "whistle": "ホイッスル",
    "wig": "かつら",
    "window screen": "ウインドウスクリーン",
    "window shade": "ウィンドウシェード",
    "Windsor tie": "ウィンザーネクタイ",
    "wine bottle": "ワインボトル",
    "wing": "羽",
    "wok": "中華鍋",
    "wooden spoon": "木製スプーン",
    "wool, woolen, woollen": "ウール",
    "worm fence, snake fence, snake-rail fence, Virginia fence": "ワームフェンス",
    "wreck": "残骸",
    "yawl": "ヨール",
    "yurt": "パオ",
    "web site, website, internet site, site": "ウェブサイト",
    "comic book": "コミックブック",
    "crossword puzzle, crossword": "クロスワードパズル",
    "street sign": "道路標識",
    "traffic light, traffic signal, stoplight": "交通信号灯",
    "book jacket, dust cover, dust jacket, dust wrapper": "ブックカバー",
    "menu": "メニュー",
    "plate": "プレート",
    "guacamole": "グアカモーレ",
    "consomme": "コンソメ",
    "hot pot, hotpot": "鍋",
    "trifle": "ささいなこと",
    "ice cream, icecream": "アイスクリーム",
    "ice lolly, lolly, lollipop, popsicle": "アイスキャンディー",
    "French loaf": "フランスのパン",
    "bagel, beigel": "ベーグル",
    "pretzel": "プレッツェル",
    "cheeseburger": "チーズバーガー",
    "hotdog, hot dog, red hot": "ホットドッグ",
    "mashed potato": "マッシュポテト",
    "head cabbage": "ヘッドキャベツ",
    "broccoli": "ブロッコリ",
    "cauliflower": "カリフラワー",
    "zucchini, courgette": "ズッキーニ",
    "spaghetti squash": "キンシウリ",
    "acorn squash": "ドングリカボチャ",
    "butternut squash": "バタースカッシュ",
    "cucumber, cuke": "キュウリ",
    "artichoke, globe artichoke": "アーティチョーク",
    "bell pepper": "ピーマン",
    "cardoon": "カルドン",
    "mushroom": "キノコ",
    "Granny Smith": "グラニースミス",
    "strawberry": "イチゴ",
    "orange": "オレンジ",
    "lemon": "レモン",
    "fig": "イチジク",
    "pineapple, ananas": "パイナップル",
    "banana": "バナナ",
    "jackfruit, jak, jack": "ジャックフルーツ",
    "custard apple": "カスタードアップル",
    "pomegranate": "ザクロ",
    "hay": "干し草",
    "carbonara": "カルボナーラ",
    "chocolate sauce, chocolate syrup": "チョコレートソース",
    "dough": "生地",
    "meat loaf, meatloaf": "ミートローフ",
    "pizza, pizza pie": "ピザ",
    "potpie": "potpie",
    "burrito": "ブリトー",
    "red wine": "赤ワイン",
    "espresso": "エスプレッソ",
    "cup": "カップ",
    "eggnog": "エッグノッグ",
    "alp": "アルプス",
    "bubble": "バブル",
    "cliff, drop, drop-off": "崖",
    "coral reef": "珊瑚礁",
    "geyser": "間欠泉",
    "lakeside, lakeshore": "湖畔",
    "promontory, headland, head, foreland": "岬",
    "sandbar, sand bar": "砂州",
    "seashore, coast, seacoast, sea-coast": "海岸",
    "valley, vale": "谷",
    "volcano": "火山",
    "ballplayer, baseball player": "野球選手",
    "groom, bridegroom": "新郎",
    "scuba diver": "スキューバダイバー",
    "rapeseed": "菜種",
    "daisy": "デージー",
    "yellow lady''s slipper, yellow lady-slipper, Cypripedium calceolus, Cypripedium parviflorum": "黄色婦人のスリッパ",
    "corn": "コーン",
    "acorn": "団栗",
    "hip, rose hip, rosehip": "ヒップ",
    "buckeye, horse chestnut, conker": "トチノキ",
    "coral fungus": "サンゴ菌",
    "agaric": "ベニテングタケ",
    "gyromitra": "gyromitra",
    "stinkhorn, carrion fungus": "腐肉菌",
    "earthstar": "earthstar",
    "hen-of-the-woods, hen of the woods, Polyporus frondosus, Grifola frondosa": "鶏の - 森",
    "bolete": "bolete",
    "ear, spike, capitulum": "耳",
    "toilet tissue, toilet paper, bathroom tissue": "トイレットペーパー"
    ]
    func en2ja(s : String) -> String {
        return MOBILENET_EN2JA[s, default: s]
    }
}

