//
//  FluxView.swift
//  Flux
//
//  Created by Sander Melnikov on 05/02/2022.
//
import ScreenSaver
import Cocoa
import OpenGL.GL3

class FluxView: ScreenSaverView {
    var pixelFormat: NSOpenGLPixelFormat!
    var openGLContext: NSOpenGLContext!
    var displayLink: CVDisplayLink!
    var flux: OpaquePointer!
    var currentTime = Float32(0.0)
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        
        wantsLayer = true;
        
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAColorSize), UInt32(32),
            UInt32(NSOpenGLPFAOpenGLProfile),
            UInt32(NSOpenGLProfileVersion4_1Core),
            UInt32(0)
          ]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: attributes) else {
            print("Cannot construct OpenGL pixel format.")
            return nil
        }
        self.pixelFormat = pixelFormat
        guard let context = NSOpenGLContext(format: pixelFormat, share: nil) else {
            print("Cannot create OpenGL context.")
            return nil
        }
        context.setValues([1], for: .swapInterval)
        openGLContext = context
        
        displayLink = makeDisplayLink()
    }
    
    // Debug in app
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
      // This is helpful if you need access to window
//    override func viewDidMoveToSuperview()
//    {
//        super.viewDidMoveToSuperview()
//        if let window = superview?.window {
//            displayLink = makeDisplayLink()
//        }
//    }
    
    private func makeDisplayLink() -> CVDisplayLink? {
        func displayLinkOutputCallback(_ displayLink: CVDisplayLink, _ nowPtr: UnsafePointer<CVTimeStamp>, _ outputTimePtr: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
            
            let _self = unsafeBitCast(displayLinkContext, to: FluxView.self)
            _self.animateOneFrame()

            return kCVReturnSuccess
        }
        
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        CVDisplayLinkSetOutputCallback(link!, displayLinkOutputCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(link!, openGLContext!.cglContextObj!, pixelFormat!.cglPixelFormatObj!)
        
        return link
    }
    
    override func lockFocus() {
      super.lockFocus()
      if openGLContext!.view != self {
        openGLContext!.view = self
      }
    }
    
    override class func backingStoreType() -> NSWindow.BackingStoreType {
        return NSWindow.BackingStoreType.buffered
    }
    
    override func startAnimation() {
        // Don’t call super because we’re managing our own timer.
        
        lockFocus()
        openGLContext?.makeCurrentContext()
        
        let size = frame.size
        flux = flux_new(Float(size.width), Float(size.height))
        
        CVDisplayLinkStart(displayLink!)
    }
    
    override func stopAnimation() {
        // Don’t call super. See startAnimation.
        CVDisplayLinkStop(displayLink!)
    }

    private func drawView() -> CVReturn {
        currentTime += 1000.0 * 1.0 / 60.0

        openGLContext.lock()
        openGLContext.makeCurrentContext()

        flux_animate(flux!, currentTime)

        openGLContext.flushBuffer()
        openGLContext.unlock()

        return kCVReturnSuccess
    }
    
    override func animateOneFrame() {
        super.animateOneFrame()
        
        let _ = drawView()
    }
    
    deinit {
        CVDisplayLinkStop(displayLink!)
        flux_destroy(flux!)
    }
}
