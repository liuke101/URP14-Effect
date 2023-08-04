Shader "Custom/Dissolve/SceneDissolve"
{
    Properties
    {
        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        
        _NoiseTex("NoiseTex", 2D) = "white" {}
        _NoiseScale("NoiseScale", Range(-1,1)) = 0.062
        _DissolveThreshold("DissolveThreshold", Range(-1,1)) = 0.466
        _EdgeWidth("EdgeWidth", Range(0,1)) = 0.022
        [HDR]_EdgeColor("EdgeColor", Color) = (1,0,0,1)
        
        _StartPoint("DissolveStartPoint", Vector) = (0,0,0,0)
        _DissolveDiffuse("DissolveDiffuse", Range(0,10)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="TransparentCutout"
             "Queue"="AlphaTest"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float _NoiseScale;
        float4 _EdgeColor;
        float4 _MainTex_ST;
        float _DissolveThreshold;
        float _EdgeWidth;
        float3 _StartPoint;
        float _DissolveDiffuse;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

        float _MaxVertexDistance;
        
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 positionWS : TEXCOORD1;
        };
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Cull Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;

                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv =TRANSFORM_TEX(i.uv, _MainTex);

                //由于影响多个模型，所以在世界空间中计算
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                float Noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv).r*_NoiseScale;
                float vertexDistance = distance(i.positionWS, _StartPoint)- _DissolveDiffuse; //片元到开始点的距离
                float normalizedDistance = 1-saturate(vertexDistance/_MaxVertexDistance + Noise);//归一化,开始点处值为0，因为距离该处片元距离开始点距离为0

                clip(normalizedDistance-_DissolveThreshold);

               
                //step算出溶解边缘
                 float internalEdge = step(normalizedDistance,_DissolveThreshold);
                 float externalEdge = step(normalizedDistance, _DissolveThreshold+_EdgeWidth);;
                 float edge = externalEdge-internalEdge;
                //return float4(edge.xxx,1);
                
                 float4 finalColor = lerp(MainTex, _EdgeColor, edge * step(0.0001,_DissolveThreshold));
                
                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}