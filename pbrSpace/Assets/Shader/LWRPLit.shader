Shader "ZShader/PBR/LWRPLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _LightTex("Metallic (R) Smooth(A)",2D) = "white" {}
        _BumpMap("BumpMap",2D) = "bump"{}
        [Gamma]_Metallic("Metallic",Range(0,1)) = 0.5 //标记了Gamma的话，会吧外面的颜色 当做Gamma.45 所以回自动 pow2.2 转到了Gamma1.0下
        _Smoothness("Smoothness",Range(0,1)) = 0.5
        _Color("_Color",Color) = (1,1,1,1)


        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightMode" = "FORWARDBASE"}

        Pass
        {
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            
            #pragma shader_feature _METALLICGLOSSMAP
            //预乘Alpha,做玻璃的时候 预乘很重要
            #pragma shader_feature _ALPHAPREMULTIPLY_ON 
            #include "UnityCG.cginc"
            #include "Lib/LWRPLit.cginc"
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal :NORMAL;
                float4 tangent :TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                

                float4 TtoW0 :TEXCOORD2;
                float4 TtoW1 :TEXCOORD3;
                float4 TtoW2 :TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _LightTex;            
            sampler2D _BumpMap;

            float _Smoothness;
            float _Metallic;
            float4 _Color;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                half3 worldPos = mul(unity_ObjectToWorld,v.vertex);

                half3 worldTangent = UnityObjectToWorldDir(v.tangent);
                half3 bitnormal = cross(o.worldNormal,worldTangent) * v.tangent.w;
                o.TtoW0 = float4(worldTangent.x,bitnormal.x,o.worldNormal.x,worldPos.x);
                o.TtoW1 = float4(worldTangent.y,bitnormal.y,o.worldNormal.y,worldPos.y);
                o.TtoW2 = float4(worldTangent.z,bitnormal.z,o.worldNormal.z,worldPos.z);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                fixed alpha = col.a * _Color.a;
                half3 worldPos = half3(i.TtoW0.w,i.TtoW1.w,i.TtoW2.w);
                half3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                half3x3 TtoWMatirx = half3x3(i.TtoW0.xyz,i.TtoW1.xyz,i.TtoW2.xyz);
                half3 normal = UnpackNormal(tex2D(_BumpMap,i.uv));
                normal = normalize(mul(TtoWMatirx,normal));

                half4 _dataChannel = tex2D(_LightTex,i.uv);
                #if _METALLICGLOSSMAP
                    half metallic = _dataChannel.r;
                    half smoothness = _dataChannel.a; 
                #else
                    half metallic = _Metallic;
                    half smoothness = _Smoothness; 
                #endif
               

                SurfaceData s = GetLitSurface(normal,worldPos,viewDir,col,metallic,smoothness,alpha);
                UnityLight light = MainLight();
                float3 lightColor = LWRPPBSLighting(s,light);

                float3 gi = SampleGI(s); //indirect diffuse
                float3 IBLColor = ReflectEnvironment(s); // indirect ibl

                lightColor += IBLColor + gi;
                return fixed4(lightColor,s.alpha);
            }
            ENDCG
        }
    }
    CustomEditor "LWRPLitShaderGUI"
}

