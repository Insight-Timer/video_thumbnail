import Flutter
import UIKit
import AVFoundation
import ACThumbnailGenerator_Swift

public class SwiftVideoThumbnailPlugin: NSObject, FlutterPlugin, ACThumbnailGeneratorDelegate {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "plugins.justsoft.xyz/video_thumbnail", binaryMessenger: registrar.messenger())
    let instance = SwiftVideoThumbnailPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
    
 private enum Method: String {
   case data
   case file
 }
    
 var generator: ACThumbnailGenerator?
 var result: FlutterResult?
 var format: Int = 0
 var quality: Int = 75
 var maxWidth: Int?
 var maxHeight: Int?
    
 public static func generateThumnail(_ url:URL, headers: [String: Any]?, format: Int,  maxWidth: Int, maxHeight:Int, timeMs:Int, quality:Int) -> Data? {
    let headersToPass = headers == nil ? nil : ["AVURLAssetHTTPHeaderFieldsKey" : headers!]
    let asset = AVURLAsset.init(url: url, options: headersToPass)
    let imgGenerator = AVAssetImageGenerator.init(asset: asset)

    imgGenerator.appliesPreferredTrackTransform = true
    imgGenerator.maximumSize = CGSize(width: maxWidth, height: maxHeight)
    imgGenerator.requestedTimeToleranceBefore = CMTime.zero
    imgGenerator.requestedTimeToleranceAfter = CMTime(value: 10, timescale: 1000)

    do {
        // Create audio player object
        let cgImage = try imgGenerator.copyCGImage(at: CMTime(value:CMTimeValue(timeMs), timescale: 1000), actualTime:nil)

        let thumbnail = UIImage(cgImage: cgImage)

      if( format == 0 ) {
          let q = Double(quality) * 0.01
          return thumbnail.jpegData(compressionQuality: CGFloat(q));
      } else {
          return thumbnail.pngData();
      }
    }
    catch {
        print("couldn't generate thumbnail, error:\(error.localizedDescription)");
        return nil;
    }
 }
    
func captureImage(_ url: URL, timeMS:Int) {
    let streamUrl = url
    generator = ACThumbnailGenerator(streamUrl: streamUrl)
    generator!.delegate = self
    generator!.captureImage(at: Double(timeMS))
}

public func generator(_ generator: ACThumbnailGenerator, didCapture image: UIImage, at position: Double) {
    
    var finalImage = image
    
    guard let result = result else {
      return
    }
    
    if maxWidth != nil || maxHeight != nil {
        finalImage = image.resize(withSize: CGSize(width: maxWidth ?? Int(image.size.width), height: maxHeight ?? Int(image.size.height)), contentMode: .contentAspectFit) ?? image
    }
    
    if(format == 0 ) {
        let q = Double(quality) * 0.01
        let data = finalImage.jpegData(compressionQuality: CGFloat(q));
        result(data)
    } else {
        let data = finalImage.pngData();
        result(data)
    }
}

     

public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    self.result = result
    let args = call.arguments;
      
    guard let json = args as? [String: Any],
        let file = json["video"] as? String,
        let format = json["format"] as? Int,
        let maxh = json["maxh"] as? Int,
        let maxw = json["maxw"] as? Int,
        let timeMs = json["timeMs"] as? Int,
        let quality = json["quality"] as? Int else {
    return
    }

    let headers = json["video"] as? [String: Any]
    var path = json["path"] as? String

    self.format = format
    self.quality = quality
    self.maxWidth = maxw
    self.maxHeight = maxh
    
    let isLocalFile = file.hasPrefix("file://") || file.hasPrefix("/");

    let url = file.hasPrefix("file://") ? URL(fileURLWithPath:String(file[file.index(file.startIndex, offsetBy: 7)...])) : (file.hasPrefix("/") ? URL(fileURLWithPath:file) : URL(string: file))
  
    guard let method = Method(rawValue: call.method) else {
        result(FlutterMethodNotImplemented)
        return
    }

    guard let url = url else {
    result(nil)
    return
    }

    var isHLS = false

    if !isLocalFile, url.pathExtension == "m3u8" {
      isHLS = true
    }

    switch(method) {
    case .data:
      if isHLS {
        captureImage(url, timeMS: timeMs)
        return
      }
      
      DispatchQueue.global().async {
          let data = SwiftVideoThumbnailPlugin.generateThumnail(url, headers:headers, format:format,maxWidth:maxw, maxHeight:maxh, timeMs:timeMs, quality:quality)
          result(data)
      }
    case .file:
      if isHLS {
        result(nil)
        return
      }
      
      if path == nil && !isLocalFile {
          path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last
      }
      
      guard let path = path else {
          result(nil);
          return
      }
      
      DispatchQueue.global().async {
          let data = SwiftVideoThumbnailPlugin.generateThumnail(url, headers:headers, format:format,maxWidth:maxw, maxHeight:maxh, timeMs:timeMs, quality:quality)
          let ext = format == 0 ? "jpg" :  "png"
          let thumbnail = url.deletingPathExtension().appendingPathExtension(ext)
          var filePath = thumbnail
       
          if !path.isEmpty {
              let lastPart = thumbnail.lastPathComponent
              filePath = URL(fileURLWithPath:path)
              if filePath.pathExtension == ext {
                 filePath = filePath.appendingPathComponent(lastPart)
              }
          }
          
          guard let data = data else {
            result(nil);
            return
          }
          
          do {
             try data.write(to: filePath)
              
              let fullpath = filePath.absoluteString
              
              if fullpath.hasPrefix("file://") {
                  result(String(fullpath[fullpath.index(fullpath.startIndex, offsetBy: 7)...]));
              }
              else {
                  result(fullpath);
              }
              
          } catch {
              result(FlutterError(code: "Error \(400)",
                                  message: error.localizedDescription,
                                          details: error.localizedDescription))
          }
      }

    }
  }
}

extension UIImage {
    
    enum ContentMode {
            case contentFill
            case contentAspectFill
            case contentAspectFit
    }
        
    func resize(withSize size: CGSize, contentMode: ContentMode = .contentAspectFill) -> UIImage? {
        let aspectWidth = size.width / self.size.width
        let aspectHeight = size.height / self.size.height
        
        switch contentMode {
        case .contentFill:
            return resize(withSize: size)
        case .contentAspectFit:
            let aspectRatio = min(aspectWidth, aspectHeight)
            return resize(withSize: CGSize(width: self.size.width * aspectRatio, height: self.size.height * aspectRatio))
        case .contentAspectFill:
            let aspectRatio = max(aspectWidth, aspectHeight)
            return resize(withSize: CGSize(width: self.size.width * aspectRatio, height: self.size.height * aspectRatio))
        }
    }
    
    private func resize(withSize size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
