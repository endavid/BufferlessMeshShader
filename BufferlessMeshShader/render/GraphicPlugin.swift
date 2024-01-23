//
//  GraphicPlugin.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

import MetalKit

protocol GraphicPlugin {
    var label: String { get }
    func draw(renderer: Renderer, drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer)
}
