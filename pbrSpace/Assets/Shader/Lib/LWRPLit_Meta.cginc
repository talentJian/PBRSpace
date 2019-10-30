#ifndef UNITY_LWRPLIT_META_INCLUDED
#define UNITY_LWRPLIT_META_INCLUDED
#include "UnityCG.cginc"
#include "LWRPLit.cginc"
#include "UnityMetaPass.cginc"

struct VertexInput
{
    float4 vertex : POSITION;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;

};

struct v2f_meta
{
    float4 pos      : SV_POSITION;
    float2 uv       : TEXCOORD0;
#ifdef EDITOR_VISUALIZATION
    float2 vizUV        : TEXCOORD1;
    float4 lightCoord   : TEXCOORD2;
#endif
};

#endif

float4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _LightTex; 
float _Smoothness;
float _Metallic;
float3 _EmissiveColor;
v2f_meta vert_meta (VertexInput v)
{
    v2f_meta o;
    o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
    o.uv = TRANSFORM_TEX(v.uv0,_MainTex);
#ifdef EDITOR_VISUALIZATION
    o.vizUV = 0;
    o.lightCoord = 0;
    if (unity_VisualizationMode == EDITORVIZ_TEXTURE)
        o.vizUV = UnityMetaVizUV(unity_EditorViz_UVIndex, v.uv0.xy, v.uv1.xy, v.uv2.xy, unity_EditorViz_Texture_ST);
    else if (unity_VisualizationMode == EDITORVIZ_SHOWLIGHTMASK)
    {
        o.vizUV = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
        o.lightCoord = mul(unity_EditorViz_WorldToLight, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)));
    }
#endif
    return o;
}


float4 frag_meta (v2f_meta i) : SV_Target
{
    float4 albedo = tex2D(_MainTex,i.uv) * _Color;
    LightTexData lightTexData = UnPackLightTex(_LightTex,i.uv,_Metallic,_Smoothness);
    half metallic = lightTexData.metallic;
    half smoothness = lightTexData.smoothness; 
    half emissiveMask = lightTexData.emissiveMask;
    float4 meta = 0;
    if(unity_MetaFragmentControl.x)
    {
        SurfaceData surface = GetLitSurfaceMeta(albedo.rgb,metallic,smoothness);
        meta = float4(surface.diffuse,1);
        //The idea behind this is that highly specular but rough materials also pass along some indirect light.
        meta.rgb += surface.specular * surface.roughness * 0.5;
        
        //这里的参数参考Unity默认，应该是给烘焙参数使用的 Lightmap参数中有 AlbedoBoost 可以调整强度~
        meta.rgb = clamp(pow(meta.rgb,unity_OneOverOutputBoost),0,unity_MaxOutputValue);
    }
    if (unity_MetaFragmentControl.y) {

        float3 emissiveColor = _EmissiveColor * emissiveMask;
		meta = float4(emissiveColor , 1);
	}
    return meta;
}