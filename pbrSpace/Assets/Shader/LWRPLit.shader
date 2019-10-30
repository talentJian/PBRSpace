Shader "ZShader/PBR/LWRPLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _LightTex("Metallic(R)Emmisve(G)Smoothness(A)",2D) = "white" {}
        _BumpMap("BumpMap",2D) = "bump"{}
        [Gamma]_Metallic("Metallic",Range(0,1)) = 0.5 //标记了Gamma的话，会吧外面的颜色 当做Gamma.45 所以回自动 pow2.2 转到了Gamma1.0下
        _Smoothness("Smoothness",Range(0,1)) = 0.5
        _Color("_Color",Color) = (1,1,1,1)
        [HDR]_EmissiveColor("EmmisiveColor",Color) = (0,0,0,1)
        
        _ClipValue("_ClipValue",Range(0,1)) = 0.5
        [Toggle(_ALPHATEST_ON)]_ALPHATEST_ON("AlphaClip",Float) = 0
        [HideInInspector] _Blend("__Blend", Float) = 0.0
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
    }
    SubShader
    {
        

        Pass
        {
            Tags { "RenderType"="Opaque" "LightMode" = "FORWARDBASE"}
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            //自带变量 暂时不用统一接口，避免变体过多不好控制
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
			#pragma multi_compile _ VERTEXLIGHT_ON

            #pragma shader_feature _ALPHATEST_ON 
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma 
            //预乘Alpha,做玻璃的时候 预乘很重要
            #pragma shader_feature _ALPHAPREMULTIPLY_ON 
            #include "UnityCG.cginc"
            #include "Lib/LWRPLit.cginc"
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 :TEXCOORD1; // lightmapUv
                float3 normal :NORMAL;
                float4 tangent :TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 lightmapUV :TEXCOORD1;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD2;

                float4 TtoW0 :TEXCOORD3;
                float4 TtoW1 :TEXCOORD4;
                float4 TtoW2 :TEXCOORD5;

                float3 vertexLight :TEXCOORD6;
                UNITY_FOG_COORDS(7)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _LightTex;            
            sampler2D _BumpMap;
            float _Smoothness;
            float _Metallic;
            float4 _Color;
            float _ClipValue;
            float3 _EmissiveColor;
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

                // SH/ambient and vertex lights
				#ifndef LIGHTMAP_ON
					#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
						o.vertexLight = 0;
						// Approximated illumination from non-important point lights
						#ifdef VERTEXLIGHT_ON
						o.vertexLight += Shade4PointLights (
							unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
							unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
							unity_4LightAtten0, o.worldpos, o.normal);
						#endif
						//o.sh = ShadeSHPerVertex (o.normal, o.sh);
					#endif
				#endif // !LIGHTMAP_ON

                #if LIGHTMAP_ON
				    o.lightmapUV = v.uv2 * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif

                UNITY_TRANSFER_FOG(o,o.vertex);
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


                LightTexData lightTexData = UnPackLightTex(_LightTex,i.uv,_Metallic,_Smoothness);
                half metallic = lightTexData.metallic;
                half smoothness = lightTexData.smoothness; 
                half emissiveMask = lightTexData.emissiveMask;
               

                SurfaceData s = GetLitSurface(normal,worldPos,viewDir,col,metallic,smoothness,alpha);
                #if _ALPHATEST_ON
                    clip(a.alpha - _ClipValue);
                #endif
                UnityLight light = MainLight();
                float3 lightColor = LWRPPBSLighting(s,light);

                float3 gi = SampleGI(s,i.lightmapUV,i.vertexLight); //indirect diffuse
                //return fixed4(gi,1);
                float3 IBLColor = ReflectEnvironment(s); // indirect ibl

                lightColor += IBLColor + gi;

                float3 emissvie = emissiveMask*_EmissiveColor;
                lightColor.rgb += emissvie;

                float4 finalColor = fixed4(lightColor,s.alpha);
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return finalColor;
            }
            ENDCG
        }

        //Meta
        Pass{
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _METALLICGLOSSMAP
            #include "Lib/LWRPLit_Meta.cginc"
            ENDCG
        }
    }
    CustomEditor "LWRPLitShaderGUI"
}

