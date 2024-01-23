//
//  MeshShader.metal
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

#include <metal_stdlib>
using namespace metal;

#if __METAL_VERSION__ < 300
void objectStage();
void meshStage();
fragment float4 fragmentMesh();
#else

struct Vertex
{
    float4 position;
    float4 normal;
    float2 uv;
};

struct VertexOut
{
    float4 position [[position]];
    float3 normal;
    float4 uv;
};
// Per-vertex primitive data.
struct PrimOut
{
    float4 color;
};
struct FragmentIn
{
    VertexOut v;
    PrimOut p;
};

static constexpr constant uint32_t MaxVertexCount = 128;
static constexpr constant uint32_t MaxPrimitiveCount = 128;
using TriangleMeshType = metal::mesh<VertexOut, PrimOut, MaxVertexCount, MaxPrimitiveCount, topology::triangle>;

struct MeshPayload
{
    Vertex vertices[MaxVertexCount];
    float4x4 transform;
    float2 uv;
    float2 size;
    uint32_t primitiveCount;
    uint8_t vertexCount;
};

static constexpr constant float PI = 3.1415926536;

// https://github.com/endavid/VidEngine/blob/master/VidFramework/VidFramework/sdk/math/Matrix.swift
float4x4 frustum(float3 bottomLeftNear, float3 topRightFar)
{
    float l = bottomLeftNear.x;
    float r = topRightFar.x;
    float b = bottomLeftNear.y;
    float t = topRightFar.y;
    float n = bottomLeftNear.z;
    float f = topRightFar.z;
    return float4x4(
        float4(2 * n / (r - l), 0, 0, 0),
        float4(0, 2 * n / (t - b), 0, 0),
        float4((r + l) / (r - l), (t + b) / (t - b), -(f + n) / (f - n), -1),
        float4(0, 0, -2 * f * n / (f - n), 0));
}
float4x4 perspective(float fov, float near, float far, float aspect)
{
    float size = near * tan(0.5 * fov);
    return frustum(float3(-size, -size / aspect, near),
                   float3(size, size / aspect, far));
}
float4x4 rotationY(float angle)
{
    float s=sin(angle), c=cos(angle);
    return float4x4(
        float4(c, 0, -s, 0),
        float4(0, 1, 0, 0),
        float4(s, 0, c, 0),
        float4(0, 0, 0, 1)
    );
}
float4x4 rotationX(float angle)
{
    float s=sin(angle), c=cos(angle);
    return float4x4(
        float4(1, 0, 0, 0),
        float4(0, c, -s, 0),
        float4(0, s, c, 0),
        float4(0, 0, 0, 1)
    );
}

[[object]]
void objectStage(object_data MeshPayload& payload [[payload]],
                 mesh_grid_properties props,
                 uint3 positionInGrid [[threadgroup_position_in_grid]])
{
    const uint32_t gridWidth = 2;
    const uint32_t gridHeight = 2;
    const uint32_t meshWidth = 1;
    const uint32_t meshHeight = 1;
    const uint32_t width = meshWidth * gridWidth;
    const uint32_t height = meshHeight * gridHeight;
    const uint32_t numQuadsPerObject = meshWidth * meshHeight;

    payload.vertexCount = numQuadsPerObject;
    payload.primitiveCount = numQuadsPerObject;
    
    float scaleX = 1.0 / float(width);
    float scaleY = 1.0 / float(height);
    payload.size = float2(scaleX, scaleY);
    uint oi = positionInGrid.x;
    uint oj = positionInGrid.y;
    
    float2 objCenter = float2((2.0 * oi - gridWidth + 1.0)/float(gridWidth),
                              (2.0 * oj - gridHeight + 1.0)/float(gridHeight));
    
    float2 texel = (objCenter + 1.0) * 0.5;
    texel.y = 1.0 - texel.y;
    payload.uv = texel;

    for (uint mj = 0; mj < meshHeight; mj++)
    {
        for (uint mi = 0; mi < meshWidth; mi++)
        {
            uint quadIndex = mj * meshWidth + mi;
            float2 offset = float2((2.0 * mi - meshWidth + 1.0)/float(width),
                                   (2.0 * mj - meshHeight + 1.0)/float(height));
            float2 p = objCenter + offset;
            float2 uv = (p + 1.0) * 0.5;
            uv.y = 1.0 - uv.y;
            payload.vertices[quadIndex].position = float4(0, 0, 0, 1);
            payload.vertices[quadIndex].normal = float4(0,0,1,1);
            payload.vertices[quadIndex].uv = uv;
        }
    }
    // transform
    float aspect = 1;
    float4x4 projection = perspective(0.5, -2, 4, aspect);
    float4x4 view = rotationY(0);
    view[3] = float4(0, 0, -10, 1);
    float t = 0;//uni.time;
    float4x4 modelTr = rotationX(-PI/3.8) * rotationY(-PI/4 + 0.5 * sin(t));
    modelTr[3] = float4(objCenter, 0, 1);
    payload.transform = projection * view * modelTr;
    // Set the output submesh count for the mesh shader.
    // Because the mesh shader is only producing one mesh, the threadgroup grid size is 1 x 1 x 1.
    props.set_threadgroups_per_grid(uint3(1, 1, 1));
}

[[mesh]]
void meshStage(TriangleMeshType output,
               const object_data MeshPayload& payload [[payload]],
               texture2d<float> texA [[ texture(0) ]],
               texture2d<float> texB [[ texture(1) ]],
               sampler sam [[ sampler(0) ]],
               uint lid [[thread_index_in_threadgroup]],
               uint tid [[threadgroup_position_in_grid]])
{
    // tid = 0 always, because there's only one thread per mesh
    // lid = 0..<n ; n triangles per mesh
    if (tid == 0)
    {
        // 6 faces x 2 triangles
        output.set_primitive_count(payload.primitiveCount * 12);
    }
    // Create cube vertices centered around the object position
    if (lid < payload.vertexCount)
    {
        float2 size = payload.size;
        float sizez = max(size.x, size.y);
        for (uint k = 0; k < 2; k++) {
          for (uint i = 0; i < 2; i++) {
            for (uint j = 0; j < 2; j++) {
                uint index = k * 4 + i * 2 + j;
                float4 p = payload.vertices[lid].position;
                p.x = p.x + (2.0 * i - 1.0) * size.x;
                p.y = p.y + (2.0 * j - 1.0) * size.y;
                // right-handed, +Z is front
                p.z = p.z + (-2.0 * k + 1.0) * sizez;
                VertexOut v;
                p = payload.transform * p;
                v.position = p;
                v.normal = payload.vertices[lid].normal.xyz;
                v.uv.xy = payload.vertices[lid].uv;
                v.uv.zw = payload.uv;
                output.set_vertex(8*lid+index, v);
            }
          }
        }
    }
    // Set the constant data for the entire primitive.
    if (lid < payload.primitiveCount)
    {
        int faces[36] = {
            // front
            0, 2, 1, 1, 2, 3,
            // right
            2, 6, 3, 3, 6, 7,
            // left
            4, 0, 5, 5, 0, 1,
            // up
            4, 6, 0, 0, 6, 2,
            // down
            1, 3, 5, 5, 3, 7,
            // back
            6, 4, 7, 7, 4, 5
        };
        float3 colors[6] = {
            float3(151,224,255), // front
            float3(0,111,174), // right
            float3(243,249,131), // left
            float3(92,50,11), // down
            float3(0,161,255), // up
            float3(249,186,0) // back
        };
        uint k = 8 * lid;
        for (uint face = 0; face < 6; face++)
        {
          PrimOut p;
          p.color = float4(colors[face]/255.0, 1.0);
          output.set_primitive(12*lid+2*face, p);
          output.set_primitive(12*lid+2*face+1, p);
          // Set the output indices.
          uint i = 36*lid;
          for (uint j = 0; j < 6; j++)
          {
              uint v = 6 * face + j;
              output.set_index(i+v, k+faces[v]);
          }
        }
    }
}

fragment float4 fragmentMesh(FragmentIn in [[stage_in]])
{
    return in.p.color;
}

#endif
