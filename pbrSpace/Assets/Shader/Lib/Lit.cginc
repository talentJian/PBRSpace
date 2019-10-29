///实现learnOpenGL中的PBR
#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityGlobalIllumination.cginc"
//#include "UnityImageBasedLighting.cginc"
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

    float reflectivity;
    float fresnelStrength;
    float3 specular; //这个应该理解为F0
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

//已经定义了
// half3 FresnelLerp(half3 F0, half3 F90, half cosA)
// {
//     half t = Pow5 (1 - cosA);   // ala Schlick interpoliation
//     return lerp (F0, F90, t);
// }

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
    
    return NdotV / denom ;
}

//合并 viewDir 和 lightDir的 G
float GeometrySmith(float3 normal,float NdotV,float NdotL,float k)
{

    float ggx1 = GeometrySchlickGGX(NdotV,k);
    float ggx2 = GeometrySchlickGGX(NdotL,k);

    return ggx1 * ggx2;
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
    // if(s.perfectDiffuser)
    // {
    //     return 0;
    // }

    //采样ibl 
    float3 reflectVector = reflect(-s.viewDir,s.normal);
    float mip = perceptualRoughnessToMipmapLevel(s.perceptualRoughness);
    half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVector, mip);
    float3 environment = DecodeHDR(rgbm, unity_SpecCube0_HDR);
    #ifdef UNITY_COLORSPACE_GAMMA
        environment = pow(environment,2.2);
    #endif

    float fresnel = Pow4(1.0 - saturate(dot(s.normal,s.viewDir)));
    float fresnelStrength = saturate(1-s.perceptualRoughness + s.reflectivity);
    environment *= lerp(s.specular,fresnelStrength,fresnel); // 如果是 perfectDiffuse, 这里会是全黑
    environment /= s.roughness * s.roughness + 1.0;  //这样可以减弱了 rouhness 的不同范围在 envirmont * [0.5,1]
    return environment;
}

// DFG/ 4(NDOTL)*(NDOTV)

float3 PBSLighting(SurfaceData s,UnityLight light)
{
    float3 halfDir = normalize(light.dir + s.viewDir);
    float HDOTV = saturate(dot(halfDir,s.viewDir));
    float NDOTL = saturate(dot(s.normal,light.dir));
    float NDOTV = saturate(dot(s.normal,s.viewDir));
    float LDOTH = saturate(dot(light.dir,halfDir));

    float NDF = DistributionGGX(s.normal,halfDir,s.roughness);
    float k = (s.perceptualRoughness + 1) * (s.perceptualRoughness + 1) /8;
    float G = GeometrySmith(s.normal,NDOTV,NDOTL,k);
    
    
   
    
    float3 fresnelTerm = FresnelSchilick(HDOTV,s.specular);

    float3 ks = fresnelTerm;
    float3 kd = 1-ks;
    kd *= 1 - s.metallic;
    
    float3 diffuseTerm = kd * s.albedo.rgb ; //这里按照Unity的不除以PI
    float3 specularTerm = (NDF * G * fresnelTerm) / max(4 * (NDOTL * NDOTV),0.001) ;
    float3 BRDF = (diffuseTerm + specularTerm) * NDOTL * light.color; //TODO: 灯光的衰减 


    float3 sh = 0;
    //#if UNITY_SHOULD_SAMPLE_SH
        sh= MShadeSH9(float4(s.normal,1)) * kd * s.albedo.rgb; //indirect diffuse Light,可以使用envMap,Unity这里使用的就是SH
    //#endif
    //IBL部分

    float3 IBLColor = ReflectEnvironment(s); //indirect specular

    return  BRDF  + IBLColor +sh;
}



