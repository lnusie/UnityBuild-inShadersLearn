
#if !defined(DEFERRED_LIGHTING_CORE)
#define DEFERRED_LIGHTING_CORE

#include "UnityPBSLighting.cginc"

struct a2v {
     float4 vertex : POSITION;
     float3 normal : NORMAL;
};

struct v2f {
     float4 pos : SV_POSITION;
     float4 uv : TEXCOORD0;
     float3 ray : TEXCOORD1;
};

sampler2D _LightBuffer;
sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;
sampler2D _CameraGBufferTexture4;
#if defined(SHADOWS_SCREEN)
     sampler2D _ShadowMapTexture;  //访问阴影贴图
#endif

#if defined(POINT_COOKIE)
     samplerCUBE _LightTexture0;
#else
     sampler2D _LightTexture0;
#endif

sampler2D _LightTextureB0;
float4x4  unity_WorldToLight;
float _LightAsQuad;

float4 _LightColor, _LightDir, _LightPos; //获取当前正在渲染的光

//UnityShadowLibrary中定义的UnityComputeShadowFadeDistance 和UnityComputeShadowFade
//unity_ShadowFadeCenterAndType变量包含阴影中心和阴影类型
//_LightShadowData变量的Z和W分量包含用于淡入的比例和偏移。
//Stable Fit 模式下，阴影衰落是球形的，居中于贴图中间。在Close Fit模式下，它基于视图深度。
// float UnityComputeShadowFadeDistance (float3 wpos, float z) {
//     float sphereDist = distance(wpos, unity_ShadowFadeCenterAndType.xyz);
//     return lerp(z, sphereDist, unity_ShadowFadeCenterAndType.w);
// }

// half UnityComputeShadowFade(float fadeDist) {
//     return saturate(fadeDist * _LightShadowData.z + _LightShadowData.w);
// }

//获取ShadowMask的值
float GetShadowMaskAttenuation (float2 uv) {
	float attenuation = 1;
	#if defined (SHADOWS_SHADOWMASK)
		float4 mask = tex2D(_CameraGBufferTexture4, uv);
          //unity_OcclusionMaskSelector : 单通道掩码
		attenuation = saturate(dot(mask, unity_OcclusionMaskSelector));
	#endif
	return attenuation;
}

UnityLight CreateLight(float2 uv, float3 worldPos, float viewZ)
{
     UnityLight light;

     float attenuation = 1;
     float shadowAttenuation = 1;
     bool shadowed = false;
     #if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
          light.dir = -_LightDir;
          #if defined(DIRECTIONAL_COOKIE)
               float2 uvCookie = mul(unity_WorldToLight, float4(worldPos,1)).xy;
               attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie, 0, -8)).w;
          #endif

          #if defined(SHADOWS_SCREEN)
               shadowed = true;
               shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;
          #endif
     #else
          float3 lightVec = _LightPos.xyz - worldPos;
          light.dir = normalize(lightVec);
          attenuation *= tex2D(_LightTextureB0,(dot(lightVec,lightVec) * _LightPos.w).rr).UNITY_ATTEN_CHANNEL;
          #if defined(SPOT)
               float4 uvCookie = mul(unity_WorldToLight, float4(worldPos,1));
               uvCookie.xy /= uvCookie.w;
               attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie.xy, 0, -8)).w;
               attenuation *= uvCookie.w < 0;

               #if defined(SHADOWS_DEPTH)
                    shadowed = true;
                    //unity_WorldToShadow数组中的第一个矩阵可用于将世界转换为阴影空间。
                    shadowAttenuation = UnitySampleShadowmap(mul(unity_WorldToShadow[0], float4(worldPos, 1)));
               #endif
          #else 
               #if defined(POINT_COOKIE)
                    float3 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xyz;
                    attenuation *= texCUBEbias(_LightTexture0, float4(uvCookie, -8)).w;
               #endif

               #if defined(SHADOWS_CUBE)
                    shadowed = true;
                    shadowAttenuation = UnitySampleShadowmap(-lightVec);
               #endif
          #endif
     #endif 
     
     #if defined(SHADOWS_SHADOWMASK)
		shadowed = true;
	#endif


     if(shadowed)
     {
          float shadowFadeDistance = UnityComputeShadowFadeDistance(worldPos, viewZ);
          float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
          //shadowAttenuation = saturate(shadowAttenuation + shadowFade);

          //混合ShadowMask和实时阴影
          shadowAttenuation = UnityMixRealtimeAndBakedShadows(
			shadowAttenuation, GetShadowMaskAttenuation(uv), shadowFade
		);
          #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT)
               #if !defined(SHADOWS_SHADOWMASK)
                    UNITY_BRANCH
                    if(shadowFade > 0.99)
                    {
                         shadowAttenuation = 1;
                    }
                    s_a_huangjinshengdian
               #endif
          #endif
     }

     light.color = _LightColor.rgb * shadowAttenuation;
     return light;
}

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);



v2f VertexProgram (a2v v) {
     v2f i;
     i.pos = UnityObjectToClipPos(v.vertex);
     i.uv = ComputeScreenPos(i.pos);
     i.ray = v.normal;
     i.ray = lerp(UnityObjectToViewPos(v.vertex) * float3(-1,-1,1), v.normal, _LightAsQuad) ;
     return i;
}

float4 FragmentProgram (v2f i) : SV_Target {
     //Unity不提供具有方便的纹理坐标的灯光pass。相反，必须从剪辑空间位置间接获取它们。
	float2 uv = i.uv.xy / i.uv.w;

	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	depth = Linear01Depth(depth);
     //对于平行光，ray可以使用矩形的法线来构造，缩放射线，再乘以远平面距离获得到达远平面的射线
     float3 rayToFarPlane = i.ray / i.ray.z * _ProjectionParams.z;
	float3 viewPos = rayToFarPlane * depth;
     float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;
	float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);

     float3 albedo = tex2D(_CameraGBufferTexture0, uv).rgb;
	float3 specularTint = tex2D(_CameraGBufferTexture1, uv).rgb;
	float3 smoothness = tex2D(_CameraGBufferTexture1, uv).a;
	float3 normal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;
     //SpecularStrength ： 取specularTint rgb最大值
	float oneMinusReflectivity = 1 - SpecularStrength(specularTint);

     UnityLight light = CreateLight(uv, worldPos, viewPos.z);
     
     UnityIndirect indirectLight;
     indirectLight.diffuse = 0;
     indirectLight.specular = 0;
	float4 color = UNITY_BRDF_PBS(
    	albedo, specularTint, oneMinusReflectivity, smoothness,
    	normal, viewDir, light, indirectLight
     );
     #if !defined(UNITY_HDR_ON)
          color = exp2(-color);
     #endif
     return color;
}

#endif











