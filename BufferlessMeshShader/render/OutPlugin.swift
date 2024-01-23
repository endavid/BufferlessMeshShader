//
//  OutPlugin.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

import MetalKit

class OutPlugin: GraphicPlugin {
    private var renderState: MTLRenderPipelineState! = nil
    
    var label: String {
        get {
            return "OutPlugin"
        }
    }
    
    static private func createDesc(library: MTLLibrary, pixelFormat: MTLPixelFormat, fragment: String) -> MTLRenderPipelineDescriptor {
        let desc = MTLRenderPipelineDescriptor()
        desc.fragmentFunction = library.makeFunction(name: fragment)!
        desc.vertexFunction = library.makeFunction(name: "passThrough2DVertex")!
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].rgbBlendOperation = .add
        desc.colorAttachments[0].alphaBlendOperation = .add
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .one
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return desc
    }

    init(renderer: Renderer, library: MTLLibrary, view: MTKView) {
        let desc = OutPlugin.createDesc(library: library, pixelFormat: view.colorPixelFormat, fragment: "passThroughTexture")
        do {
            try renderState = renderer.device.makeRenderPipelineState(descriptor: desc)
        } catch let error {
            NSLog("Failed to create pipeline state: \(error.localizedDescription)")
        }
    }
    
    func draw(renderer: Renderer, drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
        let desc = renderer.createRenderPassWithColorAttachmentTexture(drawable.texture, clear: true)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else {
            return
        }
        encoder.label = self.label
        encoder.setRenderPipelineState(renderState)
        encoder.setFragmentTexture(renderer.outputTexture, index: 0)
        encoder.setFragmentSamplerState( renderer.textureSamplers.samplers[.pointWithClamp]!, index: 0)
        renderer.fullScreenQuad.draw(encoder: encoder)
        encoder.endEncoding()
    }
}

