Shader "URPPostProcessing/Blur/DepthNormalTextureOutline"
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)

        CBUFFER_END

        TEXTURE2D_X(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        
        float4 _BlitTexture_TexelSize;
        float _EdgesOnly;
        float4 _EdgeColor;
        float4 _BackgroundColor;
        float _SampleDistance;
        float _SensitivityDepth;
        float _SensitivityNormals;


        struct Attributes
        {
            uint vertexID : SV_VertexID;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv[5] : TEXCOORD0;
        };
        ENDHLSL

        Pass
        {
            Name "SobelOutline"
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
                float2 uv = GetFullScreenTriangleTexCoord(i.vertexID);
                o.uv[0] = uv;
                o.uv[1] = uv + _BlitTexture_TexelSize.xy * float2(1, 1) * _SampleDistance; //右上
                o.uv[2] = uv + _BlitTexture_TexelSize.xy * float2(-1, -1) * _SampleDistance; //左下
                o.uv[3] = uv + _BlitTexture_TexelSize.xy * float2(-1, 1) * _SampleDistance; //左上
                o.uv[4] = uv + _BlitTexture_TexelSize.xy * float2(1, -1) * _SampleDistance; //右下


                return o;
            }

            
            //分别计算对角线上两个纹理值的差值，判断是否是边缘
            float CheckSame(float3 center, float3 sample)
            {
                //并不需要使用真正的法线值，xy分量就可以比较出差异
                float2 centerNormal = center.xy; 
                float centerDepth = center.z;
                float2 sampleNormal = sample.xy;
                float sampleDepth = sample.z;

                //法线的不同
                float2 diffNormal = abs(centerNormal-sampleNormal)*_SensitivityNormals;
                int isSameNormal = (diffNormal.x+diffNormal.y) < 0.1;
                //深度的不同
                float diffDepth = abs(centerDepth-sampleDepth)*_SensitivityDepth;
                int isSameDepth = diffDepth < 0.1;

                return isSameNormal*isSameDepth?1.0:0.0;
            }

            float3 DecodeNormal(float4 enc)
            {
                float kScale = 1.7777;
                float3 nn = enc.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
                float g = 2.0 / dot(nn.xyz,nn.xyz);
                float3 n;
                n.xy = g*nn.xy;
                n.z = g-1;
                return n;
            }

            
            float4 frag(Varyings i) : SV_Target
            {
                float3 sample1;
                float3 sample2;
                float3 sample3;
                float3 sample4;
                sample1.xy = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[1]).rg;
                sample1.z = Linear01Depth(SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[1]).r,_ZBufferParams);
                
                sample2.xy = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[2]).rg;
                sample2.z = Linear01Depth(SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[2]).r,_ZBufferParams);
                
                sample3.xy = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[3]).rg;
                sample3.z = Linear01Depth(SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[3]).r,_ZBufferParams);
                
                sample4.xy = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[4]).rg;
                sample4.z = Linear01Depth(SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[4]).r,_ZBufferParams);
                
                float edge = 1.0;
                edge *= CheckSame(sample1, sample2);
                edge *= CheckSame(sample3, sample4);
                
                float4 withEdgeColor = lerp(_EdgeColor,SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv[0]),edge);
                float4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
                
                return lerp(withEdgeColor, onlyEdgeColor, _EdgesOnly);
            }
            ENDHLSL
        }
    }
    Fallback Off
}