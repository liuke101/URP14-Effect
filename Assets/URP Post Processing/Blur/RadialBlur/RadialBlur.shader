Shader "URPPostProcessing/Blur/RadialBlur"
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
        float2 _RadialCenter;  //径向轴心
        float _RadialOffsetIterations; //径向偏移迭代次数
        float _BlurOffset;
        float4 _BlitTexture_TexelSize;

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
                 o.uv = GetFullScreenTriangleTexCoord(i.vertexID);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //从uv指向径向轴心的向量
                float2 blurVector = (_RadialCenter-i.uv) * _BlurOffset;
                float4 color = float4(0,0,0,0);

                for(int j = 0;j<_RadialOffsetIterations;j++)
                {
                    color += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                    i.uv += blurVector; //径向偏移，偏向轴心
                }
                color /= _RadialOffsetIterations; //取平均值
                
                return color;
            }
            ENDHLSL
        }
    }
    Fallback Off
}