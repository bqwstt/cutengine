Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

struct Input {
    float2 TexCoord:    TEXCOORD0;
    float3 Normal:      TEXCOORD1;
    float3 CurrentPos:  TEXCOORD2;
    float3 ViewDir:     TEXCOORD3;
};

struct Output {
    float4 Color: SV_Target0;
};

struct LightSource {
    float3 Pos;
    float4 Color;
};

cbuffer Light : register(b0, space3) { 
    LightSource Light;
    float AmbientStrength; // Used to create a color.
};

cbuffer Material : register(b1, space3) {
    float4 BaseColor;
    float  SpecularStrength; // Used to create a color.
    uint   Shininess;
}

// Toon shading:
// * https://roystan.net/articles/toon-shader/
Output main(Input input)
{
    float3 normal = normalize(input.Normal);
    float3 light_direction = normalize(Light.Pos - input.CurrentPos);
    float n_dot_l = dot(normal, light_direction);
    float light_intensity = smoothstep(0, 0.05, n_dot_l);

    float3 view_dir = normalize(input.ViewDir);
    float3 half_vector = normalize(light_direction + view_dir);
    float n_dot_h = dot(normal, half_vector);
    float specular_intensity = pow(n_dot_h * light_intensity, Shininess * Shininess);
    float specular_intensity_smooth = smoothstep(0.005, 0.01, specular_intensity);
    float4 specular = specular_intensity_smooth * float4(SpecularStrength.xxx, 1.0);

    float4 rim_dot = 1 - dot(view_dir, normal);
    float rim_amount = smoothstep(0.715, 0.720, rim_dot);

    float4 albedo = BaseColor * Texture.Sample(Sampler, input.TexCoord);
    float4 ambient = float4(AmbientStrength.xxx, 1.0);
    float4 light = light_intensity * Light.Color;

    Output output;
    output.Color = float4(albedo.rgb * (ambient + light + specular + rim_amount), albedo.a);
    return output;
}