import AppKit
// Port of mobile-repo ic_launcher_background/foreground.xml (108 × 108 viewport).
let size = 1024
let c = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size * 4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
c.translateBy(x:0,y:1024); c.scaleBy(x:1024/108,y: -1024/108)
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor { CGColor(red:CGFloat((hex >> 16) & 255)/255,green:CGFloat((hex >> 8) & 255)/255,blue:CGFloat(hex & 255)/255,alpha:alpha) }
let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[color(0x1E3A8A),color(0x2563EB),color(0x38BDF8)] as CFArray,locations:[0,0.55,1])!
c.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:108,y:108),options:[])
c.setFillColor(CGColor(gray:1,alpha:20/255)); c.fillEllipse(in:CGRect(x:-18,y:-28,width:92,height:92))
func shield() -> CGPath {
    let p = CGMutablePath(); p.move(to:CGPoint(x:54,y:26))
    p.addCurve(to:CGPoint(x:76,y:33),control1:CGPoint(x:59,y:29.5),control2:CGPoint(x:67.5,y:32))
    p.addCurve(to:CGPoint(x:77,y:37),control1:CGPoint(x:76.6,y:34),control2:CGPoint(x:77,y:35.5)); p.addLine(to:CGPoint(x:77,y:51))
    p.addCurve(to:CGPoint(x:54,y:82),control1:CGPoint(x:77,y:65.5),control2:CGPoint(x:67.5,y:76.5))
    p.addCurve(to:CGPoint(x:31,y:51),control1:CGPoint(x:40.5,y:76.5),control2:CGPoint(x:31,y:65.5)); p.addLine(to:CGPoint(x:31,y:37))
    p.addCurve(to:CGPoint(x:32,y:33),control1:CGPoint(x:31,y:35.5),control2:CGPoint(x:31.4,y:34))
    p.addCurve(to:CGPoint(x:54,y:26),control1:CGPoint(x:40.5,y:32),control2:CGPoint(x:49,y:29.5)); p.closeSubpath(); return p
}
c.saveGState(); c.translateBy(x:0,y:2); c.addPath(shield()); c.setFillColor(color(0x0B1B4D,0.15)); c.fillPath(); c.restoreGState()
c.addPath(shield()); c.setFillColor(CGColor(gray:1,alpha:1)); c.fillPath()
let waves = CGMutablePath()
for r in [CGRect(x:41.5,y:46,width:5,height:14),CGRect(x:51.5,y:42,width:5,height:22),CGRect(x:61.5,y:46,width:5,height:14)] { waves.addRoundedRect(in:r,cornerWidth:2.5,cornerHeight:2.5) }
c.addPath(waves); c.clip()
let waveGradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[color(0x1D4ED8),color(0x38BDF8)] as CFArray,locations:[0,1])!
c.drawLinearGradient(waveGradient,start:CGPoint(x:54,y:42),end:CGPoint(x:54,y:64),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
let bitmap = NSBitmapImageRep(cgImage:c.makeImage()!)
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments.dropFirst().first ?? "Tiskz/Resources/Assets.xcassets/AppIcon.appiconset/Icon.png"))
