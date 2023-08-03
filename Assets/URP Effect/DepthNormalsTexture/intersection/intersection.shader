Shader "Custom/intersection"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalScale("NormalScale", Range(0, 10)) = 1

        [Header(Specular)]
        _SpecularPower("SpecularPower", Range(1, 100)) = 32
        _SpecularScale("SpecularScale", Range(0, 10)) = 1
        _SpecularColor("SpecularColor", Color) = (1,1,1,1)

        [Header(Fresnel)]
        _FresnelScale("_FresnelScale", Range(0, 10)) = 1
        _FresnelPower("FresnelPower", Range(0, 10)) = 1
        [HDR]_FresnelColor("FresnelColor", Color) = (1,1,1,1)

        [Header(DepthFade)]
        _DepthFadeDistance("深度消退距离",Range(0.01,2)) = 0.1
        _DepthFadePower("深度消退指数",Range(0,10)) = 1
        _DepthFadeScale("深度消退大小",Range(0,10)) = 1
        [HDR]_DepthFadeColor("深度消退颜色",Color) = (0,0,1,1)

        [Header(WhiteLine)]
        _WhiteEdgeWidth("白边宽度",Range(0,1)) = 0.1
        [HDR]_WhiteEdgeColor("白边颜色",Color) = (1,1,1,1)
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _BaseColor;
    float _NormalScale;

    float _SpecularPower;
    float _SpecularScale;
    float4 _SpecularColor;

    float _FresnelScale;
    float _FresnelPower;
    float4 _FresnelColor;

    float _DepthFadeDistance;
    float _DepthFadePower;
    float _DepthFadeScale;
    float4 _DepthFadeColor;

    float _WhiteEdgeWidth;
    float4 _WhiteEdgeColor;
    CBUFFER_END

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    TEXTURE2D(_NormalMap);
    SAMPLER(sampler_NormalMap);

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
            Cull Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

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

            //VFACE来实现护盾内外部效果不同
            float4 frag(Varyings i, float facing : VFACE) : SV_Target
            {
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float3 normalMap = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);

                //向量计算
                float3x3 TBN = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz);
                float3 N = TransformTangentToWorld(normalMap, TBN, true);
                float3 L = normalize(_MainLightPosition.xyz);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);

                float3 fresnelColor = saturate(_FresnelScale * pow(1 - dot(V, N), _FresnelPower) * _FresnelColor.rgb);

                //获取屏幕UV
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);

                //从深度纹理中采样深度
                #if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(ScreenUV);
                #else
                float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uvSS));
                #endif
                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
                // 重建世界空间位置，注意，这里的深度为非线性深度
                float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, depth, UNITY_MATRIX_I_VP);

                //---------------------------------
                //深度交接出白边
                //--------------------------------
                //rebuildPosWS一般来说>=i.positionWS
                float3 posDistance = saturate(distance(rebuildPosWS, i.positionWS) / _DepthFadeDistance);
                
                float3 whiteEdge = 1 - posDistance;

                //计算过渡颜色
                float3 FadeColor = pow(whiteEdge, _DepthFadePower) * _DepthFadeScale * _DepthFadeColor.rgb;

                //计算边颜色
                float3 edge = step(_WhiteEdgeWidth, whiteEdge); //Step得出离地近的边
                float3 edgeColor = edge * _WhiteEdgeColor.rgb;

                //混合颜色
                float3 DepthEdgeColor = lerp(FadeColor, edgeColor, edge);


                //护盾外部菲涅尔,内部无菲涅尔
                if (facing > 0)
                {
                    return float4(DepthEdgeColor + fresnelColor, 1);
                }
                else
                {
                    return float4(DepthEdgeColor, 1);
                }


            }
            ENDHLSL
        }
    }
}