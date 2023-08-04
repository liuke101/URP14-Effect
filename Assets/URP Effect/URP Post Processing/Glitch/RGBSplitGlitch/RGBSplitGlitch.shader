Shader "URPPostProcessing/Glitch/RGBSplitGlitch"
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
        float _SplitIntensity;
        float _Amplitude;
        
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
            Name "RGBSplitGlitch"
            
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
                    
            float4 frag(Varyings i) : SV_Target
            {
                //性能优化版本的基于随机噪声抖动
                //float splitIntensity = randomNoise(_Time.y,2)* _SplitIntensity;
                
                //基于三角函数和pow方法控制抖动
                float splitIntensity = (1.0 + sin(_Time.y * 6.0)) * 0.5;
                 splitIntensity *= 1.0 + sin(_Time.y * 16.0) * 0.5;
                 splitIntensity *= 1.0 + sin(_Time.y * 19.0) * 0.5;
                 splitIntensity *= 1.0 + sin(_Time.y * 27.0) * 0.5;
                 splitIntensity = pow(splitIntensity, _Amplitude);
                splitIntensity*= (0.05*_SplitIntensity);

                float3 finalColor;
                finalColor.r = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, float2(i.uv.x+splitIntensity,i.uv.y)).r;
                finalColor.g = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, float2(i.uv.x,i.uv.y)).g;
                finalColor.b = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, float2(i.uv.x-splitIntensity,i.uv.y)).b;
                finalColor *= (1.0 - splitIntensity * 0.5);
                
                return float4(finalColor.rgb,1);
            }
            ENDHLSL
        }
    }
    Fallback Off
}