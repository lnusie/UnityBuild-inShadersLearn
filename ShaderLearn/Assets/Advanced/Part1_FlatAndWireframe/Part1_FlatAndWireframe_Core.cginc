
    #if !defined(Part1_FlatAndWireframe_INCLUDE)
    #define Part1_FlatAndWireframe_INCLUDE



    #include "Part1_FlatAndWireframe_Core_Input.cginc" 
    #if !defined(ALBEDO_FUNCTION)
	    #define ALBEDO_FUNCTION GetAlbedo
    #endif

    //UnityCG中ObjSpaceViewDir的定义：
    // inline float3 ObjSpaceViewDir (float4 v) {
    // float3 objSpaceCameraPos =
	// 	mul(unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz, 1)).xyz;
    // return objSpaceCameraPos - v.xyz;
    // }
    
    v2f vert (appdata v)
    {
        v2f o;
        //不同平台定义变量可能有不同的默认值，UNITY_INITIALIZE_OUTPUT用于统一设置默认值
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        o.pos = UnityObjectToClipPos(v.vertex);
        o.worldPos.xyz = mul(unity_ObjectToWorld,v.vertex);
        #if FOG_DEPTH
            o.worldPos.w = o.vertex.z;
        #endif

        //合批后本地空间的法线方向会改变，所以需要变换到世界空间
        //将法线变换到世界空间，如果直接用unity_ObjectToWorld变换，当模型缩放时法线会受影响
        //公式的推导参考<shader入门精要>   
        //UnityCG 提供了相同操作的接口 UnityObjectToWorldNormal o.normal = UnityObjectToWorldNormal(v.normal);
        //o.normal = mul(transpose((float3x3)unity_WorldToObject),v.normal);
        //o.normal = normalize(o.normal);
        o.normal = UnityObjectToWorldNormal(v.normal);
        #if defined(BINORMAL_PER_FRAGMENT)
            o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
        #else
            o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
            o.binormal = CreateBinormal(o.normal, o.tangent, v.tangent.w);
        #endif
        // #if defined(SHADOW_SCREEN)
        //     // i.shadowCoordinates.xy = (i.position.xy + i.position.w) * 0.5;// i.position;      
        //     // i.shadowCoordinates.zw = i.position.zw;   
        //     //ComputeScreenPos执行了与上面相同的计算，只不过加了比如不同平台屏幕坐标原点差异等处理
        //     //i.shadowCoordinates = ComputeScreenPos(i.position);
        //     //TRANSFER_SHADOW执行了以上相同的运算，差异在于要求变量名必须为shadowCoordinates，
        //     //与SHADOW_COORDS搭配使用
        //     //TRANSFER_SHADOW(i);

        //     UNITY_TRANSFER_SHADOW(o, v.uv1);
        // #endif  

        //TRRANSFORM_TEX确保在贴图有缩放和偏移的情况下仍能返回正确的uv
        o.uv.xy = TRANSFORM_TEX(v.uv,_MainTex);
        o.uv.zw = TRANSFORM_TEX(v.uv,_DetailTex);
        #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
            //TRANSFORM_TEX里会默认使用 unity_Lightmap_ST
            //然而unity_Lightmap对应的是 unity_LightmapST
            //所以需要手动调整uv
            o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
        #endif
        UNITY_TRANSFER_SHADOW(o, v.uv1);
        ComputeVertexLightColor(o);

        #if defined(_PARALLAX_MAP)
            //Unity在动态合批时为了性能考虑不会将切线和法线归一化
            #if defined(PARALLAX_SUPPORT_SCALED_DYNAMIC_BATCHING)
                v.tangent.xyz = normalize(v.tangent.xyz);
                v.normal = normalize(v.normal);
            #endif
            float3x3 object2Tangent = float3x3(
                v.tangent.xyz,
                cross(v.normal, v.tangent.xyz) * v.tangent.w,
                v.normal
            );
            o.tangentViewDir = mul(object2Tangent, ObjSpaceViewDir(v.vertex));
        #endif 
        return o;
    }

 	FragmentOutput frag (v2f i) 
    {
        #if defined(LOD_FADE_CROSSFADE)
		    UnityApplyDitherCrossFade(i.vpos);
	    #endif
        
	    ApplyParallax(i);

        float alpha = GetAlpha(i);
        #if defined(_RENDERING_CUTOUT)
		    clip(alpha - _Cutoff); 
	    #endif

        // //不同单位长度的法线经过差值后不能得到单位向量，需要再归一化
        // i.normal = normalize(i.normal);
        InitFragNormal(i);

        //也可以在顶点函数计算视角方向并插值，但可能存在过渡不平缓的情况
        float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

        float3 albedo = ALBEDO_FUNCTION(i);
        //使用金属工作流时，高光颜色由反射率乘以金属度
        float3 specularTint = albedo * _Metallic;

        float oneMinusReflectivity;
 
        albedo = _DiffuseAndSpecularFromMetallic(
            albedo, GetMetallic(i), specularTint, oneMinusReflectivity
        );

        //能量守恒：同一束光不能既被反射，又穿过对象。
        //因此，无论其固有的透明性如何，反射性越强，穿过它的光线越少。
        #if defined(_RENDERING_TRANSPARENT)
		    albedo *= alpha;
            alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
	    #endif
      
        float4 color = UNITY_BRDF_PBS(  albedo, specularTint,
                                        oneMinusReflectivity, GetSmoothness(i),
                                        i.normal, viewDir,
                                        CreateLight(i), CreateIndirectLight(i, viewDir)
                                     );
        color.rgb += GetEmission(i);
        #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
            color.a = alpha;
        #endif
        FragmentOutput output; 
        #if defined(DEFERRED_PASS)
            output.gBuffer0.rgb = albedo;
            output.gBuffer0.a = GetOcclusion(i);
            output.gBuffer1.rgb = specularTint;
            output.gBuffer1.a = GetSmoothness(i);
            output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
            #if !defined(UNITY_HDR_ON)
                //LDR模式下，需要进行对数编码,因为Unity按HDR数据格式存储
                color.rgb = exp2(-color.rgb);
            #endif
            output.gBuffer3 = color;

            #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
                float2 shadowUV = 0;
                #if defined(LIGHTMAP_ON)
                    shadowUV = i.lightmapUV;
                #endif
                //除了不输出一个通道的值，UnityGetRawBakedOcclusions的功能与UnitySampleBakedOcclusion相同
                output.gBuffer4 = UnityGetRawBakedOcclusions(shadowUV, i.worldPos.xyz);
		    #endif

        #else
            output.color = ApplyFog(color, i);
        #endif
        //output.color.rgb = albedo;  
        return output;
    } 
#endif 
