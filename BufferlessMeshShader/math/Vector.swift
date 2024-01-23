//
//  Vector.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

import simd

public struct Vec4 {
    let x : Float
    let y : Float
    let z : Float
    let w : Float
    init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    init(_ v: simd_float4) {
        self.x = v.x
        self.y = v.y
        self.z = v.z
        self.w = v.w
    }
}
