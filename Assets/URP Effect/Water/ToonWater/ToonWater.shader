Shader "Custom/ToonWater"
{
    Properties
    {
        [Header(Depth)]
        _MaxDepth("最大深度", Range(0, 1000)) = 10
        [HDR]_DepthColor("深水区颜色", Color) = (0,0,1,1)
        [HDR]_ShallowColor("浅水区颜色", Color) = (0,1,1,1)

        [Header(Foam)]
        _SurfaceNoise("水面噪声贴图", 2D) = "white" {}
        _SurfaceNoiseCutoff("噪声贴图裁切", Range(0, 1)) = 0.777
        _FoamMaxDistance("Foam Maximum Distance", Range(0,10)) = 0.4
        _FoamMinDistance("Foam Minimum Distance", Range(0,10)) = 0.04
        _FoamEdgeFade("Foam Edge Fade", Range(0,1)) = 0.5

        [Header(FlowMap)]
        _FlowMap("FlowMap", 2D) = "white" {}
        _FlowSpeed("向量场速度", Range(0, 10)) = 1

        [Header(Settings)]
        _TimeSpeed("水流速度", Vector) = (0.03,0.03,0,1)

        [Header(Refract)]
        _RefractFactor("折射系数", Range(0, 100)) = 1
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalScale("NormalScale", Range(0, 10)) = 1
        
        
        [Header(Reflect)]
        _SpecularPower("SpecularPower", Range(0, 256)) = 32
        _SpecularScale("SpecularScale", Range(0, 100)) = 1
        _FresnelPower("FresnelPower", Range(0, 32)) = 5
        _FresnelScale("FresnelScale", Range(0, 10)) = 1
        _CubeMap("CubeMap", CUBE) = "white" {}
        _ReflectNormalLerp("ReflectNormalLerp", Range(0, 1)) = 0.05
    
        [Header(caustic)]
        _CausticTex("CausticTex", 2D) = "white" {}
        
        
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
    float _NormalScale;
    float _MaxDepth;
    float4 _DepthColor;
    float4 _ShallowColor;

    float4 _NormalMap_ST;
    float4 _SurfaceNoise_ST;
    float _SurfaceNoiseCutoff;
    float _FoamMaxDistance;
    float _FoamMinDistance;
    float _FoamEdgeFade;
    float2 _TimeSpeed;
    

    float _FlowSpeed;


    float _RefractFactor;
    float _SpecularPower;
    float _SpecularScale;
    float _FresnelPower;
    float _FresnelScale;
    float _ReflectNormalLerp;
    float4 _CausticTex_ST;

    CBUFFER_END

    TEXTURE2D(_NormalMap);
    SAMPLER(sampler_NormalMap);
    TEXTURE2D(_SurfaceNoise);
    SAMPLER(sampler_SurfaceNoise);
    TEXTURE2D(_FlowMap);
    SAMPLER(sampler_FlowMap);
    TEXTURE2D(_CausticTex);
    SAMPLER(sampler_CausticTex);
    TEXTURE2D(_CameraOpaqueTexture);
    SAMPLER(sampler_CameraOpaqueTexture);
    TEXTURECUBE(_CubeMap);
    SAMPLER(sampler_CubeMap);
    float4 _CameraOpaqueTexture_TexelSize;
    SAMPLER(sampler_unity_SpecCube0);


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
        float2 noiseUV : TEXCOORD7;
        float3 positionVS : TEXCOORD8;
        float3 normalVS : TEXCOORD9;
        float2 normalUV : TEXCOORD10;
    };
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }
        Cull Off
        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);

                o.uv = i.uv;
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;
                o.positionVS = vertexInput.positionVS;

                //TBN
                o.normalWS = normalInput.normalWS;
                o.normalVS = TransformWorldToViewNormal(o.normalWS);
                o.tangentWS = float4(normalInput.tangentWS.xyz, i.tangentOS.w * GetOddNegativeScale());
                o.bitangentWS = normalInput.bitangentWS;

                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);

                //扰动UV
                o.normalUV = TRANSFORM_TEX(float2(i.uv + _TimeSpeed*_Time.y), _NormalMap);
                o.noiseUV = TRANSFORM_TEX(float2(i.uv + _TimeSpeed*_Time.y), _SurfaceNoise);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //--------------------------------------------
                // 折射
                //--------------------------------------------
                //屏幕UV
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                //扭曲：法线纹理采样

                //法线贴图扰动屏幕UV
                float3 normalMap = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.normalUV), _NormalScale);
                float3x3 TBN = CreateTangentToWorld(i.normalWS, i.tangentWS.xyz, i.tangentWS.w);
                float3 N = TransformTangentToWorld(normalMap, TBN, true);
                float2 bias = N.xy * _CameraOpaqueTexture_TexelSize.xy * _RefractFactor;
                float2 ScreenUVRefract = ScreenUV + bias;

                //--------------------------------------------
                // 基于深度着色
                //--------------------------------------------
                //1 水下不透明物体在深度纹理中的观察空间深度
                //没有被扰动的
                #if UNITY_REVERSED_Z
                float opaqueDepth = SampleSceneDepth(ScreenUV);
                #else
                float opaqueDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV)); 
                #endif
                float opaqueDepthVS = LinearEyeDepth(opaqueDepth, _ZBufferParams);

                //被扰动的
                #if UNITY_REVERSED_Z
                float opaqueDepthRefract = SampleSceneDepth(ScreenUVRefract);
                #else
                float opaqueDepthRefract = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUVRefract)); 
                #endif
                float opaqueDepthRefractVS = LinearEyeDepth(opaqueDepthRefract, _ZBufferParams); //线性

                //2 水面的观察空间深度
                float waterSurfaceDepth = i.positionCS.w; //或= -i.positionVS.z
                //3 计算水深
                float waterDepth = opaqueDepthVS - waterSurfaceDepth;
                float waterDepthRefract = opaqueDepthRefractVS - waterSurfaceDepth;

                //4 除以最大水深，归一化深度
                float waterDepthNormalize = saturate(waterDepthRefract / _MaxDepth);
                //5 插值深度着色
                float4 waterColor = lerp(_ShallowColor, _DepthColor, waterDepthNormalize);

                //--------------------------------------------
                // 判断水上水下，水上用屏幕UV，水下用扭曲UV，来采样不透明纹理
                //--------------------------------------------
                if (waterDepth < 0)
                {
                    ScreenUVRefract = ScreenUV;
                }
                float4 OpaqueTexture = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture,ScreenUVRefract);

                //--------------------------------------------
                // 泡沫(采用未扰动的UV和深度)
                //--------------------------------------------
                //FlowMap来处理噪声贴图
                float3 flowDir = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, i.uv).rgb * 2.0 - 1.0;
                flowDir *= _FlowSpeed;
                float phase0 = frac(_Time.y * _TimeSpeed.x);
                float phase1 = frac(_Time.y * _TimeSpeed.x + 0.5);
                float tex0 = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, i.noiseUV-flowDir.xy*phase0).r;
                float tex1 = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, i.noiseUV-flowDir.xy*phase1).r;
                float NoiseFlowTex = lerp(tex0, tex1, abs((0.5 - phase0) / 0.5));

                //泡沫深度
                float3 NormalsTexture = normalize(SampleSceneNormals(ScreenUV));

                float normalDot = saturate(dot(NormalsTexture, i.normalVS)); //法线纹理点积观察空间法线

                float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
                float foamDepthDifference = saturate(waterDepth / foamDistance);

                //越深裁剪值越大
                float FoamNoiseCutoff = foamDepthDifference * _SurfaceNoiseCutoff;
                //抗锯齿：平滑过渡
                float FoamNoise = smoothstep(FoamNoiseCutoff - _FoamEdgeFade, FoamNoiseCutoff + _FoamEdgeFade,
                NoiseFlowTex);

                //--------------------------------------------
                // 反射
                //--------------------------------------------
                //高光反射
                //向量计算
                float3 L = normalize(_MainLightPosition.xyz);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);
                float3 ReflectN= lerp(i.normalWS, N, _ReflectNormalLerp);
                float NdotH = dot(N, H);
                float3 specular = pow(max(0, NdotH), _SpecularPower) * _SpecularScale  * _MainLightColor.rgb;
                
                //Fresnel
                float fresnel = pow(1 - saturate(dot(i.normalWS, V)), _FresnelPower) * _FresnelScale;

                //环境反射
                //CubeMap
                float3 R = normalize(reflect(-V, ReflectN)); 
                float4 cubeMap = SAMPLE_TEXTURECUBE(_CubeMap,sampler_CubeMap, R); 
                float3 cubeMapcolor = DecodeHDREnvironment(cubeMap, unity_SpecCube0_HDR);
                //实时环境反射：反射探针
                // float4 environment = SAMPLE_TEXTURECUBE(unity_SpecCube0,sampler_unity_SpecCube0, R); 
                // float3 envcolor = DecodeHDREnvironment(environment, unity_SpecCube0_HDR); 
                
                
                //--------------------------------------------
                // 焦散(深度重建世界坐标xz分量采样焦散贴图)
                //--------------------------------------------
                 // float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, opaqueDepthRefract, UNITY_MATRIX_I_VP);
                 // float4 CausticTex = SAMPLE_TEXTURE2D(_CausticTex, sampler_CausticTex, float2((rebuildPosWS.xz + _TimeSpeed * _Time.y) * _CausticTex_ST.xy +_CausticTex_ST.zw))*waterDepth;
                //卡通水
                float4 finalColor = waterColor * OpaqueTexture + FoamNoise+float4(cubeMapcolor+specular+fresnel,1);

                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}