Shader "Custom/Dissolve/DirectionalDissolve"
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
        float4 _OutlineColor;
        float4 _MainTex_ST;
        float _DissolveThreshold;
        float _EdgeWidth;
        float _DissolveDiffuse;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

        float _MinBorderX;
        float _MaxBorderX;
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 positionOS : TEXCOORD1;
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

                o.positionOS = i.positionOS.xyz;
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                float Noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv).r*_NoiseScale;

                float range =abs(_MaxBorderX-_MinBorderX);
                float borderDistance = saturate(distance(i.positionOS.x,_MinBorderX) / range + Noise);
                clip(borderDistance-_DissolveThreshold);
               
                //step算出溶解边缘
                 float internalEdge = step(borderDistance,_DissolveThreshold);
                 float externalEdge = step(borderDistance, _DissolveThreshold + _EdgeWidth);;
                 float edge = externalEdge-internalEdge;
                
                 float4 finalColor = lerp(MainTex, _OutlineColor, edge * step(0.0001,_DissolveThreshold));
                  
                
                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}