//
//  MeshPlugin.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

import MetalKit

class MeshPlugin: GraphicPlugin {
    private var renderState: MTLRenderPipelineState! = nil
    private var depthState: MTLDepthStencilState?
    private var pipelineDesc = MTLMeshRenderPipelineDescriptor()
        
    var label: String {
        get {
            return "MeshPlugin"
        }
    }
    
    func createDepthDescriptor() -> MTLDepthStencilDescriptor {
        let desc = MTLDepthStencilDescriptor()
        desc.isDepthWriteEnabled = true
        desc.depthCompareFunction = .less
        return desc
    }
    
    init(renderer: Renderer, view: MTKView, library: MTLLibrary, objectFn: MTLFunction? = nil, meshFn: MTLFunction? = nil, fragmentFn: MTLFunction? = nil) {
        pipelineDesc.objectFunction = objectFn ?? library.makeFunction(name: "objectStage")!
        pipelineDesc.meshFunction = meshFn ?? library.makeFunction(name: "meshStage")!
        pipelineDesc.fragmentFunction = fragmentFn ?? library.makeFunction(name: "fragmentMesh")!
        pipelineDesc.maxTotalThreadgroupsPerMeshGrid = 64
        pipelineDesc.maxTotalThreadsPerMeshThreadgroup = 64
        pipelineDesc.maxTotalThreadsPerObjectThreadgroup = 64
        pipelineDesc.colorAttachments[0].pixelFormat = renderer.outputTexture.pixelFormat
        pipelineDesc.colorAttachments[0].isBlendingEnabled = false
        pipelineDesc.rasterSampleCount = view.sampleCount
        initRenderState(renderer: renderer)
    }
    
    private func initRenderState(renderer: Renderer) {
        do {
            try (renderState, _) = renderer.device.makeRenderPipelineState(descriptor: pipelineDesc, options: MTLPipelineOption())
            if pipelineDesc.depthAttachmentPixelFormat == .invalid {
                depthState = nil
            } else {
                let depthDesc = createDepthDescriptor()
                depthState = renderer.device.makeDepthStencilState(descriptor: depthDesc)
            }
        } catch let error {
            NSLog("Failed to create pipeline state: \(error.localizedDescription)")
        }
    }
    
    private func updatePipelineDesc(renderer: Renderer) -> Bool {
        var changed = false
        if renderer.outputTexture.pixelFormat != pipelineDesc.colorAttachments[0].pixelFormat {
            // we allow changes in the pixel format of the output buffer
            pipelineDesc.colorAttachments[0].pixelFormat = renderer.outputTexture.pixelFormat
            changed = true
        }
        let depthAttachmentPixelFormat = renderer.depthTexture?.pixelFormat ?? .invalid
        if pipelineDesc.depthAttachmentPixelFormat != depthAttachmentPixelFormat {
            pipelineDesc.depthAttachmentPixelFormat = depthAttachmentPixelFormat
            changed = true
        }
        return changed
    }
    
    func draw(renderer: Renderer, drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
        if updatePipelineDesc(renderer: renderer) {
            initRenderState(renderer: renderer)
        }
        let desc = renderer.createDefaultRenderPass(clear: true, clearColor: MTLClearColor())
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else {
            return
        }
        encoder.label = self.label
        if let depthState = self.depthState {
            encoder.setDepthStencilState(depthState)
        }
        encoder.setRenderPipelineState(renderState)
        encoder.setCullMode(renderer.is3D ? .back : .none)
        encoder.setFrontFacing(.counterClockwise)
        let oGroups = MTLSize(width: 2, height: 2, depth: 1)
        let oThreads = MTLSize(width: 1, height: 1, depth: 1)
        let mThreads = MTLSize(width: 1, height: 1, depth: 1)
        encoder.drawMeshThreads(oGroups, threadsPerObjectThreadgroup: oThreads, threadsPerMeshThreadgroup: mThreads)
        encoder.endEncoding()
    }
}
