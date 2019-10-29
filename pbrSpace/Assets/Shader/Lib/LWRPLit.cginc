///实现learnOpenGL中的PBR
#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityGlobalIllumination.cginc"
//#include "UnityImageBasedLighting.cginc"
struct PBSData{
    
};
struct SurfaceData
{  
    float3 position;
    float3 normal;
    float3 viewDir;
    float4 albedo;
    float metallic;
    float perceptualRoughness;
    float roughness;

    float reflectivity;
    float fresnelStrength;
    float3 specular; //这个应该理解为F0
    float3 diffuse; //这里一般放着 albedo * kd 

    float alpha;
};
UnityLight MainLight ()
{
    UnityLight l;

    l.color = _LightColor0.rgb;
#if UNITY_COLORSPACE_GAMMA
    l.color = pow(l.color,2.2);
#endif
    l.dir = _WorldSpaceLightPos0.xyz;
    return l;
}

SurfaceData GetLitSurface(float3 normal,float3 position,float3 viewDir,
float3 color,float metallic,float smoothness,half alpha,bool perfectDiffuser = false)
{
    SurfaceData s;
    s.normal = normal;
    s.position = position;
    s.viewDir = viewDir;
    s.diffuse = color;
    //完美的Diffuse
    if(perfectDiffuser)
    { 
        s.reflectivity = 0;
        s.specular = 0.0;
        smoothness = 0.0;
    }else{
        s.specular = lerp(0.04,color,metallic);//F0
        s.reflectivity = lerp(0.04,1.0,metallic);
        s.diffuse *=1.0 - s.reflectivity; //金属越强，漫反射越低~ //
    }
    s.fresnelStrength = saturate(smoothness + s.reflectivity); //反射和平滑度一起影响菲涅尔的强度
    s.perceptualRoughness = 1.0 - smoothness;
    // s.roughness = s.perceptualRoughness *s.perceptualRoughness;
    s.roughness = clamp(s.perceptualRoughness * s.perceptualRoughness,0.001,1);

    #if _ALPHAPREMULTIPLY_ON
    s.diffuse *= alpha;
    s.alpha = alpha * (1-s.reflectivity) + s.reflectivity;
    #endif
    return s;
}

// normal should be normalized, w=1.0
// output in active color space
half3 MShadeSH9 (half4 normal)
{
    // Linear + constant polynomial terms
    half3 res = SHEvalLinearL0L1 (normal);

    // Quadratic polynomials
    res += SHEvalLinearL2 (normal);

// #   ifdef UNITY_COLORSPACE_GAMMA
//         res = LinearToGammaSpace (res);
// #   endif

    return res;
}


//----Unity的IBL部分
float3 ReflectEnvironment(SurfaceData s)
{
    //采样ibl 
    float3 reflectVector = reflect(-s.viewDir,s.normal);
    float mip = perceptualRoughnessToMipmapLevel(s.perceptualRoughness);
    half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVector, mip);
    float3 environment = DecodeHDR(rgbm, unity_SpecCube0_HDR);


    float fresnel = Pow4(1.0 - saturate(dot(s.normal,s.viewDir)));
    float fresnelStrength = saturate(1-s.perceptualRoughness + s.reflectivity);
    environment *= lerp(s.specular,fresnelStrength,fresnel); // 如果是 perfectDiffuse, 这里会是全黑
    environment /= s.roughness * s.roughness + 1.0;  //这样可以减弱了 rouhness 的不同范围在 envirmont * [0.5,1]
    return environment;
}


//采样GI 相关
//实时则采样light probe
//否则采样Lightmap,这里不考虑 substractive的阴影
half3 SampleGI(SurfaceData s)
{
    half3 gi = 0;
    #ifdef LIGHTMAP_ON
        half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
        half3 bakedColor = DecodeLightmap(bakedColorTex);
        gi = bakedColor;
    #else
        half3 sh= MShadeSH9(float4(s.normal,1)) * s.diffuse;
        gi = sh;
    #endif
    return gi;
}

// half3 SampleLightmap(float2 lightmapUV)
// {
//     fixed3 lmcol = DecodeLightmap(unity_Lightmap,lightmapUV);
//     return lmcol;
// }

//LWRP使用的BRDF
half3 LWRPPBSLighting(SurfaceData s,UnityLight light)
{
    half3 halfDir = normalize(light.dir + s.viewDir);
    half NdotH = saturate(dot(s.normal,halfDir));
    half LdotH = saturate(dot(light.dir,halfDir));
    half NDotL = saturate(dot(s.normal,light.dir));
    half d = NdotH * NdotH * (s.roughness*s.roughness-1) + 1.00001h;

    half LdotH2 = LdotH * LdotH;

    half normalizationTerm = (s.roughness+0.5)*4;
    half specurlarTerm = (s.roughness*s.roughness) / ((d*d)*max(0.1h,LdotH2) * normalizationTerm);

    half3 BRDF = ((specurlarTerm * s.specular) + s.diffuse);

    //放在外面加
    // half3 sh= MShadeSH9(float4(s.normal,1)) * s.diffuse; //indirect diffuse
    // half3 IBLColor = ReflectEnvironment(s); //indirect specular
    return BRDF* NDotL * light.color;
}