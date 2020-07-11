Shader "X_Shader/Standard/Part1_MetallicWorkFlow"
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
    }
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
            //#include "UnityCG.cginc"
            //UnityStandardBRDF有引用UnityCG，所以include一个就行
            //#include "UnityStandardBRDF.cginc"
            //#include "UnityStandardUtils.cginc"
            //UnityPBSLighting包含以上两个
            #include "UnityPBSLighting.cginc" 

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;      
                float3 worldPos :TEXCOORD2;
            };

            fixed4 _Tint;
            fixed4 _MainTex_ST;
            float _Smoothness;
            //float4 _SpecularTint;
            float _Metallic;
            sampler2D _MainTex;

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




            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                //合批后本地空间的法线方向会改变，所以需要变换到世界空间
                //将法线变换到世界空间，如果直接用unity_ObjectToWorld变换，缩放后法线会受影响
                //公式的推导参考<shader入门精要>                
                o.normal = mul(transpose((float3x3)unity_WorldToObject),v.normal);
                o.normal = normalize(o.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                //UnityCG 提供了相同操作的接口 UnityObjectToWorldNormal
                //o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 _frag (v2f i) : SV_Target
            {
                //不同单位长度的法线经过差值后不能得到单位向量，需要再归一化
                i.normal = normalize(i.normal);
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 lightColor = _LightColor0.rgb;

                //也可以在顶点函数计算视角方向并插值，但可能存在过渡不平缓的情况
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                //Blinn-Phong模型，近似模拟Blinn模型
                //避免计算 reflect(-lightDir, i.normal); 
                //reflect 计算公式为： D - 2N(N·D) ,推导过程网上有
                float3 halfVector = normalize(lightDir + viewDir);


                float3 albedo = tex2D(_MainTex,i.uv).rgb * _Tint.rgb;

                //使用金属工作流时，高光颜色由反射率乘以金属度
                float3 _SpecularTint = albedo * _Metallic;


                //当入射 DotClamped(halfVector,i.normal)表示的是当halfVector与normal重合度
                //越高反射光强度越强
                //金属的镜面反射往往是彩色的，这里用_SpecularTint来模拟
                float3 specular = _SpecularTint.rgb * lightColor * pow(DotClamped(halfVector,i.normal), _Smoothness * 100);
                
                //保证能量守恒，高光与漫反射相加的和小于等于1，
                //UnityStandardUtils 中定义的 EnergyConservationBetweenDiffuseAndSpecular做的就是相同操作
                // float oneMinusReflectivity = 1 - max(_SpecularTint.r,max(_SpecularTint.g,_SpecularTint.b));
                //albedo *= oneMinusReflectivity;

                float oneMinusReflectivity;
                //oneMinusReflectivity 在方法里面计算并返回
                albedo = EnergyConservationBetweenDiffuseAndSpecular(
                    albedo, _SpecularTint.rgb, oneMinusReflectivity
                );

                //以上得到的 albedo 是的计算过程是简化了的，实际上高光强度和反射率不只与金属度相关，
                //还与颜色空间有关，UnityStandardUtils了提供DiffuseAndSpecularFromMetallic 方法在进行
                //以上操作时还加入了与颜色空间相关的操作
                albedo = _DiffuseAndSpecularFromMetallic(
                    albedo, _Metallic, _SpecularTint.rgb, oneMinusReflectivity
                );

                //DotClamped定义在UnityStandardBRDF,等价于 saturate(dot(a,b));
                float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);

                return float4(diffuse+specular,1);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //不同单位长度的法线经过差值后不能得到单位向量，需要再归一化
                i.normal = normalize(i.normal);
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 lightColor = _LightColor0.rgb;

                //也可以在顶点函数计算视角方向并插值，但可能存在过渡不平缓的情况
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                //Blinn-Phong模型，近似模拟Blinn模型
                //避免计算 reflect(-lightDir, i.normal); 
                //reflect 计算公式为： D - 2N(N·D) ,推导过程网上有
                float3 halfVector = normalize(lightDir + viewDir);


                float3 albedo = tex2D(_MainTex,i.uv).rgb * _Tint.rgb;

                //使用金属工作流时，高光颜色由反射率乘以金属度
                float3 _SpecularTint = albedo * _Metallic;


                //当入射 DotClamped(halfVector,i.normal)表示的是当halfVector与normal重合度
                //越高反射光强度越强
                //金属的镜面反射往往是彩色的，这里用_SpecularTint来模拟
                float3 specular = _SpecularTint.rgb * lightColor * pow(DotClamped(halfVector,i.normal), _Smoothness * 100);
                
                //保证能量守恒，高光与漫反射相加的和小于等于1，
                //UnityStandardUtils 中定义的 EnergyConservationBetweenDiffuseAndSpecular做的就是相同操作
                // float oneMinusReflectivity = 1 - max(_SpecularTint.r,max(_SpecularTint.g,_SpecularTint.b));
                //albedo *= oneMinusReflectivity;

                float oneMinusReflectivity;
                //oneMinusReflectivity 在方法里面计算并返回
                // albedo = EnergyConservationBetweenDiffuseAndSpecular(
                //     albedo, _SpecularTint.rgb, oneMinusReflectivity
                // );

                //以上得到的 albedo 是的计算过程是简化了的，实际上高光强度和反射率不只与金属度相关，
                //还与颜色空间有关，UnityStandardUtils了提供DiffuseAndSpecularFromMetallic 方法在进行
                //以上操作时还加入了与颜色空间相关的操作
                albedo = _DiffuseAndSpecularFromMetallic(
                    albedo, _Metallic, _SpecularTint.rgb, oneMinusReflectivity
                );
                //DotClamped定义在UnityStandardBRDF,等价于 saturate(dot(a,b));
                float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);

                UnityLight light;
                light.color = lightColor;
                light.dir = lightDir;
                light.ndotl = DotClamped(i.normal, lightDir);
                UnityIndirect indirectLight;
                indirectLight.diffuse = 0;
                indirectLight.specular = 0;

                //UNITY_BRDF_PBS除了执行以上操作还有一些额外的数学运算
                //用于模拟更真实的效果
                return UNITY_BRDF_PBS(
                        albedo, _SpecularTint,
                        oneMinusReflectivity, _Smoothness,
                        i.normal, viewDir,
                        light, indirectLight
                    );

                return float4(diffuse+specular,1);
            }
            ENDCG
        }
    }
}
