Shader "URPPostProcessing/Bloom/GodRay"
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
        TEXTURE2D(_SceneColor);
        SAMPLER(sampler_SceneColor);
        TEXTURE2D(_BloomTexture); //Bloom纹理
        SAMPLER(sampler_BloomTexture);
        float _BloomIntensity; //Bloom强度
        float _LuminanceThreshold; //亮度阈值
        float _BlurOffset;
        float4 _BlitTexture_TexelSize;

        float2 _RadialCenter; //径向轴心
        float _RadialOffsetIterations; //径向偏移迭代次数

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
            Name "ExtractBright"
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
                o.uv[0] = GetFullScreenTriangleTexCoord(i.vertexID);

                return o;
            }

            // luminance明亮度公式，计算得到像素的亮度值
            float luminance(float4 color)
            {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[0]);

                // 调用luminance得到采样后像素的亮度值，再减去阈值
                // 使用clamp函数将结果截取在[0,1]范围内
                float luminanceValue = clamp(luminance(color) - _LuminanceThreshold, 0.0, 1.0);

                // 与原贴图采样得到的像素值相乘，得到提取后的亮部区域
                return color * luminanceValue;
            }
            ENDHLSL
        }

        Pass
        {
            Name "RadialBlur"
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
                o.uv[0] = GetFullScreenTriangleTexCoord(i.vertexID);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //从uv指向径向轴心的向量
                float2 blurVector = (_RadialCenter - i.uv[0]) * _BlurOffset;
                float4 color = float4(0, 0, 0, 0);

                for (int j = 0; j < _RadialOffsetIterations; j++)
                {
                    color += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[0]);
                    i.uv[0] += blurVector; //径向偏移，偏向轴心
                }
                color /= _RadialOffsetIterations; //取平均值

                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Blit"
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
                o.uv[0] = GetFullScreenTriangleTexCoord(i.vertexID);

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 scenecolor = SAMPLE_TEXTURE2D(_SceneColor, sampler_SceneColor, i.uv[0]);
                float4 bloom = SAMPLE_TEXTURE2D(_BloomTexture, sampler_BloomTexture, i.uv[0]);

                //与bloom颜色混合
                return scenecolor + bloom * _BloomIntensity;
            }
            ENDHLSL
        }
    }
    Fallback Off
}