Shader "URPPostProcessing/Blur/DirectionalBlur"
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

        CBUFFER_START(UnityPerMateiral)

        CBUFFER_END

        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);

        float4 _BlitTexture_TexelSize;
        float _OffsetIterations; //偏移迭代次数
        float2 _DirectionalOffset; //方向偏移

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
            Name "DirectionalBlur"
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
                float4 color = float4(0, 0, 0, 0);

                for (int j = 0; j < _OffsetIterations; j++)
                {
                    color += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv - _DirectionalOffset*j);
                }

                  color /= _OffsetIterations;
                
                return color;
            }
            ENDHLSL
        }
    }
    Fallback Off
}