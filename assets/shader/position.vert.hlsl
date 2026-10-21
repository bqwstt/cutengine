struct Input {
    float3 Position: TEXCOORD0;
    float3 Normal:   TEXCOORD1;
    float2 TexCoord: TEXCOORD2;
};

struct Output {
    float2 TexCoord:   TEXCOORD0;
    float3 Normal:     TEXCOORD1;
    float3 CurrentPos: TEXCOORD2;
    float4 Position:   SV_Position;
};

cbuffer World  : register(b0, space1) { row_major float4x4 view_proj; };
cbuffer Object : register(b1, space1) { row_major float4x4 model; };

Output main(Input input)
{
    float4 world = mul(model, float4(input.Position, 1.0));

    Output output;
    output.TexCoord = input.TexCoord;
    output.Normal = input.Normal;
    output.CurrentPos = world;
    output.Position = mul(view_proj, world);
    return output;
}