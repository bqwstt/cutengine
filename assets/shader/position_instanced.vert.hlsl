struct Input {
    float3 Position: TEXCOORD0;
    float3 Normal:   TEXCOORD1;
    float2 TexCoord: TEXCOORD2;
    uint   InstanceIndex: SV_InstanceID;
};

StructuredBuffer<float4> InstancePositions : register(t0, space0);

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
    float4 local = mul(Model, float4(input.Position, 1.0));
    float4 world = float4(local.xyz + InstancePositions[input.InstanceIndex].xyz, 1.0);

    Output output;
    output.TexCoord = input.TexCoord;
    output.Normal = input.Normal;
    output.CurrentPos = world;
    output.ViewDir = CameraPosition - world.xyz;
    output.Position = mul(ViewProjection, world);
    return output;
}