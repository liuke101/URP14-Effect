Shader "URPPostProcessing/Blur/VBufferMotionBlur"
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)

        CBUFFER_END

        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        float4 _BlitTexture_TexelSize;
        float _BlurSize;
        float4x4 _CurrentViewProjectionInverseMatrix;
        float4x4 _PreviousViewProjectionMatrix;

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
                //获取屏幕空间UV
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                
                //从深度纹理中采样深度
                #if UNITY_REVERSED_Z
                // 具有 REVERSED_Z 的平台（如 D3D）的情况。
                // 返回[1,0]的非线性深度值
                float depth = SampleSceneDepth(ScreenUV);
                #else
                // 没有 REVERSED_Z 的平台（如 OpenGL）的情况。
                // 调整 Z 以匹配 OpenGL 的 NDC ([-1, 1])
                float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV));
                #endif

                // 当前帧NDC空间坐标
                float4 currentPosNDC = float4(ScreenUV.x * 2 - 1, ScreenUV.y * 2 - 1, 2*depth-1, 1);

                //得到当前帧世界空间坐标
                float4 D = mul(_CurrentViewProjectionInverseMatrix, currentPosNDC);
                float4 currentPosWS = D / D.w;

                //上一帧裁剪空间坐标
                float4 previousPosCS = mul(_PreviousViewProjectionMatrix, currentPosWS);
                //做齐次除法得到上一帧NDC坐标
                float4 previousPosNDC = previousPosCS / previousPosCS.w;

                // NDC坐标差作为速度向量
                float2 velocity = currentPosNDC.xy - previousPosNDC.xy;

                float2 uv = i.uv;
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv);
                uv += velocity * _BlurSize; //速度偏移uv进行采样
                for (int it = 1; it < 3; it++, uv += velocity * _BlurSize)
                {
                    float4 currentColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv);
                    color += currentColor;
                }
                color /= 3;

                return half4(color.rgb, 1.0);
            }
            ENDHLSL
        }
    }
    Fallback Off
}