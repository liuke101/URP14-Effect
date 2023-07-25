Shader "URPPostProcessing/Blur/GrainyBlur"
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
        float _BlurOffset;
        float _UVDistortionIterations;
        
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
            Name "GrainyBlur"
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

            //随机抖动
            float Rand(float2 n)
            {
                return sin(dot(n, half2(1233.224, 1743.335)));
            }

            float4 frag(Varyings i) : SV_Target
            {
                float2 randomOffset = float2(0.0, 0.0);
                float4 finalColor = float4(0.0, 0.0, 0.0, 0.0);
                float random = Rand(i.uv);


                //采样并乘高斯核权重
                float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);


                for (int k = 0; k < int(_UVDistortionIterations); k++)
                {
                    random = frac(43758.5453 * random + 0.61432);;
                    randomOffset.x = (random - 0.5) * 2.0;
                    random = frac(43758.5453 * random + 0.61432);
                    randomOffset.y = (random - 0.5) * 2.0;

                    finalColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture,float2(i.uv + randomOffset * _BlurOffset));
                }
                return finalColor / _UVDistortionIterations;
            }
            ENDHLSL
        }
    }
    Fallback Off
}