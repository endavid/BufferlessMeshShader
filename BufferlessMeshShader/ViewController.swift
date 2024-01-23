//
//  ViewController.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

import MetalKit

class ViewController: NSViewController, MTKViewDelegate {
    let inflightSemaphore = DispatchSemaphore(value: 0)
    var device: MTLDevice! = nil
    var commandQueue: MTLCommandQueue!
    var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        device = MTLCreateSystemDefaultDevice()
        guard device != nil else {
            // Fallback to a blank view.
            // An application could also fallback to OpenGL ES here.
            NSLog("Metal is not supported on this device")
            self.view = NSView(frame: self.view.frame)
            return
        }
        let view = self.view as! MTKView
        view.device = device
        view.delegate = self
        commandQueue = device.makeCommandQueue()
        commandQueue.label = "main command queue"
        // init with 0 and send 3 signals on init to fix crash when closing window
        // https://forums.developer.apple.com/forums/thread/126781
        // https://lists.apple.com/archives/cocoa-dev/2014/Apr/msg00485.html
        for _ in 0..<Renderer.numSyncBuffers {
            inflightSemaphore.signal()
        }
    }
    
    override func viewWillAppear() {
        if device == nil {
            return
        }
        if renderer == nil {
            // already added in viewDidLoad, but if we dismissed the view and present it again, this will be necessary
            let view = self.view as! MTKView
            renderer = Renderer(device, view: view, width: 512, height: 512)
            // this flag will set the depth buffer and the backface culling
            renderer.is3D = true
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // MARK: MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // handle drawable size changes as necessary
    }
    
    func draw(in view: MTKView) {
        // use semaphore to encode 3 frames ahead
        let _ = inflightSemaphore.wait(timeout: DispatchTime.distantFuture)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        // use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use capture list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            self?.inflightSemaphore.signal()
        }
        renderer.draw(view, commandBuffer: commandBuffer)
    }

}

