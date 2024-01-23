//
//  TextureUtils.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

import MetalKit

class TextureUtils {
    class func createRenderTargetTexture(device: MTLDevice, pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead, .pixelFormatView]
        return device.makeTexture(descriptor: desc)
    }
}
