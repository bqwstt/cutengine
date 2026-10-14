Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

struct Input {
    float2 TexCoord:    TEXCOORD0;
    float4 ObjectColor: TEXCOORD1;
    float3 Normal:      TEXCOORD2;
    float3 CurrentPos:  TEXCOORD3;
};

struct Output {
    float4 Color: SV_Target0;
};

struct LightSource {
    float3 Pos;
    float4 Color;
};

cbuffer Light : register(b0, space3) { LightSource Light; };

Output main(Input input)
{
    float3 normal = normalize(input.Normal);
    float3 light_direction = normalize(Light.Pos - input.CurrentPos);

    float diffuse = max(dot(normal, light_direction), 0.0f);
    float4 base_color = Texture.Sample(Sampler, input.TexCoord) * input.ObjectColor;

    Output output;
    output.Color = float4(base_color.rgb * diffuse * Light.Color.rgb, base_color.a);
    return output;
}