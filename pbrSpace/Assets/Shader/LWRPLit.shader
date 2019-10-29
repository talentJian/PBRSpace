Shader "ZShader/PBR/LWRPLit"
{
    Properties
    {
         _MainTex ("Texture", 2D) = "white" {}
        
        [Gamma]_Metallic("Metallic",Range(0,1)) = 0.5 //标记了Gamma的话，会吧外面的颜色 当做Gamma.45 所以回自动 pow2.2 转到了Gamma1.0下
        _Smoothness("Smoothness",Range(0,1)) = 0.5
        _Color("_Color",Color) = (1,1,1,1)
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
            #include "Lib/LWRPLit.cginc"
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
            float4 _Color;
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
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                float3 normal = normalize(i.worldNormal);
                float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                SurfaceData s = GetLitSurface(normal,i.worldPos,viewDir,col,_Metallic,_Smoothness);
                UnityLight light = MainLight();
                float3 lightColor = LWRPPBSLighting(s,light);
                return fixed4(lightColor,1);
            }
            ENDCG
        }
    }
}
