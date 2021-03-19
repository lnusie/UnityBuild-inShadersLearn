

    #if !defined(Part1_FlatAndWireframe_INCLUDE)
    #define Part1_FlatAndWireframe_INCLUDE
    
    #include "UnityPBSLighting.cginc" 
    #include "AutoLight.cginc" 


    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #if !defined(FOG_DISTANCE)
    	    #define FOG_DEPTH 1
        #endif
        #define FOG_ON 1
    #endif

    #if !defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
        #if defined(SHADOWS_SHADOWMASK) && !defined(UNITY_NO_SCREENSPACE_SHADOWS)
            #define ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS 1
        #endif
    #endif

    #if defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
        #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
            #define SUBTRACTIVE_LIGHTING 1
        #endif
    #endif
    
    

	struct appdata
    {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        float4 tangent : TANGENT;
        float2 uv1 : TEXCOORD1; //光照贴图uv
    };

    struct InterpolatorsVertex 
    {
        float4 pos : SV_POSITION;
        float4 uv : TEXCOORD0;
        float3 normal : TEXCOORD1;
        #if defined(BINORMAL_PER_FRAGMENT)//在frag方法里计算副法线
            float4 tangent : TEXCOORD2;
        #else
            //在vert方法里计算副法线
            float3 tangent : TEXCOORD2;
            float3 binormal : TEXCOORD3;
        #endif 
        #if FOG_DEPTH 
		    float4 worldPos : TEXCOORD4;
	    #else
		    float3 worldPos : TEXCOORD4;
	    #endif
        UNITY_SHADOW_COORDS(5)

        #if defined(VERTEXLIGHT_ON)
            float3 vertexLightColor : TEXCOORD6;
        #endif

        #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
            float2 lightmapUV : TEXCOORD7;
        #endif

        //target 3.0支持10个插值器。target2.0只支持8个，但如果是taget2.0就没必要用视差图了。
        #if defined(_PARALLAX_MAP)
            float3 tangentViewDir : TEXCOORD8; 
        #endif

    };

    struct v2f
    {
        #if SHADOWS_SEMITRANSPARENT || defined(LOD_FADE_CROSSFADE)
            UNITY_VPOS_TYPE vpos : VPOS;
        #else
            float4 pos : SV_POSITION;
        #endif

        float4 uv : TEXCOORD0;
        float3 normal : TEXCOORD1;
        #if defined(BINORMAL_PER_FRAGMENT)//在frag方法里计算副法线
            float4 tangent : TEXCOORD2;
        #else
            //在vert方法里计算副法线
            float3 tangent : TEXCOORD2;
            float3 binormal : TEXCOORD3;
        #endif 
        #if FOG_DEPTH 
		    float4 worldPos : TEXCOORD4;
	    #else
		    float3 worldPos : TEXCOORD4;
	    #endif
        UNITY_SHADOW_COORDS(5)

        // #if defined(SHADOW_SCREEN)
        //     //float4 shadowCoordinates : TEXCOORD5;
        //     //SHADOW_COORDS 也是定义shadowCoordinates
        //     //SHADOW_COORDS(5)
        //     UNITY_SHADOW_COORDS(5)
        // #endif 
        #if defined(VERTEXLIGHT_ON)
            float3 vertexLightColor : TEXCOORD6;
        #endif

        #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
            float2 lightmapUV : TEXCOORD7;
        #endif

        #if defined(_PARALLAX_MAP)
            float3 tangentViewDir : TEXCOORD8; 
        #endif
    };

    struct FragmentOutput
    {
        #if defined(DEFERRED_PASS)
            float4 gBuffer0 : SV_TARGET0;
            float4 gBuffer1 : SV_TARGET1;
            float4 gBuffer2 : SV_TARGET2;
            float4 gBuffer3 : SV_TARGET3;

            //有些平台可能不支持太多buffer
            // (UNITY_ALLOWED_MRT_COUNT > 4)用于判断是否有足够多的渲染目标才使用SHADOWS_SHADOWMASK
            #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
			    float4 gBuffer4 : SV_Target4;
		    #endif
        #else
            float4 color : SV_TARGET;
        #endif 
    };

    fixed4 _Color;
    float _Smoothness;
    //float4 _SpecularTint;
    float _Metallic;

    float _BumpScale;
    float _DetailBumpScale;

    sampler2D _MainTex;
    sampler2D _DetailTex;
    fixed4 _MainTex_ST;
    fixed4 _DetailTex_ST;

    sampler2D _NormalMap;
    sampler2D _DetailNormalMap;

    sampler2D _MetallicMap;

    sampler2D _EmissionMap;
    float3 _Emission;

    sampler2D _OcclusionMap;    
    float _OcclusionStrength;

    sampler2D _DetailMask;
    sampler2D _ParallaxMap;
    float _ParallaxStrength;

    fixed _Cutoff;

    //UnityStandardUtils中DiffuseAndSpecularFromMetallic的具体实现
    inline half _OneMinusReflectivityFromMetallic(half metallic) {
        // We'll need oneMinusReflectivity, so
        //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic)
        //                  = lerp(1-dielectricSpec, 0, metallic)
        // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
        //   1-reflectivity = lerp(alpha, 0, metallic)
        //                  = alpha + metallic*(0 - alpha)
        //                  = alpha - metallic * alpha
        half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
        return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
    }

    inline half3 _DiffuseAndSpecularFromMetallic (
        half3 albedo, half metallic,
        out half3 specColor, out half oneMinusReflectivity
    ) {
        specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
        oneMinusReflectivity = _OneMinusReflectivityFromMetallic(metallic);
        return albedo * oneMinusReflectivity;
    }

    // //UnityShadowLibrary 中UnitySampleBakedOcclusion的部分实现：（实际代码还包含混合光照探针的强度）
    // //采样阴影贴图
    // fixed UnitySampleBakedOcclusion (float2 lightmapUV, float3 worldPos) {
    //     #if defined (SHADOWS_SHADOWMASK)
    //         #if defined(LIGHTMAP_ON)
    //             fixed4 rawOcclusionMask = UNITY_SAMPLE_TEX2D_SAMPLER(
    //                 unity_ShadowMask, unity_Lightmap, lightmapUV.xy
    //             );
    //         #else
    //             fixed4 rawOcclusionMask =
    //                 UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
    //         #endif
    //         //unity_OcclusionMaskSelector是一个只有一个值为1的Vector,起到掩码的作用
    //         return saturate(dot(rawOcclusionMask, unity_OcclusionMaskSelector));
    //     #else
    //         return 1.0;
    //     #endif
    // }
    // //UnityShadowLibrary 中UnityMixRealtimeAndBakedShadows的部分实现：
    // 对实时阴影与烘焙阴影进行混合
    // inline half UnityMixRealtimeAndBakedShadows (half realtimeShadowAttenuation, half bakedShadowAttenuation, half fade) 
    // {
    //     #if !defined(SHADOWS_DEPTH) && !defined(SHADOWS_SCREEN) && \
    //         !defined(SHADOWS_CUBE)
    //         return bakedShadowAttenuation;
    //     #endif

    //     #if defined (SHADOWS_SHADOWMASK)
    //         #if defined (LIGHTMAP_SHADOW_MIXING)
    //             realtimeShadowAttenuation =
    //                 saturate(realtimeShadowAttenuation + fade);
    //             return min(realtimeShadowAttenuation, bakedShadowAttenuation);
    //         #else
    //             return lerp(
    //                 realtimeShadowAttenuation, bakedShadowAttenuation, fade
    //             );
    //         #endif
    //     #else //no shadowmask
    //         return saturate(realtimeShadowAttenuation + fade);
    //     #endif
    // }

    //处理阴影的距离衰减，以及对ShadowMask的采样
    float FadeShadows(v2f i, float attenuation)
    {
        #if HANDLE_SHADOWS_BLENDING_IN_GI || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
            #if ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
                attenuation = SHADOW_ATTENUATION(i);
            #endif
            //距离相机的z轴距离
            float viewZ = dot(_WorldSpaceCameraPos - i.worldPos, UNITY_MATRIX_V[2].xyz);
            //基于距离的投影
            float shadowFadeDistance = UnityComputeShadowFadeDistance(i.worldPos, viewZ);
            float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
            
            //UnitySampleBakedOcclusion 对unity_ShadowMask进行采样
            float bakedAttenuation = UnitySampleBakedOcclusion(i.lightmapUV, i.worldPos);
            // //混合烘焙阴影和实时阴影
            // attenuation = UnityMixRealtimeAndBakedShadows(
            //     attenuation, bakedAttenuation,  shadowFade
            // ); 
            // attenuation = saturate(attenuation + shadowFade);
            return bakedAttenuation;
        #endif
        return attenuation;
    }

    //根据光的类型返回相应的UnityLight结构体
    //UnityLight保存并不是当前光源的信息，
    //而是当前光源对于当前片元的信息
    UnityLight CreateLight(v2f i)
    {
        UnityLight light;
        #if defined(DEFERRED_PASS)
            //输出到GBuffer的颜色应该不带光照计算
            light.dir = float3(0,1,0);
            light.color = 0;
        #else
            #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
                light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
            #else
                //平行光没有光源位置，所以_WorldSpaceLightPos0.xyz就是光的方向
                light.dir = _WorldSpaceLightPos0.xyz;
            #endif

            float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos.xyz;
            //计算光强，光强随距离增大而减小，如点光源.分母+1是为了防止距离过近是attenuation变得很大
            // float attenuation = 1 / (1 + dot(lightVec,lightVec)); 
            // #if defined(SHADOW_SCREEN)
            //     //采样当前光源生成的屏幕阴影纹理 
            //     attenuation = tex2D(_ShadowMapTexture, i.shadowCoordinates.xy / i.shadowCoordinates.w);
            //     //SHADOW_ATTENUATION 执行了与上面相同的计算
            //     //float attenuation = SHADOW_ATTENUATION(i);
            // #else
            // #endif
            //UNITY_LIGHT_ATTENUATION里面有判断SHADOW_SCREEN宏并进行相应计算的操作
            //并且根据不同光源，对阴影的采样也不同
            UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
            attenuation = FadeShadows(i, attenuation);
            light.color = _LightColor0.rgb * attenuation;
        #endif 
        return light;
    }

    //求盒投影: position为投影盒中某点，direction为该点的reflectDir
    //cubemapPosition 投影盒中心点，boxMin，boxMax 为投影盒的边界点
    //求出盒中一点到投影盒边界的向量，再求得中心点到边界的向量，并用此向量采样
    //即可得到此点的反射值（用相似三角形定理即可求出）
    float3 BoxProjection( float3 position,float3 direction,
        float4 cubemapPosition, float3 boxMin, float3 boxMax)
    {
        //是否应用盒投影
        UNITY_BRANCH
        if(cubemapPosition.w > 0)
        {
            float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
            float scalar = min(min(factors.x, factors.y), factors.z);
            return direction * scalar + (position - cubemapPosition);
        }
        return direction;
    }

    //TODO SSAO
    float GetOcclusion (v2f i) {
        #if defined(_OCCLUSION_MAP)
            //lerp(a,b,c) -> return a + c * (b - a)
            return lerp(1,tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
        #else
            return 1;
        #endif
    }

    //创建环境光，如果存在顶点光源，则作为环境光
    //UnityIndirect 保存的不是光源信息，而是当前片元相对于光的信息
    //烘焙出的光照贴图跟阴影贴图 会在此被采样作为漫反射。
    UnityIndirect CreateIndirectLight(v2f i, float3 viewDir)
    {
        UnityIndirect indirectLight;
        indirectLight.diffuse = 0;
        indirectLight.specular = 0;
        #if defined(VERTEXLIGHT_ON)
            indirectLight.diffuse = i.vertexLightColor;
        #endif

        #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS) //延迟渲染计算灯光是不会计算环境光的，所以要先算好混合
            #if defined(LIGHTMAP_ON) //光照贴图不会和顶点光照一起使用
                //DecodeLightmap里应该还采样了阴影贴图。但Light设置为Mixed的时候不会采样，而是CreateLight里采样并与实时阴影混合
                indirectLight.diffuse = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV)); 
                #if defined(DIRLIGHTMAP_COMBINED)
                    //unity_Lightmap 定义了主光线的方向
                    float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(
                        unity_LightmapInd, unity_Lightmap, i.lightmapUV
                    );
                    //DecodeDirectionalLightmap 里面用半兰伯特模型计算漫反射
                    indirectLight.diffuse = DecodeDirectionalLightmap(indirectLight.diffuse, 
                    lightmapDirection, i.normal);
			    #endif
            #else
                indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
            #endif

            // float3 reflectDir = reflect(-viewDir, i.normal);
            // float roughness = 1 - _Smoothness;       
            // roughness *= 1.7 - 0.7 * roughness;// 粗糙度与mipmap级别不是线性关系。    
            // //UNITY_SPECCUBE_LOD_STEPS在 UnityShaderVariables中定义，初始值为6。
            // float4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectDir, roughness * UNITY_SPECCUBE_LOD_STEPS);
            // //unity_SpecCube0包含HDR颜色，必须从HDR格式转化为RGB
            // //HDR数据使用RGBM格式存储在四个通道中，M通道存储的是幅度因子
            // indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);
            //Unity_GlossyEnvironment是对以上代码的封装 并判断了平台差异

            Unity_GlossyEnvironmentData envData;
            envData.roughness = 1 - _Smoothness;
            float3 reflectDir = reflect(-viewDir, i.normal);
            envData.reflUVW = BoxProjection(i.worldPos.xyz, reflectDir, unity_SpecCube0_ProbePosition, 
            unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
            float3 probe0 = Unity_GlossyEnvironment(
                //UNITY_PASS_TEXCUBE 
                UNITY_PASS_TEXCUBE(unity_SpecCube0),unity_SpecCube0_HDR,envData
            );

            #if UNITY_SPECCUBE_BLENDING //平台支持混合反射探针贴图
                //unity_SpecCube_BoxMin.w 存储混合的权重
                float interpolator = unity_SpecCube0_BoxMin.w;
                if(interpolator < 0.9999)
                {
                    envData.reflUVW = BoxProjection(i.worldPos.xyz, reflectDir, unity_SpecCube1_ProbePosition, 
                    unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
                    float3 probe1 = Unity_GlossyEnvironment(
                        //UNITY_PASS_TEXCUBE这个宏会判断unity_SpecCube1是否存在
                        UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),unity_SpecCube0_HDR,envData
                    );
                    indirectLight.specular = lerp(probe1, probe0, interpolator);
                }
                else
                {
                    indirectLight.specular = probe0;
                }
            #else
                    indirectLight.specular = probe0;
            #endif
            float occlusion = GetOcclusion(i);
            indirectLight.diffuse *= occlusion;
            indirectLight.specular *= occlusion;
            #if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
                indirectLight.specular = 0;
            #endif

        #endif

        return indirectLight;
    }

    void ComputeVertexLightColor(inout v2f v)
    {
        #if defined(VERTEXLIGHT_ON)
            // //unity 最多支持四个顶点光源，并用4个float4结果存储这4个光源的位置
            // float3 lightPos = float3(unity_4LightPosX0.x,unity_4LightPosY0.x,unity_4LightPosZ0.x);
            // float3 lightVec = lightPos - i.worldPos;
            // float3 lightDir = normalize(lightVec);
            // float ndotl = DotClamped(i.normal, lightDir);
            // float attenuations = 1 / (1+dot(lightVec,lightVec));
            // //unity_4LightAtten0是UnityShaderVariables中定义的衰减值，应该是用于更平滑的衰减
            // v.vertexLightColor = unity_LightColor[0].rgb * ndotl * attenuations * unity_4LightAtten0.x;

            //Shade4PointLights相当于执行了4次以上的操作并混合
            i.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, i.worldPos.xyz, i.normal
            );
        #endif
    }

    float3 __CreateBinormal(float3 normal, float3 tangent, float binormalSign)
    {
        //i.trangent.w存储的是副法线的方向，
        //因为创建具有双边对称性（例如人和动物）的3D模型时，一种常见的技术是左右镜像网格。 
        //这意味着只需要编辑网格的一侧。 只需要一半的纹理数据即可。 这意味着法向和切向量也将被镜像。
        //但副法线不应该被镜像，所以如果是镜像时i.trangent.w存储的是-1
        //构造镜像时，还有一个附加细节。 假设对象的比例尺设置为（-1，1，1）。 这意味着它已被镜像。
        //在这种情况下，我们必须翻转副法线，以正确反映切线空间。 实际上，当奇数个维数为负时，我们必须这样做。
        //UnityShaderVariables通过定义float4 unity_WorldTransformParams变量来帮助我们。 
        //当我们需要翻转副法线时，它的第四部分包含-1，否则为1。
        return cross(normal,tangent.xyz) * binormalSign * unity_WorldTransformParams.w;        
    }

    float GetMetallic (v2f i) {
        #if defined(_METALLIC_MAP)
            //有金属贴图时，_Metallic相当于一个调节因子
    	    return tex2D(_MetallicMap, i.uv.xy).r * _Metallic;
        #else
            return _Metallic;
        #endif
    }

    float3 GetEmission (v2f i) {
        #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
            #if defined(_EMISSION_MAP)
                return tex2D(_EmissionMap, i.uv.xy) * _Emission;
            #else
                #if defined(_EMISSION)
                    return _Emission;
                #else
                    return 0;
                #endif 
            #endif
        #else
            return 0;
        #endif
    }

    float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
	return cross(normal, tangent.xyz) *
		(binormalSign * unity_WorldTransformParams.w);
    }

    float GetSmoothness (v2f i) {
        float smoothness = 1;
        #if defined(_SMOOTHNESS_ALBEDO)
            smoothness = tex2D(_MainTex, i.uv.xy).a;
        #elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
            smoothness = tex2D(_MetallicMap, i.uv.xy).a;
        #endif
        return smoothness * _Smoothness;
    }

    float GetDetailMask (v2f i) {
        #if defined (_DETAIL_MASK)
            return tex2D(_DetailMask, i.uv.xy).a;
        #else
            return 1;
        #endif
    }

    float3 GetAlbedo (v2f i) {
        float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
        #if defined (_DETAIL_ALBEDO_MAP)
            float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
            albedo = lerp(albedo, albedo * details, GetDetailMask(i));
        #endif
        return albedo;
    }

    float GetAlpha (v2f i) {
        float alpha = _Color.a;
        #if !defined(_SMOOTHNESS_ALBEDO)
		    alpha *= tex2D(_MainTex, i.uv.xy).a;
	    #endif
	    return _Color.a * tex2D(_MainTex, i.uv.xy).a;
    }

    float3 GetTangentSpaceNormal(v2f i)
    {
        // //Unity 使用DXT5nm存储法线图,wy分量存储法线的xy部分，z值则由xy计算
        // normal.xy = tex2D(_NormalMap, i.uv).wy * 2 - 1; //[0,1] -> [-1,1]
        // normal.xy *= _BumpScale;
        // normal.z = sqrt(1 - saturate(dot(i.normal.xy, i.normal.xy)));
        // normal = normalize(normal);
        //UnityStandardUtils定义了UnpackScaleNormal执行相同操作
        float3 normal = float3(0, 0, 1);
        
        #if defined(_NORMAL_MAP)
            normal = UnpackScaleNormal(tex2D(_NormalMap,i.uv.xy),_BumpScale);
        #endif 

        #if defined(_DETAIL_NORMAL_MAP)
            //混合两张法线贴图，增加细节
            //混合方法1 ： 偏倒数相加
            //float3 normal = float3(mainNormal.xy / mainNormal.z + detailNormal.xy / detailNormal.z, 1);
            //混合方法2 ： whiteout blending ,放大了xy方向，使细节更明显，Unity内部也是使用此方法
            //float3 normal = float3(mainNormal.xy + detailNormal.xy, mainNormal.z * detailNormal.z);
            //UnityStandardUtils内定义的BlendNormals就是whiteout blending操作
            float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap,i.uv.zw),_DetailBumpScale);
            detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
            normal = BlendNormals(normal,detailNormal);
        #endif
        return normal;
    }

    //UnityCG 中关于UNITY_CALC_FOG_FACTOR_RAW宏的定义
    //在其中根据雾的计算模式，计算了unityFogFactor的值，用于片段源色与雾色插值
    //其中unity_FogParams存储根据雾参数预计算的值

	// x = density / sqrt(ln(2)), useful for Exp2 mode
	// y = density / ln(2), useful for Exp mode
	// z = -1/(end-start), useful for Linear mode
	// w = end/(end-start), useful for Linear mode
	//float4 unity_FogParams;

    // #if defined(FOG_LINEAR)
	// // factor = (end-z)/(end-start) = z * (-1/(end-start))+(end/(end-start))
	// #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = \
	// 	(coord) * unity_FogParams.z + unity_FogParams.w
    // #elif defined(FOG_EXP)
    //     // factor = exp(-density*z)
    //     #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = \
    //         unity_FogParams.y * (coord); \
    //         unityFogFactor = exp2(-unityFogFactor)
    // #elif defined(FOG_EXP2)
    //     // factor = exp(-(density*z)^2)
    //     #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = \
    //         unity_FogParams.x * (coord); \
    //         unityFogFactor = exp2(-unityFogFactor*unityFogFactor)
    // #else
    //     #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = 0.0
    // #endif

    //UnityCG中UNITY_Z_0_FAR_FROM_CLIPSPACE的实现
    //其中处理了D3D平台z轴反转问题
    // #if defined(UNITY_REVERSED_Z)
    //     //D3d with reversed Z =>
    //     //z clip range is [near, 0] -> remapping to [0, far]
    //     //max is required to protect ourselves from near plane not being
    //     //correct/meaningfull in case of oblique matrices.
    //     #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) \
    //         max(((1.0-(coord)/_ProjectionParams.y)*_ProjectionParams.z),0)
    // #elif UNITY_UV_STARTS_AT_TOP
    //     //D3d without reversed z => z clip range is [0, far] -> nothing to do
    //     #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
    // #else 
    //     //Opengl => z clip range is [-near, far] -> should remap in theory
    //     //but dont do it in practice to save some perf (range is close enought)
    //     #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
    // #endif

    float4 ApplyFog (float4 color, v2f i) {
        float3 fogColor = 0;
        #if defined(FORWARD_BASE_PASS)
            fogColor = unity_FogColor.rgb;
        #endif 
        #if FOG_ON 
            float viewDistance = length(_WorldSpaceCameraPos - i.worldPos);
            #if FOG_DEPTH
                viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
            #endif 
            UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
            //对于可能超出0-1的值要先saturate才能作为lerp的参数，
            //否则在手机上可能导致奇怪的表现
            color.rgb = lerp(fogColor, color, saturate(unityFogFactor));
        #endif
        return color;
    }

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

    void InitFragNormal(inout v2f i)
    {     
        //ddx用于求相邻两个片元p（x,y）与p（x+1,y）的差值（偏导数），这里传进的是worldPos,那么就会返回
        //相邻两个片元worldPos的差值
        // float3 dpdx = ddx(i.worldPos);
        // float3 dpdy = ddy(i.worldPos);
        // i.normal = normalize(cross(dpdy, dpdx));

        // float3 tangentSpaceNormal =  GetTangentSpaceNormal(i);

        // #if defined(BINORMAL_PER_FRAGMENT)
        //     float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
        // #else
        //     float3 binormal = i.binormal;
        // #endif
      	// i.normal = normalize( 
        //     tangentSpaceNormal.x * i.tangent +
        //     tangentSpaceNormal.y * binormal +
        //     tangentSpaceNormal.z * i.normal
	    // );
    } 

    //UnityApplyDitherCrossFade 的实现: 采样遮罩图，clip掉

    // sampler2D _DitherMaskLOD2D;
    // void UnityApplyDitherCrossFade(float2 vpos) {
    // 	vpos /= 4; // the dither mask texture is 4x4
    // 	// quantized lod fade by 16 levels
    // 	vpos.y = frac(vpos.y) * 0.0625 /* 1/16 */ + unity_LODFade.y;
    // 	clip(tex2D(_DitherMaskLOD2D, vpos).a - 0.5);
    // }

    float GetParallaxHeight(float2 uv)
    {
        return tex2D(_ParallaxMap, uv.xy).g;
    }

    float2 ParallaxOffset(float2 uv, float3 viewDir)
    {
        float height = GetParallaxHeight(uv);
        height -= 0.5f;//为了让低区域更低，高区域更高
        height *= _ParallaxStrength;
        //除以Z是为了获得更真实的透视投影效果, 视角越平，偏移越大。加0.42是为了防止分母为0
        float2 dir = viewDir.xy / (viewDir.z + 0.42);
        return dir * height;
    }

    float2 ParallaxRaymarching(float2 uv, float3 viewDir)
    {
        #if !defined(PARALLAX_RAYMARCHING_STEPS)
		    #define PARALLAX_RAYMARCHING_STEPS 10
	    #endif
        float2 uvOffset = 0;
        float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;
        float2 uvDelta = viewDir.xy * (stepSize * _ParallaxStrength); 
        float stepHeight = 1;
        float surfaceHeight = GetParallaxHeight(uv);

        float2 prevUVOffset = uvOffset;
        float prevStepHeight = stepHeight;
        float prevSurfaceHeight = surfaceHeight;

        //这里如果写成while (stepHeight > surfaceHeight) 编译器会报错，意思是不可在循环中采样 原因如下：
        //GPU在采样前会先确定Mipmap等级选择不同分辨率的贴图
        //而确定MipmapLevel的算法需要对比相邻几个frag的uv坐标，而这一算法需要所有frag执行相同的分支
        //当出现这种情况时，编译器会尝试展开循环，让每个frag都执行最大循环次数。（或者尝试调整代码结构，把采样代码移到循环外）
        //使用while时 编译器不知道最大次数展开不了，所以编译器才会报错。
        for(int i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight; i++)
        {
            prevUVOffset = uvOffset;
            prevStepHeight = stepHeight;
            prevSurfaceHeight = surfaceHeight;
            uvOffset -= uvDelta;
            stepHeight -= stepSize;
            surfaceHeight = GetParallaxHeight(uv + uvOffset);          
        }
        
        #if !defined(PARALLAX_RAYMARCHING_SEARCH_STEPS)
            #define PARALLAX_RAYMARCHING_SEARCH_STEPS 0
        #endif 

        #if PARALLAX_RAYMARCHING_SEARCH_STEPS > 0 
            //使用二分法逐步逼近碰撞点
            for(int i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEPS; i++)
            {
                uvDelta *= 0.5f;
                stepSize *= 0.5f;
                //用step优化分支
                uvOffset -= uvDelta;
                stepHeight -= stepSize;
                //a < b 返回 0 ， a > b 返回 1 
                fixed dir = step(stepHeight, surfaceHeight);
                uvOffset += 2 * dir * uvDelta;
                stepHeight += 2 * dir * stepSize;
                surfaceHeight =  GetParallaxHeight(uv + uvOffset);
            }
        #elif defined(PARALLAX_RAYMARCHING_INTERPOLATE) 
            //应用数学方法进行预测两步之间比较合理的碰撞点
            //细节见：https://catlikecoding.com/unity/tutorials/rendering/part-20/
            float prevDifference = prevStepHeight - prevSurfaceHeight;
            float difference = surfaceHeight - stepHeight;
            float t = prevDifference / (prevDifference + difference);
            //uvOffset = lerp(prevUVOffset, uvOffset, t);
            uvOffset = prevUVOffset - uvDelta * t;
        #endif
        return uvOffset;
    }

    void ApplyParallax(inout v2f i)
    {
        #if defined(_PARALLAX_MAP)
            i.tangentViewDir = normalize(i.tangentViewDir);
            // #if defined(PARALLAX_OFFSET_LIMITING)
            //     #define PARALLAX_BIAS 0.42
            // #endif 
            #if !defined(PARALLAX_FUNCTION)
			    #define PARALLAX_FUNCTION ParallaxOffset
		    #endif
            float2 uvOffset = PARALLAX_FUNCTION(i.uv.xy, i.tangentViewDir.xyz);
            i.uv.xy += uvOffset;
            //细节贴图uv也要偏移，细节贴图与主贴图尺寸、缩放不一致会导致偏移比例对不上。
            i.uv.zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy);
        #endif 
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

        float3 albedo = GetAlbedo(i);
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
