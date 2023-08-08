Shader "URPPostProcessing/Blur/SobelOutline"
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
        float4 _BlitTexture_TexelSize;
        float _EdgesOnly;
        float4 _OutlineColor;
        float4 _BackgroundColor;
        


        struct Attributes
        {
            uint vertexID : SV_VertexID;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv[9] : TEXCOORD0;
        };
        ENDHLSL

        Pass
        {
            Name "SobelOutline"
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

                o.uv[0] = uv + _BlitTexture_TexelSize.xy * float2(-1, -1); //左下
                o.uv[1] = uv + _BlitTexture_TexelSize.xy * float2(0, -1); //下
                o.uv[2] = uv + _BlitTexture_TexelSize.xy * float2(1, -1); //右下
                o.uv[3] = uv + _BlitTexture_TexelSize.xy * float2(-1, 0); //左
                o.uv[4] = uv + _BlitTexture_TexelSize.xy * float2(0, 0); //中
                o.uv[5] = uv + _BlitTexture_TexelSize.xy * float2(1, 0); //右
                o.uv[6] = uv + _BlitTexture_TexelSize.xy * float2(-1, 1); //左上
                o.uv[7] = uv + _BlitTexture_TexelSize.xy * float2(0, 1); //上
                o.uv[8] = uv + _BlitTexture_TexelSize.xy * float2(1, 1); //右上

                return o;
            }

            // luminance亮度公式，计算得到像素的亮度值
            float luminance(float3 color)
            {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            //Sobel算子计算当前像素的梯度值
            float Sobel(Varyings i)
            {
                //Sobel算子
                const float GX[9] = {
                    -1, -2, -1,
                    0, 0, 0,
                    1, 2, 1
                };

                const float GY[9] = {
                    -1, 0, 1,
                    -2, 0, 2,
                    -1, 0, 1
                };

                float texColor; //像素亮度值
                float gx, gy; //像素的梯度值

                for (int it = 0; it < 9; it++)
                {
                    texColor = luminance(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[it]).rgb);
                    gx += texColor * GX[it];
                    gy += texColor * GY[it];
                }

                //float g = sqrt(gx * gx + gy * gy); //总梯度值
                float G = abs(gx) + abs(gy); //总梯度值(替代开根号，性能好)

                return G;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float G = Sobel(i); //值越大，说明该像素越可能是边缘
                float4 withEdgeColor = lerp(
                    SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv[4]), _OutlineColor, G);
                float4 onlyEdgeColor = lerp(_BackgroundColor, _OutlineColor, G);

                return lerp(withEdgeColor, onlyEdgeColor, _EdgesOnly) ;
            }
            ENDHLSL
        }
    }
    Fallback Off
}