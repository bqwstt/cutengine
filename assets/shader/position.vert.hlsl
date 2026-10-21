struct Input {
    float3 Position: TEXCOORD0;
    float3 Normal:   TEXCOORD1;
    float2 TexCoord: TEXCOORD2;
};

struct Output {
    float2 TexCoord:   TEXCOORD0;
    float3 Normal:     TEXCOORD1;
    float3 CurrentPos: TEXCOORD2;
    float3 ViewDir:    TEXCOORD3;
    float4 Position:   SV_Position;
};

cbuffer Camera : register(b0, space1) {
    float3 CameraPosition;
    row_major float4x4 ViewProjection;
};

cbuffer Object : register(b1, space1) { row_major float4x4 Model; };

Output main(Input input)
{
    float4 world = mul(Model, float4(input.Position, 1.0));

    Output output;
    output.TexCoord = input.TexCoord;
    output.Normal = mul((float3x3) Model, input.Normal); // Rotate normals with object
    output.CurrentPos = world;
    output.ViewDir = CameraPosition - world.xyz;
    output.Position = mul(ViewProjection, world);
    return output;
}