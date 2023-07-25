Shader "URPPostProcessing/DemoColorBlit"
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
        float _Intensity;
        
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
            Name "ColorBlit"
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
                float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                return color * float4(0, _Intensity, 0, 1.0);
            }
            ENDHLSL
        }
    }
}