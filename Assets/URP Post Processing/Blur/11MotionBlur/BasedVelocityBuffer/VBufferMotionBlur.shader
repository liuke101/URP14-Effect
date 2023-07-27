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
        float4x4 _PreviousVPMatrix;
        float4x4 _CurrentVPInverseMatrix;

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
                //1 获取屏幕UV
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                //2 从深度纹理中采样深度
                #if UNITY_REVERSED_Z
                // 具有 REVERSED_Z 的平台（如 D3D）的情况。
                float depth = SampleSceneDepth(ScreenUV); 
                #else
                // 没有 REVERSED_Z 的平台（如 OpenGL）的情况。
                // 调整 Z 以匹配 OpenGL 的 NDC ([-1, 1])
                 float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV));
                #endif

                //3 重建世界空间位置
               //float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, depth, UNITY_MATRIX_I_VP);
               float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, depth, _CurrentVPInverseMatrix);
                //4 使用前一帧的VP矩阵，对重建世界空间位置进行变换，得到前一帧在NDC下的坐标
                float4 currentNDCPos = mul(UNITY_MATRIX_VP, float4(rebuildPosWS, 1)); //当前帧的NDC坐标
                //得到的是一个未作齐次除法的世界坐标
                float4 previousPosWS = mul(_PreviousVPMatrix, float4(rebuildPosWS, 1));
                //做齐次除法转化成世界坐标
                previousPosWS /= previousPosWS.w;

                //5 计算前一阵和当前帧在屏幕空间的位置差，得到该像素的速度向量
                float2 velocity = currentNDCPos.xy - previousPosWS.xy;

                //6 使用该速度值对邻域像素采样，相加后取平均得到模糊结果
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv);
                i.uv+=velocity*_BlurSize;
                for(int it=1;it<3;it++)
                {
                    color+=SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv);
                    i.uv+=velocity*_BlurSize;
                }
                color/=3;
                
                return float4(color.rgb,1);
            }
            ENDHLSL
        }
    }
    Fallback Off
}