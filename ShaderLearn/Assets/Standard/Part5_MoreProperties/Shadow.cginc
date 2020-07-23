// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

#if !defined(SHADOW_INCLUDE)
#define SHADOW_INCLUDE

#include "UnityCG.cginc"

//UnityCG中UnityApplyLinearShadowBias的实现
//主要是增加裁剪坐标的z值。但它使用的是齐次坐标，必须补偿透视投影
//以使偏移量不会随着相机的距离而变换，还必须确保结果不会超出范围
float4 _UnityApplyLinearShadowBias(float4 clipPos)
{
	clipPos.z += saturate(unity_LightShadowBias.x / clipPos.w);
	float clamped = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
	clipPos.x = lerp(clipPos.z, clamped, unity_LightShadowBias.y);

}

//UnityCG中UnityClipSpaceShadowCasterPoss的实现
//它将位置转换为世界空间，应用法向偏差，
//然后转换为裁剪空间。确切的偏移量取决于法线和光方向之间的角度以及阴影纹素大小。
float4 _UnityClipSpaceShadowCasterPos (float3 vertex, float3 normal) {
	float4 clipPos;
    // Important to match MVP transform precision exactly while rendering
    // into the depth texture, so branch on normal bias being zero.
    if (unity_LightShadowBias.z != 0.0) {
		float3 wPos = mul(unity_ObjectToWorld, float4(vertex,1)).xyz;
		float3 wNormal = UnityObjectToWorldNormal(normal);
		float3 wLight = normalize(UnityWorldSpaceLightDir(wPos));

	// apply normal offset bias (inset position along the normal)
	// bias needs to be scaled by sine between normal and light direction
	// (http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/)
	//
	// unity_LightShadowBias.z contains user-specified normal offset amount
	// scaled by world space texel size.
		float shadowCos = dot(wNormal, wLight);
		float shadowSine = sqrt(1 - shadowCos * shadowCos);
		//法线与光线夹角越大，偏移值越大
		float normalBias = unity_LightShadowBias.z * shadowSine;
		wPos -= wNormal * normalBias;
		clipPos = mul(UNITY_MATRIX_VP, float4(wPos, 1));
    }
    else {
        clipPos = UnityObjectToClipPos(vertex);
    }
	return clipPos;
}

//UnityCG中EncodeFloatRGBA的实现
//将0~1的浮点数转换成8位的RGBA通道值
//Note that : >= 1不能编码
inline float4 _EncodeFloatRGBA (float v) {
	float4 kEncodeMul = float4(1.0, 255.0, 65025.0, 16581375.0);
	float kEncodeBit = 1.0 / 255.0;
	float4 enc = kEncodeMul * v;
	enc = frac(enc);
	enc -= enc.yzww * kEncodeBit;
	return enc;
}

//将0~1的数值转为8位的RGBA值
float4 _UnityEncodeCubeShadowDepth (float z) {
	#ifdef UNITY_USE_RGBA_FOR_POINT_SHADOWS
		return EncodeFloatRGBA(min(z, 0.999));
	#else
		return z;
	#endif
}

struct VertexData {
	float4 position : POSITION;
	float3 normal : NORMAL;
};

//当点光源生成的阴影贴图是CubeMap，需要在片元函数中进行特殊的深度计算
#if defined(SHADOW_CUBE)
	struct Interpolators
	{
		float4 position : SV_POSITION;
		float3 lightVec : TEXCOORD0;
	}
	float4 ShadowVertex (VertexData v) : SV_POSITION {
		Interpolators i;
		i.position = UnityObjectToClipPos(v.position);
		//_LightPositionRange : xyz存储光源位置 z存储其范围的倒数
		i.lightVec = mul(unity_objectToWorld, v.position).xyz - _LightPositionRange.xyz;
	}	
	float4 ShadowFragment(Interpolators i) : SV_TARGET{
		float depth = length(i.lightVec) + unity_LightShadowBias.x;
		depth *= _LightPositionRange.w;
		//depth最终被限制在0~1之间，超过这个范围物体不在点光源范围内
		//UnityEncodeCubeShadowDepth将深度值编码存储在立方体贴图RGBA通道中
		return UnityEncodeCubeShadowDepth(depth);
	}
#else
	float4 ShadowVertex (VertexData v) : SV_POSITION {
		//float4 position = UnityObjectToClipPos(v.position);
		float4 position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
		//加入深度偏差,为了解决阴影失真问题
		//阴影失真的根本原因 1是精度问题，2是Shadow depth map 分辨率不够，因此多个相邻的Pixel会对应map上的一个点，
		//在对比场景深度和灯光深度的时候就会出现场景深度图上相邻的几个点对应灯光深度图的一个点，相邻几个点的比较结果有大有小（selfShadow）
		//https://blog.csdn.net/lawest/article/details/106364935
		return UnityApplyLinearShadowBias(position);
	}
	half4 ShadowFragment () : SV_TARGET {
		return 0;
	}
#endif



#endif