import Foundation
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
let src = args[1], outDir = args[2]
let scale = 6
guard let isrc = CGImageSourceCreateWithURL(URL(fileURLWithPath: src) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(isrc, 0, nil) else { fatalError("load") }
let W = img.width, H = img.height
// grey = max channel
var rgba = [UInt8](repeating: 0, count: W * H * 4)
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: &rgba, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
var g = [UInt8](repeating: 0, count: W * H)
for i in 0..<(W * H) { g[i] = max(rgba[i*4], rgba[i*4+1], rgba[i*4+2]) }
let thr: UInt8 = 90
var mask = g.map { $0 > thr }
// dilate radius R
let R = 9
var dil = [Bool](repeating: false, count: W * H)
for y in 0..<H { for x in 0..<W where mask[y*W+x] {
    for dy in -R...R { let yy = y+dy; if yy < 0 || yy >= H { continue }
        for dx in -R...R { let xx = x+dx; if xx < 0 || xx >= W { continue }; dil[yy*W+xx] = true } } } }
var label = [Int](repeating: -1, count: W * H)
var boxes: [(Int, Int, Int, Int)] = []
for y in 0..<H { for x in 0..<W where dil[y*W+x] && label[y*W+x] < 0 {
    let id = boxes.count; var minx = x, maxx = x, miny = y, maxy = y
    var stack = [(x, y)]; label[y*W+x] = id
    while let (cx, cy) = stack.popLast() {
        minx = min(minx, cx); maxx = max(maxx, cx); miny = min(miny, cy); maxy = max(maxy, cy)
        for (nx, ny) in [(cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1)] where nx >= 0 && ny >= 0 && nx < W && ny < H && dil[ny*W+nx] && label[ny*W+nx] < 0 {
            label[ny*W+nx] = id; stack.append((nx, ny)) } }
    boxes.append((minx + R, miny + R, maxx - R, maxy - R)) } }
var list = boxes.filter { ($0.2 - $0.0) > 25 && ($0.3 - $0.1) > 25 }
list.sort { ($0.1 / 80, $0.0) < ($1.1 / 80, $1.0) }
var manifest = ""
for (n, b) in list.enumerated() {
    let pad = 8
    let x0 = max(0, b.0 - pad), y0 = max(0, b.1 - pad), x1 = min(W - 1, b.2 + pad), y1 = min(H - 1, b.3 + pad)
    let cw = x1 - x0 + 1, ch = y1 - y0 + 1
    // crop grey into an 8-bit grey image, upscale with high-quality interpolation
    var crop = [UInt8](repeating: 0, count: cw * ch)
    for yy in 0..<ch { for xx in 0..<cw { crop[yy*cw+xx] = g[(y0+yy)*W + x0+xx] } }
    let gcs = CGColorSpaceCreateDeviceGray()
    let cctx = CGContext(data: &crop, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: cw, space: gcs, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let cimg = cctx.makeImage()!
    let uw = cw * scale, uh = ch * scale
    var up = [UInt8](repeating: 0, count: uw * uh)
    let uctx = CGContext(data: &up, width: uw, height: uh, bitsPerComponent: 8, bytesPerRow: uw, space: gcs, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    uctx.interpolationQuality = .high
    uctx.draw(cimg, in: CGRect(x: 0, y: 0, width: uw, height: uh))
    // PBM P1 ascii: 1 = black (shape). shape = bright pixel
    var s = "P1\n\(uw) \(uh)\n"
    var row = ""
    for yy in 0..<uh { row = ""; for xx in 0..<uw { row += up[yy*uw+xx] > 100 ? "1" : "0" }; s += row + "\n" }
    let name = String(format: "i%02d", n)
    try! s.write(toFile: "\(outDir)/\(name).pbm", atomically: true, encoding: .ascii)
    manifest += "\(name) x=\(x0) y=\(y0) w=\(cw) h=\(ch)\n"
}
try! manifest.write(toFile: "\(outDir)/manifest.txt", atomically: true, encoding: .utf8)
print(manifest)
