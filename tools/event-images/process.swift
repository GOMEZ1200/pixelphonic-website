// Turns a real job photo into a website image: black and white with colour kept only on lit
// buttons and LEDs, client content on screens replaced or softened, natural grain and vignette.
// Nothing is redrawn: every pixel comes from the photo or from rendered screen content.
//
//   swift process.swift scenes/<scene>.json [--debug]
//
// Coordinates in the JSON are fractions of the photo (0 to 1, from the top left).
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct Replace: Codable { var quad: [[Double]]; var image: String; var brightness: Double?; var soften: Double?
  var keepDark: Double?   // keep dark things in front of the screen (stands, heads): only replace pixels brighter than this
}
struct Region: Codable { var rect: [Double]; var radius: Double? }
struct Scene: Codable {
  var input: String; var output: String; var width: Int
  var crop: [Double]?                 // optional [x0,y0,x1,y1]
  var replace: [Replace]?             // screens to swap for rendered content
  var blur: [Region]?                 // small areas to soften (distant logos, printouts)
  var colour: [Region]?               // only lit, saturated pixels inside these keep colour
  var sat: Double?; var val: Double?  // thresholds for "lit and coloured"
  var grain: Double?; var vignette: Double?; var contrast: Double?
  var mix: [Double]?                  // black-and-white channel weights [r,g,b], like a colour filter on film
  var dim: [Region]?                  // lit buttons that should read as idle: darkened...
  var keep: [Region]?                 // ...except these (the live PGM/PVW crosspoints)
  var dimAmount: Double?
}

let args = CommandLine.arguments
let sceneURL = URL(fileURLWithPath: args[1])
let base = sceneURL.deletingLastPathComponent()
let scene = try JSONDecoder().decode(Scene.self, from: Data(contentsOf: sceneURL))
let debug = args.contains("--debug")
func path(_ p: String) -> URL { p.hasPrefix("/") || p.hasPrefix("~") ? URL(fileURLWithPath: (p as NSString).expandingTildeInPath) : base.appendingPathComponent(p) }

let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
var photo = CIImage(contentsOf: path(scene.input), options: [.applyOrientationProperty: true])!
let W = photo.extent.width, H = photo.extent.height
func pt(_ p: [Double]) -> CGPoint { CGPoint(x: p[0] * W, y: (1 - p[1]) * H) }
func rect(_ r: [Double]) -> CGRect { CGRect(x: r[0] * W, y: (1 - r[3]) * H, width: (r[2] - r[0]) * W, height: (r[3] - r[1]) * H) }
func feathered(_ r: CGRect, _ f: CGFloat) -> CIImage {
  CIImage(color: .white).cropped(to: r).applyingGaussianBlur(sigma: f).cropped(to: photo.extent)
    .composited(over: CIImage(color: .black).cropped(to: photo.extent))
}

// 1. Screens: map rendered content onto each screen with a perspective warp, matched to the photo.
for r in scene.replace ?? [] {
  var content = CIImage(contentsOf: path(r.image))!
  let p = CIFilter.perspectiveTransform()
  p.inputImage = content
  p.topLeft = pt(r.quad[0]); p.topRight = pt(r.quad[1]); p.bottomRight = pt(r.quad[2]); p.bottomLeft = pt(r.quad[3])
  content = p.outputImage!
  // Screens photographed by a phone are a little soft and lifted; match that.
  content = content.applyingGaussianBlur(sigma: r.soften ?? 0.8).cropped(to: content.extent)
  let b = CIFilter.colorControls(); b.inputImage = content; b.brightness = Float(r.brightness ?? 0) ; b.contrast = 0.92; content = b.outputImage!
  // Mask: the quad itself, edges feathered by a pixel so it sits inside the bezel.
  let m = CIFilter.perspectiveTransform()
  m.inputImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
  m.topLeft = pt(r.quad[0]); m.topRight = pt(r.quad[1]); m.bottomRight = pt(r.quad[2]); m.bottomLeft = pt(r.quad[3])
  var mask = m.outputImage!.applyingGaussianBlur(sigma: 0.9).cropped(to: photo.extent).composited(over: CIImage(color: .black).cropped(to: photo.extent))
  if let t = r.keepDark {
    let k = CIColorKernel(source: "kernel vec4 bright(__sample c, float t) { float l = dot(c.rgb, vec3(0.3,0.59,0.11)); float k = smoothstep(t, t + 0.12, l); return vec4(k,k,k,1.0); }")!
    let bright = k.apply(extent: photo.extent, arguments: [photo, Float(t)])!.applyingGaussianBlur(sigma: 0.7).cropped(to: photo.extent)
    let mul = CIFilter.multiplyCompositing(); mul.inputImage = bright; mul.backgroundImage = mask; mask = mul.outputImage!.cropped(to: photo.extent)
  }
  let bl = CIFilter.blendWithMask(); bl.inputImage = content; bl.backgroundImage = photo; bl.maskImage = mask
  photo = bl.outputImage!.cropped(to: photo.extent)
}

// 2. Soften small areas (distant logos, printed running orders) like natural defocus.
for r in scene.blur ?? [] {
  let soft = photo.clampedToExtent().applyingGaussianBlur(sigma: r.radius ?? 8).cropped(to: photo.extent)
  let bl = CIFilter.blendWithMask(); bl.inputImage = soft; bl.backgroundImage = photo; bl.maskImage = feathered(rect(r.rect), 2)
  photo = bl.outputImage!.cropped(to: photo.extent)
}

// 2b. Idle buttons: darken lit buttons that should be off, keeping the live crosspoints.
if let dims = scene.dim, !dims.isEmpty {
  var dm = CIImage(color: .black).cropped(to: photo.extent)
  for r in dims { dm = CIImage(color: .white).cropped(to: rect(r.rect)).applyingGaussianBlur(sigma: 1.5).cropped(to: photo.extent).composited(over: dm) }
  for r in scene.keep ?? [] { dm = CIImage(color: .black).cropped(to: rect(r.rect)).applyingGaussianBlur(sigma: 1.5).cropped(to: photo.extent).composited(over: dm) }
  let a = Float(scene.dimAmount ?? 0.28)
  let dk = CIFilter.colorMatrix(); dk.inputImage = photo
  dk.rVector = CIVector(x: CGFloat(a), y: 0, z: 0, w: 0); dk.gVector = CIVector(x: 0, y: CGFloat(a), z: 0, w: 0); dk.bVector = CIVector(x: 0, y: 0, z: CGFloat(a), w: 0)
  let sat = CIFilter.colorControls(); sat.inputImage = dk.outputImage!; sat.saturation = 0.15
  let bl = CIFilter.blendWithMask(); bl.inputImage = sat.outputImage!; bl.backgroundImage = photo; bl.maskImage = dm
  photo = bl.outputImage!.cropped(to: photo.extent)
}

// 3. Black and white with a gentle photographic curve.
let wts = scene.mix ?? [0.3, 0.59, 0.11]
let cm = CIFilter.colorMatrix(); cm.inputImage = photo
let wv = CIVector(x: wts[0], y: wts[1], z: wts[2], w: 0)
cm.rVector = wv; cm.gVector = wv; cm.bVector = wv
let mono = CIFilter.colorControls(); mono.inputImage = cm.outputImage!; mono.saturation = 0; mono.contrast = Float(scene.contrast ?? 1.08)
var bw = mono.outputImage!

// 4. Selective colour: inside the control-surface regions, keep only pixels that are both
//    saturated and bright (emitted light), with a soft edge and a little glow.
if let regions = scene.colour, !regions.isEmpty {
  let s = Float(scene.sat ?? 0.35), v = Float(scene.val ?? 0.45)
  let kernel = CIColorKernel(source: """
    kernel vec4 lit(__sample c, float s, float v) {
      float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
      float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
      float k = smoothstep(s, s + 0.15, sat) * smoothstep(v, v + 0.15, mx);
      return vec4(k, k, k, 1.0);
    }
  """)!
  var lit = kernel.apply(extent: photo.extent, arguments: [photo, s, v])!
  // Grow the mask slightly so each button is coloured as a whole, then feather it.
  lit = lit.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 1.5]).applyingGaussianBlur(sigma: 1.2).cropped(to: photo.extent)
  var area = CIImage(color: .black).cropped(to: photo.extent)
  for r in regions { area = CIImage(color: .white).cropped(to: rect(r.rect)).applyingGaussianBlur(sigma: 6).cropped(to: photo.extent).composited(over: area) }
  let mult = CIFilter.multiplyCompositing(); mult.inputImage = lit; mult.backgroundImage = area
  let mask = mult.outputImage!.cropped(to: photo.extent)
  let bl = CIFilter.blendWithMask(); bl.inputImage = photo; bl.backgroundImage = bw; bl.maskImage = mask
  bw = bl.outputImage!.cropped(to: photo.extent)
  // Glow: the coloured light bleeding a little into its surroundings.
  let glowSrc = CIFilter.blendWithMask(); glowSrc.inputImage = photo; glowSrc.backgroundImage = CIImage(color: .black).cropped(to: photo.extent); glowSrc.maskImage = mask
  let glow = glowSrc.outputImage!.applyingGaussianBlur(sigma: 6).cropped(to: photo.extent)
  let dim = CIFilter.colorMatrix(); dim.inputImage = glow; dim.rVector = CIVector(x: 0.35, y: 0, z: 0, w: 0); dim.gVector = CIVector(x: 0, y: 0.35, z: 0, w: 0); dim.bVector = CIVector(x: 0, y: 0, z: 0.35, w: 0)
  let add = CIFilter.additionCompositing(); add.inputImage = dim.outputImage!; add.backgroundImage = bw
  bw = add.outputImage!.cropped(to: photo.extent)
}

// 5. Lens vignette and fine film-like grain.
let vig = CIFilter.vignette(); vig.inputImage = bw; vig.intensity = Float(scene.vignette ?? 0.55); vig.radius = Float(max(W, H) / 900)
bw = vig.outputImage!.cropped(to: photo.extent)
let noise = CIFilter.randomGenerator().outputImage!.cropped(to: photo.extent)
let g = CIFilter.colorMatrix(); g.inputImage = noise
let gs = CGFloat(scene.grain ?? 0.05)
g.rVector = CIVector(x: gs, y: 0, z: 0, w: 0); g.gVector = CIVector(x: gs, y: 0, z: 0, w: 0); g.bVector = CIVector(x: gs, y: 0, z: 0, w: 0); g.biasVector = CIVector(x: -gs/2, y: -gs/2, z: -gs/2, w: 0)
let mono2 = CIFilter.colorControls(); mono2.inputImage = g.outputImage!; mono2.saturation = 0
let grain = mono2.outputImage!.applyingGaussianBlur(sigma: 0.45).cropped(to: photo.extent)
let ga = CIFilter.additionCompositing(); ga.inputImage = grain; ga.backgroundImage = bw
var out = ga.outputImage!.cropped(to: photo.extent)

// Debug: outline every region so positions can be checked against the photo.
if debug {
  var marks = CIImage(color: .clear).cropped(to: photo.extent)
  func box(_ r: CGRect, _ c: CIColor) { for e in [CGRect(x: r.minX, y: r.minY, width: r.width, height: 2), CGRect(x: r.minX, y: r.maxY-2, width: r.width, height: 2), CGRect(x: r.minX, y: r.minY, width: 2, height: r.height), CGRect(x: r.maxX-2, y: r.minY, width: 2, height: r.height)] { marks = CIImage(color: c).cropped(to: e).composited(over: marks) } }
  for r in scene.colour ?? [] { box(rect(r.rect), CIColor(red: 0, green: 1, blue: 0)) }
  for r in scene.blur ?? [] { box(rect(r.rect), CIColor(red: 1, green: 0, blue: 0)) }
  out = marks.composited(over: out)
}

// 6. Crop and size.
if let c = scene.crop { out = out.cropped(to: rect(c)) }
let scale = CGFloat(scene.width) / out.extent.width
out = out.transformed(by: CGAffineTransform(translationX: -out.extent.minX, y: -out.extent.minY)).applyingFilter("CILanczosScaleTransform", parameters: ["inputScale": min(scale, 1.0)])
let cg = ctx.createCGImage(out, from: out.extent)!
let rep = NSBitmapImageRep(cgImage: cg)
let outURL = path(debug ? scene.output.replacingOccurrences(of: ".jpg", with: "-debug.jpg") : scene.output)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.86])!.write(to: outURL)
print("wrote \(outURL.path) \(cg.width)x\(cg.height)")
