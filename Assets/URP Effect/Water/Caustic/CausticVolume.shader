Shader "Custom/CausticVolume"
{
    Properties
    {
        [Header(Caustics)]
        _CausticsTexture("焦散纹理", 2D) = "white" {}
        _CausticsStrength("焦散强度", Float) = 1
        _CausticsUVOffset("焦散UV偏移", Range(0,0.1)) = 0.1
        _CausticsLuminanceMask("亮度遮罩", Range(0,1)) = 0.5
        _CausticsFadeRadius("焦散消退半径", Range(0,1)) = 0.5
        _CausticsFadeStrength("焦散消退强度", Range(0,1)) = 0.5
        _Alpha("透明度", Range(0,1)) = 0.5
        _TimeSpeed("Time Speed", Vector) = (1,1,1,1)
        
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
    float4 _CausticsTexture_ST;
    float _CausticsStrength;
    float _CausticsUVOffset;
    float _CausticsLuminanceMask;
    float _CausticsFadeRadius;
    float _CausticsFadeStrength;
    float _Alpha;
    float2 _TimeSpeed;
    CBUFFER_END
    
    TEXTURE2D(_CausticsTexture);
    SAMPLER(sampler_CausticsTexture);
    float4x4 _MainLightDirection;
    TEXTURE2D(_CameraOpaqueTexture);
    SAMPLER(sampler_CameraOpaqueTexture);

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
            Blend  SrcAlpha OneMinusSrcAlpha
            
            Cull Front
            ZTest Always
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

                //TBN
                o.normalWS = normalInput.normalWS;
                real sign = i.tangentOS.w * GetOddNegativeScale();
                o.tangentWS = float4(normalInput.tangentWS.xyz, sign);
                o.bitangentWS = normalInput.bitangentWS;

                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);

                return o;
            }

            //分离rgb，计算色差
           float3 SampleCaustics(float2 uv, float uvOffset)
            {
                float2 uv1 = uv + float2(uvOffset, uvOffset);
                float2 uv2 = uv + float2(uvOffset, -uvOffset);
                float2 uv3 = uv + float2(-uvOffset, -uvOffset);

                float r = SAMPLE_TEXTURE2D(_CausticsTexture, sampler_CausticsTexture, uv1).r;
                float g = SAMPLE_TEXTURE2D(_CausticsTexture, sampler_CausticsTexture, uv2).r;
                float b = SAMPLE_TEXTURE2D(_CausticsTexture, sampler_CausticsTexture, uv3).r;

                return float3(r, g, b);
            }
            
            float4 frag(Varyings i) : SV_Target
            {

                //重建世界空间坐标
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                #if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(ScreenUV);
                #else
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV));
                #endif
                float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, depth, UNITY_MATRIX_I_VP);

                //在局部空间中计算Box Mask
                float3 rebuildPosOS = TransformWorldToObject(rebuildPosWS);
                //局部空间坐标范围在-0.5到0.5之间，作为Box的边界
                //通过将输出与此边界框遮罩相乘，我们可以将焦散限制为仅在需要的地方渲染。
                float boundingBoxMask = all(step(rebuildPosOS, 0.5) * (1 - step(rebuildPosOS, -0.5)));

                //主灯光方向影响焦散采样UV
                float2 causticsUV = mul(rebuildPosWS,_MainLightDirection).xy;

                //叠加两次焦散贴图
                float2 uv1 = (causticsUV + _TimeSpeed * _Time.y * 0.5) * _CausticsTexture_ST.xy +_CausticsTexture_ST.zw;
                float2 uv2 = (causticsUV + _TimeSpeed * _Time.y * 1) * (-_CausticsTexture_ST.xy) + _CausticsTexture_ST.zw;
                float3 tex1 = SampleCaustics(uv1, _CausticsUVOffset);
                float3 tex2 = SampleCaustics(uv2, _CausticsUVOffset);
                float3 caustics = min(tex1,tex2) * _CausticsStrength;
                //亮度遮罩(阴影处暗)
                float3 SceneColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, ScreenUV).rgb;
                float sceneLuminance = Luminance(SceneColor);
                float luminanceMask = lerp(1, sceneLuminance, _CausticsLuminanceMask);

                //边缘渐变
                float edgeFadeMask = 1 - saturate((distance(rebuildPosOS, 0) - _CausticsFadeRadius) / (1 - _CausticsFadeStrength));

                float4 finalColor = float4(caustics.xyz,_Alpha) * boundingBoxMask * luminanceMask * edgeFadeMask;
                
                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}