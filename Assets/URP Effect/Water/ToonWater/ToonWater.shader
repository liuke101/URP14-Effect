Shader "Custom/ToonWater"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalScale("NormalScale", Range(0, 10)) = 1

        [Header(Depth)]
        _DepthDifference("深度差", Range(0, 100)) = 10
        [HDR]_DepthColor("深水区颜色", Color) = (0,0,1,1)
        [HDR]_ShallowColor("浅水区颜色", Color) = (0,1,1,1)
        
        [Header(Foam)]
        _SurfaceNoise("水面噪声贴图", 2D) = "white" {}
        _SurfaceNoiseCutoff("噪声贴图裁切", Range(0, 1)) = 0.777
        _FoamDistance("泡沫距离", float) = 1
        _FoamMaxDistance("Foam Maximum Distance", Range(0,10)) = 0.4
_FoamMinDistance("Foam Minimum Distance", Range(0,10)) = 0.04
        _FoamEdgeFade("Foam Edge Fade", Range(0,1)) = 0.5
        
        [Header(FlowMap)]
        _FlowMap("FlowMap", 2D) = "white" {}
        _FlowSpeed("向量场速度", Range(0, 10)) = 1
        
        [Header(Settings)]
        _TimeSpeed("水流速度", Vector) = (0.03,0.03,0,1)
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _BaseColor;
    float _NormalScale;

    float _DepthDifference;
    float4 _DepthColor;
    float4 _ShallowColor;
    float4 _SurfaceNoise_ST;
    float _SurfaceNoiseCutoff;
    float _FoamDistance;
    float _FoamMaxDistance;
float _FoamMinDistance;
    float _FoamEdgeFade;
    float2 _TimeSpeed;

    float _FlowSpeed;

    
    CBUFFER_END

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    TEXTURE2D(_NormalMap);
    SAMPLER(sampler_NormalMap);
    TEXTURE2D(_SurfaceNoise);
    SAMPLER(sampler_SurfaceNoise);
    TEXTURE2D(_FlowMap);
    SAMPLER(sampler_FlowMap);
    struct Attributes
    {
        float4 positionOS : POSITION;
        float4 color : COLOR;
        float3 normalOS : NORMAL;
        float4 tangentOS : TANGENT;
        float2 uv : TEXCOORD0;
        float2 noiseUV : TEXCOORD1;
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

                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;

                //TBN
                o.normalWS = normalInput.normalWS;
                real sign = i.tangentOS.w * GetOddNegativeScale();
                o.tangentWS = float4(normalInput.tangentWS.xyz, sign);
                o.bitangentWS = normalInput.bitangentWS;

                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);

                o.noiseUV = TRANSFORM_TEX(i.noiseUV, _SurfaceNoise);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //纹理采样
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float3 normalMap = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);
                //向量计算
                float3x3 TBN = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz);
                float3 N = TransformTangentToWorld(normalMap, TBN, true);
                //观察空间法线
                float3 normalVS = TransformWorldToViewNormal(N);
                
                //--------------------------------------------
                // 水面颜色
                //--------------------------------------------
                //用深度纹理和屏幕空间uv重建像素的世界空间位置
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                #if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(ScreenUV);
                #else
                float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV));
                #endif
                //采样深度图
                float linearDepth = LinearEyeDepth(depth, _ZBufferParams);
                //水面深度
                float waterSurfaceDepth = i.positionCS.w;
                float depthDifference = linearDepth - waterSurfaceDepth;
                float waterDepthDifference = saturate(depthDifference / _DepthDifference);
                //混合深水区，浅水区
                float4 WaterColor = lerp(_ShallowColor, _DepthColor, waterDepthDifference);

                //--------------------------------------------
                // 泡沫
                //--------------------------------------------
                //扰动噪声贴图的uv
                float2 noiseUV = float2(i.noiseUV.x + _Time.y * _TimeSpeed.x,i.noiseUV.y + _Time.y * _TimeSpeed.y);
                 //FlowMap来处理噪声贴图
                float3 flowDir = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, i.uv)*2.0-1.0;
                flowDir*=_FlowSpeed;
                float phase0 = frac(_Time.y*_TimeSpeed.x);
                float phase1 = frac(_Time.y*_TimeSpeed.x+0.5);
                float tex0 = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, noiseUV-flowDir.xy*phase0).rgb;
                float tex1 = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, noiseUV-flowDir.xy*phase1).rgb;
                float NoiseFlowTex = lerp(tex0,tex1,abs((0.5-phase0)/0.5));
                //泡沫深度
                float3 NormalsTexture = SampleSceneNormals(ScreenUV); //法线纹理
                float3 normalDot = saturate(dot(NormalsTexture, normalVS)); //法线纹理点积观察空间法线,相机视线平行与水面时值最大。
                float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
                float foamDepthDifference = saturate(depthDifference / foamDistance);
                //越深裁剪值越大
                float FoamNoiseCutoff = foamDepthDifference * _SurfaceNoiseCutoff;
                //卡通硬边会有锯齿
                //float FoamNoise = NoiseFlowTex > FoamNoiseCutoff ? 1 : 0;
                //抗锯齿：平滑过渡
                float FoamNoise = smoothstep(FoamNoiseCutoff-_FoamEdgeFade,FoamNoiseCutoff+_FoamEdgeFade,NoiseFlowTex);
                
                //采样法线纹理
                //卡通水
                float4 finalColor = WaterColor + FoamNoise;
                return float4(finalColor.rgb, 0.8);
                
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}