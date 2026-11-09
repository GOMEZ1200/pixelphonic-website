// One shared colour grade so different photos sit together: gentle contrast, slightly muted colour,
// a cool tint in the shadows, warm highlights, matched vignette and grain.
//   swift grade.swift in.jpg out.jpg exposure width
import AppKit; import CoreImage; import CoreImage.CIFilterBuiltins
let a = CommandLine.arguments
var img = CIImage(contentsOf: URL(fileURLWithPath: a[1]), options: [.applyOrientationProperty: true])!
let ext = img.extent
let ev = CIFilter.exposureAdjust(); ev.inputImage = img; ev.ev = Float(a[3])!; img = ev.outputImage!
let cc = CIFilter.colorControls(); cc.inputImage = img; cc.saturation = 0.82; cc.contrast = 1.1; img = cc.outputImage!
// split tone: shadows towards deep blue, highlights towards warm
let mono = CIFilter.colorMonochrome(); mono.inputImage = img; mono.color = CIColor(red: 0.16, green: 0.26, blue: 0.40); mono.intensity = 1
let soft = CIFilter.softLightBlendMode(); soft.inputImage = mono.outputImage!; soft.backgroundImage = img
let mix = CIFilter.dissolveTransition(); mix.inputImage = soft.outputImage!; mix.targetImage = img; mix.time = 0.55; img = mix.outputImage!.cropped(to: ext)
let warm = CIFilter.temperatureAndTint(); warm.inputImage = img; warm.neutral = CIVector(x: 6500, y: 0); warm.targetNeutral = CIVector(x: 6100, y: 0); img = warm.outputImage!
let vig = CIFilter.vignette(); vig.inputImage = img; vig.intensity = 0.45; vig.radius = Float(ext.width/900); img = vig.outputImage!.cropped(to: ext)
let n = CIFilter.randomGenerator().outputImage!.cropped(to: ext)
let g = CIFilter.colorMatrix(); g.inputImage = n; let s: CGFloat = 0.04
g.rVector = CIVector(x: s, y: 0, z: 0, w: 0); g.gVector = CIVector(x: s, y: 0, z: 0, w: 0); g.bVector = CIVector(x: s, y: 0, z: 0, w: 0); g.biasVector = CIVector(x: -s/2, y: -s/2, z: -s/2, w: 0)
let gm = CIFilter.colorControls(); gm.inputImage = g.outputImage!; gm.saturation = 0
let add = CIFilter.additionCompositing(); add.inputImage = gm.outputImage!.applyingGaussianBlur(sigma: 0.45).cropped(to: ext); add.backgroundImage = img; img = add.outputImage!.cropped(to: ext)
let w = CGFloat(Double(a[4])!); img = img.applyingFilter("CILanczosScaleTransform", parameters: ["inputScale": min(1, w/ext.width)])
let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
let cg = ctx.createCGImage(img, from: img.extent)!
try! NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.86])!.write(to: URL(fileURLWithPath: a[2]))
print("wrote \(a[2]) \(cg.width)x\(cg.height)")
