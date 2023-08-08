Shader "Custom/FastSSS"
{
    Properties
    {

        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalScale("NormalScale", Range(0, 10)) = 1

        [Header(Specular)]
        _SpecularExp("SpecularExp", Range(1, 100)) = 32
        _SpecularStrength("SpecularStrength", Range(0, 10)) = 1
        _SpecularColor("SpecularColor", Color) = (1,1,1,1)

        [Header(SSS)]
        _Distortion("Distortion", Range(0, 1)) = 0
        //次表面扰动
        _BackLightPower("BackLightPower", Range(0, 5)) = 1
        //背光扩散
        _BackLightScale("BackLightScale", Range(0, 5)) = 1
        _BackLightColor("BackLightColor", Color) = (1,1,1,1)
        //局部厚度
        _ThicknessMap("ThicknessMap", 2D) = "white" {}
        
        [Header(Toggle)]
        [Toggle] _AdditionalLights("开启多光源", Float) = 1
        [Toggle] _Cut("透明度裁剪", Float) = 1
        _Cutoff("透明度裁剪阈值", Range(0, 1)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="TransparentCutout"
            "Queue"="AlphaTest"
        }
        Cull Off
        HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        //开启多光源关键字
        #pragma shader_feature _ADDITIONALLIGHTS_ON

        //透明度裁剪关键字
        #pragma shader_feature _CUT_ON

        //阴影关键字
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS                          //接收阴影
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE                  //TransformWorldToShadowCoord
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS                    //额外光源阴影
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS //开启额外光源计算
        #pragma multi_compile _ _SHADOWS_SOFT                                //软阴影
    
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _BaseColor;
        float _NormalScale;
        float _SpecularExp;
        float _SpecularStrength;
        float4 _SpecularColor;
        float _Distortion;
        float _BackLightPower;
        float _BackLightScale;
        float4 _BackLightColor;
        float _Cutoff;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_NormalMap);
        SAMPLER(sampler_NormalMap);
        TEXTURE2D(_ThicknessMap);
        SAMPLER(sampler_ThicknessMap);
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float4 color : COLOR;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float4 color : COLOR0;
            float2 uv : TEXCOORD0;
            float3 positionWS: TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float4 tangentWS : TEXCOORD3;
            float3 bitangentWS : TEXCOORD4;
            float3 viewDirWS : TEXCOORD5;
            float3 lightDirWS : TEXCOORD6;
        };
        ENDHLSL
        
        //阴影接收pass
        Pass
        {
            Tags
            {
                 "LightMode"="UniversalForward"
            }
            
            Cull off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile_instancing
            
            
            Varyings vert(Attributes i)
            { 
                Varyings o = (Varyings)0;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);

                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;

                //TBN
                o.normalWS = normalInput.normalWS;
                real sign = i.tangentOS.w * GetOddNegativeScale();
                o.tangentWS = float4(normalInput.tangentWS.xyz, sign);
                o.bitangentWS = normalInput.bitangentWS;
                
                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);

                return o;
            }
            
            //多光源光照计算
            float3 AdditionalLighting(float3 normalWS,float3 viewDirWS, float3 lightDirWS , float3 lightColor, float lightAttenuation,float thickness)
            {
                float3 H = normalize(lightDirWS + viewDirWS);       //正面光照的半角向量
                float3 H_back = lightDirWS + normalWS * _Distortion;  //背面光照的半角向量
                float NdotL = dot(normalWS, lightDirWS);
                float NdotH = dot(normalWS, H);
                float VdotNegativeH = dot(viewDirWS, -H_back);

                //多光源正面光照
                float3 diffuse = (0.5 * NdotL + 0.5) * _BaseColor.rgb * lightColor;
                float3 specular = pow(max(0, NdotH), _SpecularExp) * _SpecularStrength * _SpecularColor.rgb * lightColor;
                float3 addColor_front = diffuse + specular;

                //多光源背面光照
                float3 addColor_back = pow(saturate(VdotNegativeH), _BackLightPower) * _BackLightScale * _BackLightColor.rgb * thickness * lightColor ;

                return (addColor_front + addColor_back) * lightAttenuation;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //获取阴影坐标
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                
                //主光源(传入阴影坐标)
                Light mainLight = GetMainLight(shadowCoord);

                //纹理采样
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                #if _CUT_ON
                    clip(MainTex.a - _Cutoff);
                #endif
                
                float3 normalMap = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);
                float thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_ThicknessMap, i.uv).r;
                //向量计算
                float3x3 TBN = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz);
                float3 N = TransformTangentToWorld(normalMap, TBN, true);
                float3 L = normalize(_MainLightPosition.xyz);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);        //正面光照的半角向量
                float3 H_back = L + N * _Distortion;  //背面光照的半角向量
                float NdotL = dot(N, L);
                float NdotH = dot(N, H);
                float VdotNegativeH = dot(V, -H_back);
                
                //主光源颜色计算（乘阴影衰减）
                float3 diffuse = (0.5 * NdotL + 0.5) * _BaseColor.rgb * mainLight.color;
                
                float3 specular = pow(max(0, NdotH), _SpecularExp) * _SpecularStrength * _SpecularColor.rgb * mainLight.color;
                //主光正面光照
                float3 mainColor_front = (diffuse + specular)* mainLight.shadowAttenuation;
                //主光背面光照
                float3 mainColor_back = pow(saturate(VdotNegativeH), _BackLightPower) * _BackLightScale * _BackLightColor.rgb * thickness * mainLight.color;
                float3 mainColor = mainColor_front + mainColor_back;
                
                //其他光源颜色计算
                //如果开启多光源
                float3 addColor = float3(0, 0, 0);
                #if _ADDITIONALLIGHTS_ON
                int addLightsCount = GetAdditionalLightsCount();
                for (int index = 0; index < addLightsCount; index++)
                {
                    Light addLight = GetAdditionalLight(index, i.positionWS);
                    
                    // 注意light.distanceAttenuation * light.shadowAttenuation，这里已经将距离衰减与阴影衰减进行了计算
                    addColor += AdditionalLighting(N,V, normalize(addLight.direction),  addLight.color, addLight.distanceAttenuation * addLight.shadowAttenuation,thickness);
                }
                #endif
                
                float4 finalColor = MainTex * float4(mainColor + addColor + _GlossyEnvironmentColor.rgb, 1);
                return finalColor;
            }
            ENDHLSL
        }
        
        //阴影投射pass
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0  //只保存阴影信息，不需要颜色绘制
            Cull Off

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            //获得齐次裁剪空间下的阴影坐标
            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
            
                //光源方向
                //为什么只传了主光源方向，点光源也可以投射阴影
                //这个PASS走的 是 记录灯光视角下深度，点光源使用这个方向计算是错的，但只是影响一点offset，所以点光源还是能看到影子
                float3 lightDirectionWS = _MainLightPosition.xyz;

                //ApplyShadowBias()得到经过深度偏移和法线偏移后的世界空间阴影坐标
                //然后转换到齐次裁剪空间
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

            //反向Z防止Z-Fighting
            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif

                return positionCS;
            }
            
            Varyings ShadowPassVertex(Attributes i)
            {
                Varyings o = (Varyings)0;
                o.uv = i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.positionCS = GetShadowPositionHClip(i);
                return o;
            }

            half4 ShadowPassFragment(Varyings i) : SV_TARGET
            {
                //纹理采样
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                #if _CUT_ON
                    clip(MainTex.a - _Cutoff);
                #endif
                
                return 0;
            }
            ENDHLSL
        }
    }
            
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}