//
//  Renderer.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//
import MetalKit

public class Renderer {
    // triple buffer so we can update stuff in the CPU while the GPU renders for 3 frames
    static let numSyncBuffers = 3
    var device : MTLDevice! = nil
    let textureSamplers: TextureSamplers
    
    private var _outputTexture: MTLTexture! = nil
    private var _depthTexture: MTLTexture?
    /// My "Render Graph" is just an ordered list 😅
    private var plugins : [GraphicPlugin] = []
    private lazy var _fullScreenQuad : FullScreenQuad = {
        return FullScreenQuad(renderer: self)
    }()
    
    var clearColor = MTLClearColorMake(38/255, 35/255, 35/255, 1.0)
    
    var fullScreenQuad : FullScreenQuad {
        get {
            return _fullScreenQuad
        }
    }
    var outputTexture: MTLTexture {
        get {
            return _outputTexture
        }
    }
    var depthTexture: MTLTexture? {
        get {
            return _depthTexture
        }
    }
    var is3D: Bool {
        get {
            return _depthTexture != nil
        }
        set {
            if newValue {
                if _depthTexture == nil {
                    createDepthTexture()
                }
            } else {
                _depthTexture = nil
            }
        }
    }
    
    func getPlugin<T>() -> T? {
        for p in plugins {
            if p is T {
                return p as? T
            }
        }
        return nil
    }
    
    private func createDepthTexture() {
        let width = outputTexture.width
        let height = outputTexture.height
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        depthDesc.usage = [.renderTarget]
        depthDesc.storageMode = .private
        let depthTexture = device.makeTexture(descriptor: depthDesc)!
        depthTexture.label = "Depth"
        _depthTexture = depthTexture
    }
    
    
    init(_ device: MTLDevice, view: MTKView, width: Int, height: Int) {
        self.device = device
        _outputTexture = TextureUtils.createRenderTargetTexture(device: device, pixelFormat: .rgba8Unorm_srgb, width: width, height: height)
        textureSamplers = TextureSamplers(device: device)
        initGraphicPlugins(view)
    }
    
    func initGraphicPlugins(_ view: MTKView) {
        guard let library = device.makeDefaultLibrary() else {
            logDebug("Failed to create shader library")
            return
        }
        plugins = []
        plugins.append(MeshPlugin(renderer: self, view: view, library: library))
        plugins.append(OutPlugin(renderer: self, library: library, view: view))
    }
    
    func draw(_ view: MTKView, commandBuffer: MTLCommandBuffer) {
        guard let currentDrawable = view.currentDrawable else {
            return
        }
        for plugin in plugins {
            plugin.draw(renderer: self, drawable: currentDrawable, commandBuffer: commandBuffer)
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    // MARK: Render passes
    
    func createRenderPassWithColorAttachmentTexture(_ texture: MTLTexture, clear: Bool, color: MTLClearColor? = nil) -> MTLRenderPassDescriptor {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = texture
        renderPass.colorAttachments[0].loadAction = clear ? .clear : .load
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = color ?? clearColor
        return renderPass
    }
    
    func createDefaultRenderPass(clear: Bool, clearColor: MTLClearColor? = nil, clearDepth: Double = 1.0) -> MTLRenderPassDescriptor {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = outputTexture
        renderPass.colorAttachments[0].loadAction = clear ? .clear : .load
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = clearColor ?? self.clearColor
        if let tex = _depthTexture {
            renderPass.depthAttachment.texture = tex
            renderPass.depthAttachment.loadAction = clear ? .clear : .load
            renderPass.depthAttachment.storeAction = .store
            renderPass.depthAttachment.clearDepth = clearDepth
        }
        return renderPass

    }

    // MARK: Buffers
    
    func createIndexBuffer(_ label: String, elements: [UInt16]) -> MTLBuffer {
        let buffer = device.makeBuffer(bytes: elements, length: elements.count * MemoryLayout<UInt16>.size, options: MTLResourceOptions())
        buffer?.label = label
        return buffer!
    }
}

