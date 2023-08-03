Shader "URPPostProcessing/BasedDepthScanLine"
{
    Properties 
    {
        _ScanDepth("扫描深度",float) = 0
        _LineWidth("扫描线宽度",Range(0,10)) = 1
        _ScanLineColor("扫描线颜色",Color) = (1,0,0,0)
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
        float _ScanDepth;
        float _LineWidth;
        float4 _ScanLineColor;
        CBUFFER_END
    
        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
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
            Name "CustomBlit"
            
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
                    float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                #if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(ScreenUV);
                #else
                float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV));
                #endif
                float linearEyeDepth = LinearEyeDepth(depth,_ZBufferParams);
                float v = saturate(abs(linearEyeDepth-_ScanDepth)/_LineWidth);
                return lerp(_ScanLineColor,color,v);
                return color;
            }
            ENDHLSL
        }
    }
    Fallback Off
}