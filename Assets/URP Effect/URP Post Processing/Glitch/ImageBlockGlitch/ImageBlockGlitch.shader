Shader "URPPostProcessing/Glitch/ImageBlockGlitch"
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
        float _BlockSize;
        float _TimeSpeed;
        float _MaxRGBSplitX;
        float _MaxRGBSplitY;

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
            Name "ImageBlockGlitch"

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

            float randomNoise(float x, float y)
            {
                return frac(sin(dot(float2(x, y), float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float randomNoise(float2 seed)
            {
                return frac(sin(dot(seed * floor(_Time.y * _TimeSpeed), float2(17.13, 3.71))) * 43758.5453123);
            }

            inline float randomNoise(float seed)
            {
                return randomNoise(float2(seed, 1.0));
            }

            float4 frag(Varyings i) : SV_Target
            {
                //生成随机强度的均匀 Block 图块
                float2 block = randomNoise(floor(i.uv * _BlockSize));

                //均匀 Block 图块强度值做强度的二次筛选，增加随机性
                float displaceNoise = pow(block.x, 8.0) * pow(block.x, 3.0);

                float splitRGBNoise = pow(randomNoise(7.2341), 17.0);
                float offsetX = displaceNoise - splitRGBNoise * _MaxRGBSplitX;
                float offsetY = displaceNoise - splitRGBNoise * _MaxRGBSplitY;
                float noiseX = 0.05 * randomNoise(13.0);
                float noiseY = 0.05 * randomNoise(7.0);
                 float2 offset = float2(offsetX * noiseX, offsetY* noiseY);
                
                float3 finalColor;
                finalColor.r = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv).r;
                finalColor.g = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture,i.uv + offset).g;
                finalColor.b = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv - offset).b;

                return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
    Fallback Off
}