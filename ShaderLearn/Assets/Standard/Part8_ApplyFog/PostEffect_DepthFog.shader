Shader "Hidden/PostEffect_DepthFog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
        
        CGINCLUDE //在这个位置定义的关键字对所有Pass都生效

    #define FOG_LINEAR

    ENDCG

    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM

            #pragma multi_compile _ FOG_DISTANCE

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex, _CameraDepthTexture;
            float3 _FrustumCorners[4];

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;

            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                #if defined(FOG_DISTANCE)
                    float3 ray : TEXCOORD1;
                #endif
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                #if defined(FOG_DISTANCE)
                    //uv坐标为（0，0），（1、0），（0，1）和（1，1）
                    o.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y];
                #endif
                return o;
            }

            
            //	_ZBufferParams的定义
            // x = 1-far/near
            // y = far/near
            // z = x/far
            // w = y/far
            inline float _Linear01Depth( float z )
            {
                return 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                //depth应该是裁剪空间下的1/z
                //我们必须转换成世界空间中的线性深度值
                //首先使用UnityCG中定义的Linear01Depth函数将其转换为线性范围。
                depth = Linear01Depth(depth);
        
                float viewDistance = 0;
                #if defined(FOG_DISTANCE)
                    //基于射线的距离值，相机旋转时射线保持不变，距离不变，所以雾的浓度不变
                    viewDistance = length(i.ray * depth);
                #else
                    //按远裁剪平面的距离缩放此值，以获得实际的基于深度的视图距离。
                    // 裁剪空间设置可通过float4 _ProjectionParams变量获得，该变量在UnityShaderVariables中定义。
                    //它的Z分量包含远端平面的距离,y分量包含近端平面的距离
                    viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y; 
                #endif
                UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
				unityFogFactor = saturate(unityFogFactor);
                #if !defined(FOG_SKYBOX)
                    if(depth > 0.9999)
                    {
                        unityFogFactor = 1;
                    }
                #endif 
            
				float3 sourceColor = tex2D(_MainTex, i.uv).rgb;
				float3 foggedColor =
					lerp(unity_FogColor.rgb, sourceColor, unityFogFactor);
                return float4(foggedColor,1);
            }
            ENDCG
        }
    }
}
