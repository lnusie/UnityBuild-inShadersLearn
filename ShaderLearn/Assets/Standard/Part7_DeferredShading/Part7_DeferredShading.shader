Shader "X_Shader/Standard/Part7_DeferredShading"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _Tint ("Tint", Color) = (1,1,1,1)
        _Smoothness ("_Smoonthness",Range(0,1)) = 0.5
        //_SpecularTint ("Specular", Color) = (0.5, 0.5, 0.5)
        //使用_Metallic和_SpecularTint，实际上对应了Unity Standard的金属流流和高光工作流
        //两者能达到同样的效果，但高光工作流可模拟一些非真实的效果
        // _Metallic值在Gamma空间下会得到正常的效果，加上[Gamma]后则线性空间下，Unity会自动
        //矫正_Metallic的值。
        [Gamma]_Metallic ("Metallic", Range(0, 1)) = 0
        [NoScaleOffset] _NormalMap ("Normals",2D) = "bump"{}
        _BumpScale ("Bump Scale", Float) = 1
        _DetailTex ("Detail Albedo", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normals",2D) = "bump"{}
        _DetailBumpScale ("Detail Bump Scale", Float) = 1

        //可优化： 金属度，光滑度，阴影遮挡存储为一张贴图，并共用一个采样器sampler，只进行一次采样

        _MetallicMap ("Metallic", 2D) = "white" {}
        _EmissionMap ("Emission", 2D) = "black" {}
		_Emission ("Emission", Color) = (0, 0, 0)

        _OcclusionMap ("Occlusion", 2D) = "white" {}
		_OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1

        _DetailMask ("Detail Mask", 2D) = "white" {}

        _AlphaCutoff ("Alpha Cutoff", Range(0, 1)) = 0.5

        [HideInInspector]_SrcBlend ("_SrcBlend", Float) = 1
		[HideInInspector]_DstBlend ("_DstBlend", Float) = 0
        [HideInInspector] _ZWrite ("_ZWrite", Float) = 1
    }

    CGINCLUDE //在这个位置定义的关键字对所有Pass都生效

    #define BINORMAL_PER_FRAGMENT

    ENDCG

    SubShader
    {
        Pass
        {
        	Tags{
        		"LightMode" = "ForwardBase"
        	}
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM

            #pragma target 3.0
            
            //shader_feature与multi_compile的区别：
            //multi_compile会为所有关键字分别编译一份Shader变体，
            //shader_feature只会为在Editor中已经有define的关键字编译一份Shader变体
            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _OCCLUSION_MAP
            #pragma shader_feature _EMISSION_MAP
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _DETAIL_ALBEDO_MAP   
			#pragma shader_feature _DETAIL_NORMAL_MAP
	        #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
 
            #pragma vertex vert
            #pragma fragment frag

            #define FORWARD_BASE_PASS

            //当该Pass的光投射阴影时，Unity会查找所有启用SHADOWS_SCREEN 关键字的变体
            #pragma multi_compile _ SHADOW_SCREEN

            #include "Part7_DeferredShading_Core.cginc"
            ENDCG
        }

        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
            }

            //与其他光照叠加
            Blend One One
            //第一个Pass已经写入Z值
            ZWrite Off

            CGPROGRAM
            #pragma target 3.0 
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP

            //本Pass可能会用于各种光源的渲染，所以定义多个变体
            //带cookie的平行光有自己的光衰减宏，因此Unity将其视为一种不同的光类型
            //#pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE POINT SPOT 

            //multi_compile_fwdadd 完成了和以上相同的操作
            #pragma multi_compile_fwdadd

            //顶点光源宏，顶点光源只支持点光源
            #pragma multi_compile _ VERTEXLIGHT_ON
            #include "Part7_DeferredShading_Core.cginc"
            ENDCG

        }

        Pass
        {
            Tags {
                "LightMode" = "ShadowCaster"
            }

            Blend [_SrcBlend] One

            CGPROGRAM

            #pragma target 3.0
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _SMOOTHNESS_ALBEDO
            #pragma shader_feature _SEMITRANSPARENT_SHADOWS
            

            #pragma multi_compile_shadowcaster

            #pragma vertex ShadowVertex
            #pragma fragment ShadowFragment

            #include "Shadow.cginc"

            ENDCG
        }

    }
    CustomEditor "XStandardShaderGUI"
}
