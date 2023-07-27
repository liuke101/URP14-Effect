Shader "URPPostProcessing/Blur/ABufferMotionBlur"
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
        float _BlurTrain;

        struct Attributes
        {
            uint vertexID : SV_VertexID;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        Varyings vert(Attributes i)
        {
            Varyings o = (Varyings)0;

            o.positionCS = GetFullScreenTriangleVertexPosition(i.vertexID);
            o.uv = GetFullScreenTriangleTexCoord(i.vertexID);

            return o;
        }
        
        float4 fragRGB(Varyings i) : SV_Target
        {
            //a通道存储运动模糊的权重，以便进行透明度混合
            return float4(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv).rgb, _BlurTrain);
        }

        float4 fragA(Varyings i) : SV_Target
        {
            //不让渲染纹理受到混合时使用的透明度值的影响
            return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
        }
        
        ENDHLSL

        Pass
        {
            
            Name "UpdateRGB"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Blend SrcAlpha OneMinusSrcAlpha //透明度混合
            ColorMask RGB //只写入RGB通道，A通道只用来混合而不写入

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragRGB
            ENDHLSL
        }

        Pass
        {
            Name "UpdateA"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Blend One Zero
            ColorMask A //只写入A通道

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragA
            ENDHLSL
        }
    }
    Fallback Off
}