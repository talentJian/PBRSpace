﻿//Built版本的Pbr
Shader "ZShader/PBR/Lit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Smoothness("Smoothness",Range(0,1)) = 0.5
        _Metallic("Metallic",Range(0,1)) = 0.5

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode" = "FORWARDBASE"}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lit.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal :NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos :TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _Smoothness;
            float _Metallic;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                float4 albedo = tex2D(_MainTex,i.uv);
                SurfaceData s;
                s.normal =  normalize(i.worldNormal);
                s.viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                s.albedo = albedo;

                s.metallic = _Metallic;
                s.perceptualRoughness = 1- _Smoothness;
                s.roughness = s.perceptualRoughness * s.perceptualRoughness;

                UnityLight mainLight = MainLight();
                
                float3 pbsLight = PBSLighting(s,mainLight) * mainLight.color;

                float4 color = float4(pbsLight,1);
                // color = pow(color,1/2.2);
                return color;
            }
            ENDCG
        }
    }
}
