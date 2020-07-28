

    #if !defined(PART6_INCLUDED)
    #define PART6_INCLUDED
    
    #include "UnityPBSLighting.cginc" 
    #include "AutoLight.cginc" 

    #endif 

	struct appdata
    {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        float4 tangent : TANGENT;
    };

    struct v2f
    {
        float4 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float3 normal : TEXCOORD1;
        #if defined(BINORMAL_PER_FRAGMENT)//在frag方法里计算副法线
            float4 tangent : TEXCOORD2;
        #else
            //在vert方法里计算副法线
            float3 tangent : TEXCOORD2;
            float3 binormal : TEXCOORD3;
        #endif 
            float3 worldPos : TEXCOORD4;
        #if defined(SHADOW_SCREEN)
            //float4 shadowCoordinates : TEXCOORD5;
            //SHADOW_COORDS 也是定义shadowCoordinates
            SHADOW_COORDS(5)
        #endif 
        #if defined(VERTEXLIGHT_ON)
            float3 vertexLightColor : TEXCOORD6;
        #endif
    };

    fixed4 _Tint;
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

    fixed _AlphaCutoff;


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

    //AutoLight中的UNITY_LIGHT_ATTENUATION关于点光源的具体实现
    //这里用了一张1维的衰减纹理存储衰减的值
    // #ifdef POINT
    // uniform sampler2D __LightTexture0;
    // uniform unityShadowCoord4x4 _unity_WorldToLight;
    // #define _UNITY_LIGHT_ATTENUATION(destName, input, worldPos)  
    //     unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz;
    //     fixed destName = (tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr). 
    //         UNITY_ATTEN_CHANNEL * SHADOW_ATTENUATION(input));
    // #endif

    //AutoLight中的UNITY_LIGHT_ATTENUATION关于聚光灯光源的具体实现
    // _LightTexture0是光源遮罩贴图，可以自己指定
    // #ifdef SPOT
    // uniform sampler2D _LightTexture0;
    // uniform unityShadowCoord4x4 unity_WorldToLight;
    // uniform sampler2D _LightTextureB0;
    // inline fixed UnitySpotCookie(unityShadowCoord4 LightCoord) {
    //      return tex2D(_LightTexture0, LightCoord.xy / LightCoord.w + 0.5).w;
    // }
    // inline fixed UnitySpotAttenuate(unityShadowCoord3 LightCoord) {
    //      return tex2D(_LightTextureB0, dot(LightCoord, LightCoord).xx).UNITY_ATTEN_CHANNEL;
    // }
    // #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) 
    //      unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); 
    //      fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * 
    //          UnitySpotAttenuate(lightCoord.xyz) * SHADOW_ATTENUATION(input);
    // #endif
    // 
    //AutoLight中的UNITY_LIGHT_ATTENUATION关于带cookie的平行光源的具体实现
    // _LightTexture0是光源遮罩贴图，可以自己指定
    // #ifdef DIRECTIONAL_COOKIE
    // uniform sampler2D _LightTexture0;
    // uniform unityShadowCoord4x4 unity_WorldToLight;
    // #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) 
    //     unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; 
    //     fixed destName = tex2D(_LightTexture0, lightCoord).w * SHADOW_ATTENUATION(input);
    //         
    // #endif

    //AutoLight中的UNITY_LIGHT_ATTENUATION关于带cookie的点光源的具体实现
    //这里cookie贴图_LightTexture0是一张cubemap
    // #ifdef POINT_COOKIE
    // uniform samplerCUBE _LightTexture0;
    // uniform unityShadowCoord4x4 unity_WorldToLight;
    // uniform sampler2D _LightTextureB0;
    // #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) 
    //     unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; 
    //     fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL *
    //           texCUBE(_LightTexture0, lightCoord).w * SHADOW_ATTENUATION(input);
    // #endif

    //根据光的类型返回相应的UnityLight结构体
    //UnityLight保存并不是当前光源的信息，
    //而是当前光源对于当前片元的信息
    UnityLight CreateLight(v2f i)
    {
        UnityLight light;
        #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
            light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
        #else
            //平行光没有光源位置，所以_WorldSpaceLightPos0.xyz就是光的方向
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif

        float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos;
        //计算光强，光强随距离增大而减小，如点光源.分母+1是为了防止距离过近是attenuation变得很大
        //float attenuation = 1 / (1 + dot(lightVec,lightVec)); 
        // #if defined(SHADOW_SCREEN)
        //     //采样当前光源生成的屏幕阴影纹理 
        //     float attenuation = tex2D(_ShadowMapTexture, i.shadowCoordinates.xy / i.shadowCoordinates.w);
        //      SHADOW_ATTENUATION 执行了与上面相同的计算
        //      float attenuation = SHADOW_ATTENUATION(i);
        // #else
        //#endif
        //UNITY_LIGHT_ATTENUATION里面有判断SHADOW_SCREEN宏并进行相应计算的操作
        //并且根据不同光源，对阴影的采样也不同
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
        light.color = _LightColor0.rgb * attenuation;
        light.ndotl = DotClamped(i.normal,light.dir);
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
    UnityIndirect CreateIndirectLight(v2f i, float3 viewDir)
    {
        UnityIndirect indirectLight;
        indirectLight.diffuse = 0;
        indirectLight.specular = 0;
        #if defined(VERTEXLIGHT_ON)
            indirectLight.diffuse = i.vertexLightColor;
        #endif

        #if defined(FORWARD_BASE_PASS)
            indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
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
            envData.reflUVW = BoxProjection(i.worldPos, reflectDir, unity_SpecCube0_ProbePosition, 
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
                    envData.reflUVW = BoxProjection(i.worldPos, reflectDir, unity_SpecCube1_ProbePosition, 
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
        #endif

        return indirectLight;
    }

    //UnityCG中Shade4PointLights函数具体实现
    // float3 _Shade4PointLights (
    //     float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    //     float3 lightColor0, float3 lightColor1,
    //     float3 lightColor2, float3 lightColor3,
    //     float4 lightAttenSq, float3 pos, float3 normal) {
    //     // to light vectors
    //     float4 toLightX = lightPosX - pos.x;
    //     float4 toLightY = lightPosY - pos.y;
    //     float4 toLightZ = lightPosZ - pos.z;
    //     // squared lengths
    //     float4 lengthSq = 0;
    //     lengthSq += toLightX * toLightX;
    //     lengthSq += toLightY * toLightY;
    //     lengthSq += toLightZ * toLightZ;
    //     // NdotL
    //     float4 ndotl = 0;
    //     ndotl += toLightX * normal.x;
    //     ndotl += toLightY * normal.y;
    //     ndotl += toLightZ * normal.z;
    //     // correct NdotL 
    //     // rsqrt（x） = 1/ 根号x
    //     float4 corr = rsqrt(lengthSq);
    //     ndotl = max(float4(0,0,0,0), ndotl * corr);
    //     // attenuation
    //     float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
    //     float4 diff = ndotl * atten;
    //     // final color
    //     float3 col = 0;
    //     col += lightColor0 * diff.x;
    //     col += lightColor1 * diff.y;
    //     col += lightColor2 * diff.z;
    //     col += lightColor3 * diff.w;
    //     return col;
    // }

    //UnityStandardUtils中UnpackScaleNormal的实现 内部判断了是否使用DXT5nm格式的法线贴图
    // half3 UnpackScaleNormal (half4 packednormal, half bumpScale) {
    // #if defined(UNITY_NO_DXT5nm)
    //     return packednormal.xyz * 2 - 1;
    // #else
    //     half3 normal;
    //     normal.xy = (packednormal.wy * 2 - 1);
    //     #if (SHADER_TARGET >= 30)
    //         // SM2.0: instruction count limitation
    //         // SM2.0: normal scaler is not supported
    //         normal.xy *= bumpScale;
    //     #endif
    //     normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
    //     return normal;
    // #endif
    // }

    //UnityStandardUtils中的BlendNormals具体实现 
    // half3 BlendNormals (half3 n1, half3 n2) {
    //     return normalize(half3(n1.xy + n2.xy, n1.z * n2.z));
    // }

    //UnityCG中ComputeScreenPos的具体实现，当需要翻转Y坐标时，_ProjectParams.x变量为-1
    //在使用Direct3D9时，它会注意纹理对齐。在进行单遍立体渲染时，还需要特殊的逻辑。
    // inline float4 ComputeNonStereoScreenPos (float4 pos) {
    //     float4 o = pos * 0.5f;
    //     #if defined(UNITY_HALF_TEXEL_OFFSET)
    //         o.xy = float2(o.x, o.y * _ProjectionParams.x) +
    //             o.w * _ScreenParams.zw;
    //     #else
    //         o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
    //     #endif
    //     o.zw = pos.zw;
    //     return o;
    // }

    // inline float4 ComputeScreenPos (float4 pos) {
    //     float4 o = ComputeNonStereoScreenPos(pos);
    //     #ifdef UNITY_SINGLE_PASS_STEREO
    //         o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);
    //     #endif
    //     return o;
    // }

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
            unity_4LightAtten0, i.worldPos, i.normal
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
        #if defined(FORWARD_BASE_PASS)
            #if defined(_EMISSION_MAP)
                return tex2D(_EmissionMap, i.uv.xy) * _Emission;
            #else
                return _Emission;
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
        float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
        #if defined (_DETAIL_ALBEDO_MAP)
            float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
            albedo = lerp(albedo, albedo * details, GetDetailMask(i));
        #endif
        return albedo;
    }

    float GetAlpha (v2f i) {
        float alpha = _Tint.a;
        #if !defined(_SMOOTHNESS_ALBEDO)
		    alpha *= tex2D(_MainTex, i.uv.xy).a;
	    #endif
	    return _Tint.a * tex2D(_MainTex, i.uv.xy).a;
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
            normal = BlendNormals(mainNormal,detailNormal);
        #endif
        return normal;
    }

    v2f vert (appdata v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.worldPos = mul(unity_ObjectToWorld,v.vertex);
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
        #if defined(SHADOW_SCREEN)
            // i.shadowCoordinates.xy = (i.position.xy + i.position.w) * 0.5;// i.position;      
            // i.shadowCoordinates.zw = i.position.zw;   
            //ComputeScreenPos执行了与上面相同的计算，只不过加了比如不同平台屏幕坐标原点差异等处理
            //i.shadowCoordinates = ComputeScreenPos(i.position);
            //TRANSFER_SHADOW执行了以上相同的运算，差异在于要求变量名必须为shadowCoordinates，
            //与SHADOW_COORDS搭配使用
            TRANSFER_SHADOW(i);
        #endif  
        //TRRANSFORM_TEX确保在贴图有缩放和偏移的情况下仍能返回正确的uv
        o.uv.xy = TRANSFORM_TEX(v.uv,_MainTex);
        o.uv.zw = TRANSFORM_TEX(v.uv,_DetailTex);
        ComputeVertexLightColor(o);
        return o;
    }

    void InitFragNormal(inout v2f i)
    {       
        float3 tangentSpaceNormal =  GetTangentSpaceNormal(i);

        #if defined(BINORMAL_PER_FRAGMENT)
            float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
        #else
            float3 binormal = i.binormal;
        #endif
      	i.normal = normalize(
            tangentSpaceNormal.x * i.tangent +
            tangentSpaceNormal.y * binormal +
            tangentSpaceNormal.z * i.normal
	    );
    } 

 	fixed4 frag (v2f i) : SV_Target
    {
        float alpha = GetAlpha(i);
        #if defined(_RENDERING_CUTOUT)
		    clip(alpha - _AlphaCutoff);
	    #endif


        // //不同单位长度的法线经过差值后不能得到单位向量，需要再归一化
        // i.normal = normalize(i.normal);
        InitFragNormal(i);

        //也可以在顶点函数计算视角方向并插值，但可能存在过渡不平缓的情况
        float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

        //Blinn-Phong模型，近似模拟Blinn模型
        //避免计算 reflect(-lightDir, i.normal); 
        //reflect 计算公式为： D - 2N(N·D) ,推导过程网上有
        //float3 halfVector = normalize(lightDir + viewDir);

        // float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
        // albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble; 
        float3 albedo = GetAlbedo(i);

        //使用金属工作流时，高光颜色由反射率乘以金属度
        float3 _SpecularTint = albedo * _Metallic;


        //当入射 DotClamped(halfVector,i.normal)表示的是当halfVector与normal重合度
        //越高反射光强度越强
        //金属的镜面反射往往是彩色的，这里用_SpecularTint来模拟
        //float3 specular = _SpecularTint.rgb * lightColor * pow(DotClamped(halfVector,i.normal), _Smoothness * 100);
        
        //保证能量守恒，高光与漫反射相加的和小于等于1，
        //UnityStandardUtils 中定义的 EnergyConservationBetweenDiffuseAndSpecular做的就是相同操作
        // float oneMinusReflectivity = 1 - max(_SpecularTint.r,max(_SpecularTint.g,_SpecularTint.b));
        //albedo *= oneMinusReflectivity;
 
        float oneMinusReflectivity;
        //oneMinusReflectivity 在方法里面计算并返回
        // albedo = EnergyConservationBetweenDiffuseAndSpecular(
        //     albedo, _SpecularTint.rgb, oneMinusReflectivity
        // );
        //以上得到的 albedo 的计算过程是简化了的，实际上高光强度和反射率不只与金属度相关，
        //还与颜色空间有关，UnityStandardUtils了提供DiffuseAndSpecularFromMetallic 方法
        //在进行以上操作时还加入了与颜色空间相关的操作
        albedo = _DiffuseAndSpecularFromMetallic(
            albedo, GetMetallic(i), _SpecularTint, oneMinusReflectivity
        );

        //能量守恒：同一束光不能既被反射，又穿过对象。
        //因此，无论其固有的透明性如何，反射性越强，穿过它的光线越少。
        #if defined(_RENDERING_TRANSPARENT)
		    albedo *= alpha;
            alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
	    #endif
      
        //DotClamped定义在UnityStandardBRDF,等价于 saturate(dot(a,b));
        //float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);
        

        float4 color = UNITY_BRDF_PBS(  albedo, _SpecularTint,
                                        oneMinusReflectivity, GetSmoothness(i),
                                        i.normal, viewDir,
                                        CreateLight(i), CreateIndirectLight(i, viewDir)
                                     );
        color.rgb += GetEmission(i);
        #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
            color.a = alpha;
        #endif
        return color;                            
    }