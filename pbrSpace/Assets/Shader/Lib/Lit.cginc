///实现learnOpenGL中的PBR
#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityGlobalIllumination.cginc"
struct PBSData{
    
};
struct SurfaceData
{
    float3 normal;
    float3 viewDir;
    float4 albedo;
    float metallic;
    float perceptualRoughness;
    float roughness;

    float fresnelStrength;
    float specular; //这个应该理解为F0
};
UnityLight MainLight ()
{
    UnityLight l;

    l.color = _LightColor0.rgb;
    l.dir = _WorldSpaceLightPos0.xyz;
    return l;
}


float3 FresnelSchilick(float HDOTV,float3 F0)
{
    return F0 + (1-F0) * pow(1.0 - HDOTV,5.0);    
}

//NDF
float DistributionGGX(float3 normal,float3 halfDir,float a)
{
    float a2 = a*a;
    float NDOTH = saturate(dot(normal,halfDir));
    float denom = ((NDOTH * NDOTH) * (a2-1)+1);
    denom = UNITY_PI * denom * denom;
    return a2 / denom;
}

//GF
float GeometrySchlickGGX(float NdotV,float k)
{
    float denom = NdotV * (1-k)+k;
    
    return NdotV / denom;
}

//合并 viewDir 和 lightDir的 G
float GeometrySmith(float3 normal,float NdotV,float NdotL,float k)
{

    float ggx1 = GeometrySchlickGGX(NdotV,k);
    float ggx2 = GeometrySchlickGGX(NdotL,k);

    return ggx1 * ggx2;
}


// DFG/ 4(NDOTL)*(NDOTV)

float3 PBSLighting(SurfaceData s,UnityLight light)
{
    float3 halfDir = normalize(light.dir + s.viewDir);
    float HDOTV = saturate(dot(halfDir,s.viewDir));
    float NDOTL = saturate(dot(s.normal,light.dir));
    float NDOTV = saturate(dot(s.normal,s.viewDir));
    
    float NDF = DistributionGGX(s.normal,halfDir,s.roughness);
    // float k = (pbsData.roughness + 1) * (pbsData.roughness + 1) /8;
    float G = GeometrySmith(s.normal,NDOTV,NDOTL,s.perceptualRoughness);
    
    
    float3 F0 = lerp(0.04,s.albedo.rgb,s.metallic);
    
    float3 fresnelTerm = FresnelSchilick(HDOTV,F0);

    float3 ks = fresnelTerm;
    float3 kd = 1-ks;
    kd *= 1 - s.metallic;
    
    float3 diffuseTerm = kd * s.albedo.rgb /UNITY_PI;
    float3 specularTerm = (NDF * G * fresnelTerm) / max(4 * (NDOTL * NDOTV),0.001) ;
    float3 BRDF = (diffuseTerm + specularTerm) * NDOTL; //灯光的衰减在外面乘。。
    return BRDF;
}

//----Unity的IBL部分
float3 ReflectEnvironment(SurfaceData s,float3 environment)
{
    // if(s.perfectDiffuser)
    // {
    //     return 0;
    // }
    float fresnel = Pow4(1.0 - saturate(dot(s.normal,s.viewDir)));
    environment *= lerp(s.specular,s.fresnelStrength,fresnel); // 如果是 perfectDiffuse, 这里会是全黑
    environment /= s.roughness * s.roughness + 1.0;  //这样可以减弱了 rouhness 的不同范围在 envirmont * [0.5,1]
    return environment;
}