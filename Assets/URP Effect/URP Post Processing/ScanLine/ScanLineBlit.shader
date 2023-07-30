Shader "URPPostProcessing/ScanLine"
{
    Properties 
    {
    }

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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)

        CBUFFER_END

        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        float4 _BlitTexture_TexelSize;
        float _LineWidth;
        float4  _LineColor;
        

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
            Name "CustomBlur"

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
                
                //用深度纹理和屏幕空间uv重建像素的世界空间位置
                //屏幕空间uv
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                #if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(ScreenUV);
                #else
                float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV));
                #endif

                // 重建世界空间位置，注意，这里的深度为非线性深度
                float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, depth, UNITY_MATRIX_I_VP);
                    
                //frac取小数
                float3 fracPos = frac(rebuildPosWS);
                //step函数，如果x<=y，返回1，否则返回0
                float3 stepPos = step(fracPos, _LineWidth);

                return float4(stepPos*_LineColor.rgb,1);
            }
            ENDHLSL
        }
    }
    Fallback Off
}