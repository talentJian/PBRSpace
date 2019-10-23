#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"

    struct PBSData{
        float metallic;
        float perceptualRoughness;
        float roughness;
    }
    struct SurfaceData
    {
        float3 normal;
        float3 viewDir;
    }
    UnityLight MainLight ()
    {
        UnityLight l;

        l.color = _LightColor0.rgb;
        l.dir = _WorldSpaceLightPos0.xyz;
        return l;
    }
    float4 PBSLighting(SurfaceData s,PBSData pbsData,UnityLight)
    {
        
    }