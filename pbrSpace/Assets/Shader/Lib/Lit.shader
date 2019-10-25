//Built版本的Pbr
Shader "ZShader/PBR/Lit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        _Metallic("Metallic",Range(0,1)) = 0.5
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
                #if UNITY_COLORSPACE_GAMMA
                _Color = pow(_Color,2.2);
                #endif
                float4 albedo = tex2D(_MainTex,i.uv) * _Color;
                //albedo = pow(albedo,0.45);
                SurfaceData s;
                s.normal =  normalize(i.worldNormal);
                s.viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                s.albedo = albedo;

                s.metallic = _Metallic;
                s.perceptualRoughness = 1- _Smoothness;
                s.roughness = clamp(s.perceptualRoughness * s.perceptualRoughness,0.001,1);
                s.reflectivity = lerp(0.04,1.0,_Metallic);
                s.specular = lerp(0.04,s.albedo.rgb,s.metallic); //FO
                UnityLight mainLight = MainLight();
                
                float3 pbsLight = PBSLighting(s,mainLight) ;

               
                
                

                float4 color = float4(pbsLight,1);
                #ifdef UNITY_COLORSPACE_GAMMA
                    color = pow(color,1/2.2);
                #endif
                
                return color;
            }
            ENDCG
        }
    }
}
