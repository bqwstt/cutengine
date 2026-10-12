struct Input {
    float3 Position: TEXCOORD0;
    float2 TexCoord: TEXCOORD1;
    uint   InstanceIndex: SV_InstanceID;
};

StructuredBuffer<float4> InstancePositions : register(t0, space0);

struct Output {
    float2 TexCoord: TEXCOORD0;
    float4 ObjectColor: TEXCOORD1;
    float4 Position: SV_Position;
};

cbuffer World  : register(b0, space1) { row_major float4x4 view_proj; };
cbuffer Object : register(b1, space1) { row_major float4x4 model; };

Output main(Input input)
{
    float4 local = mul(model, float4(input.Position, 1.0));
    float4 world = float4(local.xyz + InstancePositions[input.InstanceIndex].xyz, 1.0);

    Output output;
    output.TexCoord = input.TexCoord;
    output.ObjectColor = float4(1.0, 1.0, 1.0, 1.0);
    output.Position = mul(view_proj, world);
    return output;
}