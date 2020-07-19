Shader "X_Shader/Standard/Part4_Shadow"
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
        _DetailTex ("Detail Texture", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normals",2D) = "bump"{}
        _DetailBumpScale ("Detail Bump Scale", Float) = 1


    }

    CGINCLUDE //在这个位置定义的关键字对所有Pass都生效

    #define BINORMAL_PER_FRAGMENT

    ENDCG

    SubShader
    {
        // No culling or depth
        Cull Back 


        Pass
        {
        	Tags{
        		"LightMode" = "ForwardBase"

        	}

            CGPROGRAM

            #pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

            #include "Part4_Shadow_Core.cginc"

            //当该Pass的光投射阴影时，Unity会查找所有启用SHADOWS_SCREEN 关键字的变体
            #pragma multi_compile _ SHADOW_SCREEN
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

            //本Pass可能会用于各种光源的渲染，所以定义多个变体
            //带cookie的平行光有自己的光衰减宏，因此Unity将其视为一种不同的光类型
            //#pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE POINT SPOT 

            //multi_compile_fwdadd 完成了和以上相同的操作
            #pragma multi_compile_fwdadd

            //顶点光源宏，顶点光源只支持点光源
            #pragma multi_compile _ VERTEXLIGHT_ON

            #include "Part4_Shadow_Core.cginc"

            ENDCG

        }

        Pass
        {
            Tags {
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_shadowcaster

            #pragma vertex ShadowVertex
            #pragma fragment ShadowFragment
            
            #include "Shadow.cginc"

            ENDCG
        }

    }
}
