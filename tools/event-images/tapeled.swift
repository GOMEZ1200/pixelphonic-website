// Black and white photo; inside the LED quads, every lit colour is remapped to the site's tape palette
// (orange, pink, yellow, green, blue) keeping its brightness, so the screens match pixelphonic.co.uk.
//   swift tapeled.swift in out width "x,y x,y x,y x,y" ["..."]   (quad corners as fractions: TL TR BR BL)
import AppKit; import CoreImage; import CoreImage.CIFilterBuiltins
let a = CommandLine.arguments
var img = CIImage(contentsOf: URL(fileURLWithPath: a[1]))!; let E = img.extent, W = E.width, H = E.height
let k = CIColorKernel(source: """
kernel vec4 tape(__sample c, __sample b) {
  float bmx = max(b.r, max(b.g, b.b)), bmn = min(b.r, min(b.g, b.b)), bd = bmx - bmn;
  float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b)), d = mx - mn;
  float s = mx > 0.0 ? d / mx : 0.0;
  float h = 0.0;
  if (bd > 0.0) { if (bmx == b.r) h = mod((b.g - b.b) / bd, 6.0); else if (bmx == b.g) h = (b.b - b.r) / bd + 2.0; else h = (b.r - b.g) / bd + 4.0; }
  h *= 60.0;
  vec3 t;
  if (h < 40.0 || h >= 320.0) t = vec3(1.0, 0.373, 0.122);        // orange
  else if (h < 125.0) t = vec3(0.91, 1.0, 0.102);                  // yellow
  else if (h < 170.0) t = vec3(0.239, 1.0, 0.353);                // green
  else if (h < 255.0) t = vec3(0.118, 0.722, 1.0);                // blue
  else t = vec3(1.0, 0.176, 0.584);                               // pink
  float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
  vec3 grey = vec3(l);
  vec3 col = t * (0.8 + 0.2 * clamp(mx, 0.0, 1.0));
  float w = smoothstep(0.18, 0.35, s);                             // white text and lines stay white
  return vec4(mix(grey, col, w), 1.0);
}
""")!
let soft = img.clampedToExtent().applyingGaussianBlur(sigma: 1.2).cropped(to: E)
let tape = k.apply(extent: E, arguments: [img, soft])!
let mono = img.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0, "inputContrast": 1.08])
var mask = CIImage(color: .black).cropped(to: E)
for q in a.dropFirst(4) {
  let p = q.split(separator: " ").map { $0.split(separator: ",").map { Double($0)! } }
  func pt(_ v: [Double]) -> CGPoint { CGPoint(x: v[0] * W, y: (1 - v[1]) * H) }
  let f = CIFilter.perspectiveTransform(); f.inputImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
  f.topLeft = pt(p[0]); f.topRight = pt(p[1]); f.bottomRight = pt(p[2]); f.bottomLeft = pt(p[3])
  mask = f.outputImage!.applyingGaussianBlur(sigma: 1.2).cropped(to: E).composited(over: mask)
}
let bl = CIFilter.blendWithMask(); bl.inputImage = tape; bl.backgroundImage = mono; bl.maskImage = mask
var out = bl.outputImage!.cropped(to: E)
// LED glow onto the set, in the new colours
let glowSrc = CIFilter.blendWithMask(); glowSrc.inputImage = tape; glowSrc.backgroundImage = CIImage(color: .black).cropped(to: E); glowSrc.maskImage = mask
let glow = glowSrc.outputImage!.clampedToExtent().applyingGaussianBlur(sigma: W * 0.01).cropped(to: E)
let gm = CIFilter.colorMatrix(); gm.inputImage = glow; gm.rVector = CIVector(x: 0.18, y: 0, z: 0, w: 0); gm.gVector = CIVector(x: 0, y: 0.18, z: 0, w: 0); gm.bVector = CIVector(x: 0, y: 0, z: 0.18, w: 0); gm.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
let ad = CIFilter.additionCompositing(); ad.inputImage = gm.outputImage!; ad.backgroundImage = out; out = ad.outputImage!.cropped(to: E)
let vig = CIFilter.vignette(); vig.inputImage = out; vig.intensity = 0.45; vig.radius = Float(W / 900); out = vig.outputImage!.cropped(to: E)
let n = CIFilter.randomGenerator().outputImage!.cropped(to: E); let g = CIFilter.colorMatrix(); g.inputImage = n; let s: CGFloat = 0.04
g.rVector = CIVector(x: s, y: 0, z: 0, w: 0); g.gVector = CIVector(x: s, y: 0, z: 0, w: 0); g.bVector = CIVector(x: s, y: 0, z: 0, w: 0); g.biasVector = CIVector(x: -s/2, y: -s/2, z: -s/2, w: 0)
let gr = g.outputImage!.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0]).applyingGaussianBlur(sigma: 0.45).cropped(to: E)
let ad2 = CIFilter.additionCompositing(); ad2.inputImage = gr; ad2.backgroundImage = out; out = ad2.outputImage!.cropped(to: E)
let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
let cg = ctx.createCGImage(out, from: E)!
try! NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.86])!.write(to: URL(fileURLWithPath: a[2]))
print("wrote \(a[2])")
