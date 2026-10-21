Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

struct Input {
    float2 TexCoord:    TEXCOORD0;
    float3 Normal:      TEXCOORD1;
    float3 CurrentPos:  TEXCOORD2;
};

struct Output {
    float4 Color: SV_Target0;
};

struct LightSource {
    float3 Pos;
    float4 Color;
};

cbuffer Light : register(b0, space3) { LightSource Light; };
cbuffer Material : register(b1, space3) { float4 BaseColor; }

Output main(Input input)
{
    float3 normal = normalize(input.Normal);
    float3 light_direction = normalize(Light.Pos - input.CurrentPos);
    float diffuse = max(dot(normal, light_direction), 0.0f);

    float4 albedo = Texture.Sample(Sampler, input.TexCoord) * BaseColor;

    Output output;
    output.Color = float4(albedo.rgb * diffuse * Light.Color.rgb, albedo.a);
    return output;
}