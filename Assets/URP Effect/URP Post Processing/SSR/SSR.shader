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

        float _maxRayMarchingDistance;
		float _maxRayMarchingStep;
		float _rayMarchingStepSize;
		float _depthThickness;
        
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

            bool checkDepthCollision(float2 ScreenUV, float3 viewPos, float3 depth)
            {
                return ScreenUV.x >= 0 &&
                    ScreenUV.x <= 1 &&
                    ScreenUV.y >= 0 &&
                    ScreenUV.y <= 1 &&
                    depth < viewPos.z;
            }
            
            bool viewSpaceRayMarching(float2 ScreenUV,float3 rayOri, float3 rayDir, float3 depth)
			{
                UNITY_LOOP
				for(int i = 0; i < _maxRayMarchingStep; i++)
				{
					float3 currentPos = rayOri + rayDir * _rayMarchingStepSize * i;
					if (length(rayOri - currentPos) > _maxRayMarchingDistance)
						return false;
					if (checkDepthCollision(ScreenUV,currentPos, depth))
					{
						return true;
					}
				}
				return false;
			}

            float4 frag(Varyings i) : SV_Target
            {
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                #if UNITY_REVERSED_Z
                float SceneDepth = SampleSceneDepth(ScreenUV);
                #else
                 float SceneDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uvSS));
                #endif
                float linearEyeDepth = LinearEyeDepth(SceneDepth, _ZBufferParams);
                float3 SceneNormal = SampleSceneNormals(ScreenUV);
                float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, SceneDepth, UNITY_MATRIX_I_VP);
                //重建观察空间坐标
                float3 viewPos = ComputeViewSpacePosition(ScreenUV, SceneDepth, UNITY_MATRIX_I_P);
                float3 viewDir = normalize(viewPos);
                float3 viewNormal = normalize(SceneNormal);
                float3 reflectDir = reflect(viewDir, viewNormal);

                float2 hitScreenPos = float2(0,0);
                if(viewSpaceRayMarching(ScreenUV, viewPos, reflectDir, SceneDepth))
                {
                    
                }
                return float4(reflectDir, 1);
                float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                
                return color;
            }
            ENDHLSL
        }
    }
    Fallback Off
}