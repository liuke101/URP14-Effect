Shader "URPPostProcessing/Blur/DualBlur"
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
            float2 uv[8] : TEXCOORD0;
        };
        ENDHLSL

        Pass
        {
            Name "DualBlurDownSample"
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

                //当前采样纹理
                float2 uv = GetFullScreenTriangleTexCoord(i.vertexID);
                o.uv[0] = uv;

                //邻域采样纹理，_BlurOffset控制采样距离
                o.uv[1] = uv + float2(-1, -1) * _BlitTexture_TexelSize.xy * _BlurOffset; //左下
                o.uv[2] = uv + float2(-1, 1) * _BlitTexture_TexelSize.xy * _BlurOffset; //左上
                o.uv[3] = uv + float2(1, 1) * _BlitTexture_TexelSize.xy * _BlurOffset; //右上
                o.uv[4] = uv + float2(1, -1) * _BlitTexture_TexelSize.xy * _BlurOffset; //右下

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 sum = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[0]) * 0.5;

                for (int index = 1; index < 4; index++)
                {
                    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[index]) * 0.125;
                }

                return sum;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DualBlurUpSample"
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
                float4 pos = GetFullScreenTriangleVertexPosition(i.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(i.vertexID);

                o.positionCS = pos;
                o.uv[0] = uv + float2(-1, -1) * _BlitTexture_TexelSize.xy * _BlurOffset; //左下
                o.uv[1] = uv + float2(-1, 1) * _BlitTexture_TexelSize.xy * _BlurOffset; //左上
                o.uv[2] = uv + float2(1, 1) * _BlitTexture_TexelSize.xy * _BlurOffset; //右上
                o.uv[3] = uv + float2(1, -1) * _BlitTexture_TexelSize.xy * _BlurOffset; //右下
                o.uv[4] = uv + float2(0, 2) * _BlitTexture_TexelSize.xy * _BlurOffset; //上
                o.uv[5] = uv + float2(0, -2) * _BlitTexture_TexelSize.xy * _BlurOffset; //下
                o.uv[6] = uv + float2(-2, 0) * _BlitTexture_TexelSize.xy * _BlurOffset; //左
                o.uv[7] = uv + float2(2, 0) * _BlitTexture_TexelSize.xy * _BlurOffset; //右


                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 sum = 0;
                for (int index = 0; index < 4; index++)
                {
                    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[index])/6;
                }

                for (int j = 4; j < 8; j++)
                {
                    sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[j])/12;
                }
                return sum;
            }
            ENDHLSL
        }
    }
    Fallback Off
}