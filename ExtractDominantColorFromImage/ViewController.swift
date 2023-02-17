//
//  ViewController.swift
//  ExtractColorsFromImage
//
//  Created by Kavana Anand on 1/4/23.
//

import UIKit

class ViewController: UIViewController {
    private let imageView = UIImageView()
    private let colorView = UIView()
    private let infoLabel = UILabel()
    
    private var downsampledCGImage: CGImage?
    private var bins = Array<Array<UIColor>>()
    private var colors = Array<UIColor>()
    
    private let binValues = [10, 20, 25]
    // More the number of bins, the range of hue per bin is small
    // Fewer the number of bins, the broader is the range of hue per bin
    private var numberOfBins = Int()
    
    private let images = ["c1", "c2", "c3", "c4", "c5"];
}


// MARK: View life cycle

extension ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.contentMode = UIView.ContentMode.scaleAspectFit
        view.addSubview(imageView)
        
        infoLabel.text = "Loading..."
        infoLabel.numberOfLines = 0
        infoLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        infoLabel.textColor = .black
        view.addSubview(infoLabel)
                        
        colorView.backgroundColor = nil
        view.addSubview(colorView)
        
        resetBins()
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        colorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            imageView.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -100),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            infoLabel.bottomAnchor.constraint(equalTo: colorView.topAnchor, constant: -50),
            colorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            colorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            colorView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            colorView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        
        // Find the dominant color for every image in images array with number of bins equal to the values specified in bins
        var imageIndex: Int = 0
        var binValueIndex: Int = 0
        var reloadImage = true
        var image = UIImage()
        
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [self] timer in
            guard imageIndex < images.count else {
                timer.invalidate()
                return
            }
            
            numberOfBins = binValues[binValueIndex]
            resetBins()
            infoLabel.text = "Image: \(images[imageIndex])\nNumber of bins: \(numberOfBins)"
            
            
            if (reloadImage) {
                // Downsample the image 300 as the maximum dimension for faster result
                guard let imageURL = createLocalUrl(forImageNamed: images[imageIndex]),
                      let downsampledImage = downsample(image: imageURL, to: CGSize(width: 300, height: 300)) else {
                    return
                }
                image = downsampledImage
                reloadImage = false
            }
            
            downsampledCGImage = image.cgImage
            imageView.image = image
            
            // Find the dominant color
            let color = getDominantColor()
            colorView.backgroundColor = color
            
            binValueIndex = binValueIndex + 1
            if (binValueIndex >= binValues.count) {
                binValueIndex = 0
                imageIndex = imageIndex + 1
                reloadImage = true
            }
        }
    }
}

// MARK: Histogram hue

extension ViewController {
    
    func getDominantColor() -> UIColor? {
        guard let cgImage = downsampledCGImage else {
            return nil
        }
        
        for x in 0..<cgImage.width {
            for y in 0..<cgImage.height {
                // Get the color of the pixel at (x,y)
                let color = getPixelColor(x, y)
                colors.append(color)
                // Color quantization
                binColor(color)
            }
        }
        
        let dominantHue = findDominantHue()
        
        // Retrieving a random color from the array with dominant hue in the image
        let randomIndex = Int.random(in: 0..<dominantHue.count)
        let dominantColor = dominantHue[randomIndex]
        return dominantColor
    }
    
    func getPixelColor(_ x: Int, _ y: Int) -> UIColor {
        guard let cgImage = downsampledCGImage else {
            return .white
        }
        
        let pixelData = cgImage.dataProvider?.data
        let dataPtr = CFDataGetBytePtr(pixelData)
        
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let pixelOffset = y * bytesPerRow + x * bytesPerPixel
        
        // Downsampling the image changed the format from RGBA to ARGB.
        // WHY?
        /* // RGBA
        let red = dataPtr![pixelOffset + 0]
        let green = dataPtr![pixelOffset + 1]
        let blue = dataPtr![pixelOffset + 2]
        let alpha = dataPtr![pixelOffset + 3]
         */
        
        // ARGB
        let alpha = dataPtr![pixelOffset + 0]
        let red = dataPtr![pixelOffset + 1]
        let green = dataPtr![pixelOffset + 2]
        let blue = dataPtr![pixelOffset + 3]
        
        let color = UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: CGFloat(alpha)/255.0)
        return color
    }
    
    func binColor(_ color: UIColor) {
        // Get the hue value for the given color
        // TODO: Handle when the hue value is outside 0.0 to 1.0 range with extended colorspace on devices running iOS 10 and later
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var brightness: CGFloat = 0
        color.getHue(&hue, saturation: &sat, brightness: &brightness, alpha: nil)
        
        // Determine the bin index
        let index = Int(CGFloat(numberOfBins) * hue)
        bins[index].append(color)
    }
    
    func findDominantHue() -> Array<UIColor> {
        /*
        for array in bins {
            print(bins.firstIndex(of: array)!, " - ", array.count)
        }
        */
        
        var dominantHue = bins[0]
        for i in 1..<numberOfBins {
            if bins[i].count > dominantHue.count {
                dominantHue = bins[i]
            }
        }
        
        return dominantHue
    }
    
    func resetBins() {
        bins.removeAll()
        for _ in 0..<numberOfBins {
            bins.append(Array<UIColor>())
        }
    }
}

// MARK: Utilities

extension ViewController {
    
    /* References
     WWDC session - https://developer.apple.com/videos/play/wwdc2018/416/?time=1373
     */
    func downsample(image imageURL: URL,
                    to size: CGSize,
                    scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            return nil
        }
        
        let pixelDimension = max(size.width, size.height) * scale
        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelDimension
        ]
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        downsampledCGImage = downsampledImage
        return UIImage(cgImage: downsampledImage)
    }
    
    
    /*
     The following snippet is copied from
     https://gist.github.com/fahied/d4a99e12914eb3edb074663828240907?permalink_comment_id=3685293#gistcomment-3685293
     */
    
    // Retrieves (or creates should it be necessary) a temporary image's local URL on cache directory for testing purposes
    /// - Parameter name: image name retrieved from asset catalog
    /// - Parameter imageExtension: Image type. Defaults to `.jpg` kind
    /// - Returns: Resulting URL for named image
    func createLocalUrl(forImageNamed name: String, imageExtension: String = "jpg") -> URL? {
        let fileManager = FileManager.default

        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("Unable to access cache directory")
            return nil
        }
        
        let url = cacheDirectory.appendingPathComponent("\(name).\(imageExtension)")
        
        // If file doesn't exist, creates it
        guard fileManager.fileExists(atPath: url.path) else {
            // Bundle(for: Self.self) is used here instead of .main in order to work on test target as well
            guard let image = UIImage(named: name, in: Bundle(for: Self.self), with: nil),
                  let data = image.jpegData(compressionQuality: 1) else {
                print("Impossible to convert to jpg data")
                return nil
            }
            
            fileManager.createFile(atPath: url.path, contents: data, attributes: nil)
            return url
        }
        
        return url
    }
}
