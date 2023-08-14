Shader "Water/GaussianLuminance"
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
        TEXTURE2D(_CameraOpaqueTexture);
        SAMPLER(sampler_CameraOpaqueTexture);
        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        TEXTURE2D(_LightDarkTexture); //明暗度纹理
        SAMPLER(sampler_LightDarkTexture);
        float _LightDarkIntensity; //明暗强度
        float _LuminanceThreshold; //亮度阈值
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
            

            // luminance亮度公式，计算得到像素的亮度值
            float luminance(float4 color)
            {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv[0]);

                // 调用luminance得到采样后像素的亮度值，再减去阈值
                // 使用clamp函数将结果截取在[0,1]范围内
                float luminanceValue = clamp(luminance(color) - _LuminanceThreshold, 0.0, 1.0);

                // 与原贴图采样得到的像素值相乘，得到提取后的亮部区域
                return luminanceValue;
            }
            ENDHLSL
        }

        Pass
        {
            Name "GaussianBlurY"
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

                //一个5x5的二维高斯核可以拆分为两个大小为5的一维高斯核
                //因此我们只需要计算5个纹理坐标即可

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
                //采样并乘高斯核权重
                float4 sum = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[0]) * 0.4026;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[1]) * 0.2442;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[2]) * 0.2442;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[3]) * 0.0545;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[4]) * 0.0545;

                return sum;
            }
            ENDHLSL
        }

        Pass
        {
            Name "GaussianBlurX"
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
                float4 sum = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[0]) * 0.4026;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[1]) * 0.2442;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[2]) * 0.2442;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[3]) * 0.0545;
                sum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[4]) * 0.0545;

                return sum * _LightDarkIntensity;  
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
                float4 LightDarkTex = SAMPLE_TEXTURE2D(_LightDarkTexture, sampler_LightDarkTexture, i.uv[0]);

                return LightDarkTex * _LightDarkIntensity;
            }
            ENDHLSL
        }
    }
    Fallback Off
}