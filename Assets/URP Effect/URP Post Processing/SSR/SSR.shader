Shader "URPPostProcessing/SSR"
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)

        CBUFFER_END

        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);

        float4 _BlitTexture_TexelSize;

        float MaxRayMarchingDistance;
        float MaxRayMarchingStep;
        float RayMarchingStepSize;
        float DepthThickness;

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
            Name "ScreenSpaceReflect"

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

            bool checkDepthCollision(float3 viewPos, out float2 screenPos)
            {
                float4 clipPos = TransformWViewToHClip(viewPos);
            
                screenPos = GetNormalizedScreenSpaceUV(clipPos);
                #if UNITY_REVERSED_Z
                float SceneDepth = SampleSceneDepth(screenPos);
                #else
                 float SceneDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uvSS));
                #endif
                float linearEyeDepth = LinearEyeDepth(SceneDepth, _ZBufferParams);
                
                //判断当前反射点是否在屏幕外，或者超过了当前深度值
                return screenPos.x > 0 && screenPos.y > 0 && screenPos.x < 1.0 && screenPos.y < 1.0 && linearEyeDepth < -viewPos.z && linearEyeDepth;
            }

            //BUG:无法得true
            bool viewSpaceRayMarching(float3 viewPos, float3 reflectDir, out float2 hitScreenPos)
            {
                UNITY_LOOP
                for (int i = 0; i < MaxRayMarchingStep; i++)
                {
                    float3 currentPos = viewPos + reflectDir * RayMarchingStepSize * i;
                    if (distance(viewPos,currentPos) > MaxRayMarchingDistance)
                        return false;
                    if (checkDepthCollision(currentPos, hitScreenPos))
                    {
                        return true;
                    }
                }
                return false;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 blitColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                #if UNITY_REVERSED_Z
                float SceneDepth = SampleSceneDepth(ScreenUV);
                #else
                 float SceneDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uvSS));
                #endif
                float linearEyeDepth = LinearEyeDepth(SceneDepth, _ZBufferParams);
                float3 SceneNormal = SampleSceneNormals(ScreenUV);
                //重建观察空间坐标
                float3 viewPos = ComputeViewSpacePosition(ScreenUV, SceneDepth, UNITY_MATRIX_I_P);

                //计算反射向量
                float3 viewDir = normalize(viewPos);
                float3 viewNormal = TransformWorldToViewNormal(SceneNormal, true); //法线转换到观察空间？
                float3 reflectDir = reflect(-viewDir, viewNormal);
                float2 hitScreenPos = float2(0, 0);
                if (viewSpaceRayMarching(viewPos, reflectDir, hitScreenPos))
                {
                    float4 reflectColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, hitScreenPos);
                    
                    blitColor.rgb += reflectColor.rgb;
                }
               return float4(blitColor.rgb,1);
                
                
                
            }
            ENDHLSL
        }
    }
    Fallback Off
}