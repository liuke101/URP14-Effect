﻿Shader "URPPostProcessing/Blur/BoxBlur"
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

        CBUFFER_START(UnityPerMaterial)

        CBUFFER_END

        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        float _BlurOffset;
        float4 _BlitTexture_TexelSize;

        struct Attributes
        {
            uint vertexID : SV_VertexID;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv[5] : TEXCOORD0;
        };
        ENDHLSL

        Pass
        {
            Name "BoxBlurY"
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

                //以5x5的卷积核为例
                //当前采样纹理
                float2 uv = GetFullScreenTriangleTexCoord(i.vertexID);
                o.uv[0] = uv;
            
                //邻域采样纹理，_BlurOffset控制采样距离
                o.uv[1] = uv + float2(0.0, _BlitTexture_TexelSize.y * 1.0) * _BlurOffset; //上1
                o.uv[2] = uv + float2(0.0, _BlitTexture_TexelSize.y * -1.0) * _BlurOffset; //下1
                o.uv[3] = uv + float2(0.0, _BlitTexture_TexelSize.y * 2.0) * _BlurOffset; //上2
                o.uv[4] = uv + float2(0.0, _BlitTexture_TexelSize.y * -2.0) * _BlurOffset; //下2

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //采样并乘卷积核权重，和高斯模糊唯一区别就是权重是平均分的
                float4 sum = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[0]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[1]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[2]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[3]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[4]) * 0.25;

                return sum;
            }
            ENDHLSL
        }

        Pass
        {
            Name "BoxBlurX"
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
                float2 uv = GetFullScreenTriangleTexCoord(i.vertexID);
                o.uv[0] = uv;
                o.uv[1] = uv + float2(_BlitTexture_TexelSize.x * 1.0, 0.0) * _BlurOffset; //左一
                o.uv[2] = uv + float2(_BlitTexture_TexelSize.x * -1.0, 0.0) * _BlurOffset; //右1
                o.uv[3] = uv + float2(_BlitTexture_TexelSize.x * 2.0, 0.0) * _BlurOffset; //左2
                o.uv[4] = uv + float2(_BlitTexture_TexelSize.x * -2.0, 0.0) * _BlurOffset; //右2

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 sum = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[0]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[1]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[2]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[3]) * 0.25;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[4]) * 0.25;

                return sum;
            }
            ENDHLSL
        }
    }
    Fallback Off
}