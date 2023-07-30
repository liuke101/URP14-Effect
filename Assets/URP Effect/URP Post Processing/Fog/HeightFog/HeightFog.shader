Shader "URPPostProcessing/Blur/HeightFog"
{
    Properties {}

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }

        LOD 100
        ZWrite Off Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)

        CBUFFER_END

        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        float4 _BlitTexture_TexelSize;
        float _FogDensity;
        float4 _FogColor;
        float _FogStart;
        float _FogEnd;

        struct Attributes
        {
            uint vertexID : SV_VertexID;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };
        ENDHLSL

        Pass
        {
            Name "HeightFogRFY"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;
                o.positionCS = GetFullScreenTriangleVertexPosition(i.vertexID);
                o.uv = GetFullScreenTriangleTexCoord(i.vertexID);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //屏幕空间uv  
                //用深度纹理和屏幕空间uv重建像素的世界空间位置
                //屏幕空间uv
                float2 ScreenUV = i.positionCS.xy / _ScaledScreenParams.xy;
                //从深度纹理中采样深度
                #if UNITY_REVERSED_Z
                // 具有 REVERSED_Z 的平台（如 D3D）的情况。
                //返回[1,0]的深度值
                real depth = SampleSceneDepth(ScreenUV);
                #else
                // 没有 REVERSED_Z 的平台（如 OpenGL）的情况。
                // 调整 Z 以匹配 OpenGL 的 NDC([-1, 1])
                real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV));
                #endif

                // 重建世界空间位置
                float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, depth, UNITY_MATRIX_I_VP);

                //计算雾的密度
                float fogDensity = (_FogEnd-rebuildPosWS.y)/(_FogEnd-_FogStart);
                fogDensity = saturate(fogDensity*_FogDensity);
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv);
                color.rgb = lerp(color.rgb, _FogColor, fogDensity);

                return color;
            }
            ENDHLSL
        }


    }
    Fallback Off
}