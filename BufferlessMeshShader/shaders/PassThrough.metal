//
//  PassThrough.metal
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

#include <metal_stdlib>
using namespace metal;

struct VertexInOut {
    float4  position [[position]];
    float4  color;
    float2  uv;
};

vertex VertexInOut passThrough2DVertex(
  uint vid [[ vertex_id ]],
  constant packed_float4* vdata [[ buffer(0) ]])
{
    VertexInOut outVertex;
    float4 xyuv = vdata[vid];
    outVertex.position = float4(xyuv.xy, 0, 1);
    outVertex.color = float4(1,1,1,1);
    outVertex.uv = xyuv.zw;
    return outVertex;
}

fragment half4 passThroughTexture(VertexInOut inFrag [[stage_in]],
                                  texture2d<float> tex [[ texture(0) ]],
                                  sampler sam [[ sampler(0) ]])
{
    float4 color = tex.sample(sam, inFrag.uv);
    return half4(color);
}
