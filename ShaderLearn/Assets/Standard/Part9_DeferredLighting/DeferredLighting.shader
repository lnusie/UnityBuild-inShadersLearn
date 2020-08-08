Shader "X_Shader/Standard/DeferredLighting" {
	
	Properties {
       	_SrcBlend ("_SrcBlend", Float) = 2
		_DstBlend ("_DstBlend", Float) = 0
	}

	SubShader {

		Pass {

			//Cull Off
			//ZTest Always
			ZWrite Off
            	Blend One One
			
			CGPROGRAM

			#pragma target 3.0
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram
			
			#pragma exclude_renderers nomrt
            
			#pragma multi_compile_lightpass
			#pragma multi_compile _ UNITY_HDR_ON
			
            	#include "DeferredLighting_Core.cginc"

			ENDCG
		}


        //第二个Pass的作用：禁用HDR后，灯光数据会进行对数编码，需要第二个Pass进行解码
        Pass {
            
			//Cull Off
			//ZTest Always
			ZWrite Off
            	Blend [_SrcBlend] [_DstBlend]

			Stencil {
				Ref [_StencilNonBackground]
				ReadMask [_StencilNonBackground]
				CompBack Equal
				CompFront Equal
			}

			CGPROGRAM

			#pragma target 3.0
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram
			
			#pragma exclude_renderers nomrt
            
			#pragma multi_compile_lightpass
			#pragma multi_compile _ UNITY_HDR_ON
			
            	#include "DeferredLighting_Core.cginc"
		
			ENDCG
		}
	}
}