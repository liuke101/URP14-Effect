Shader "Custom/SimpleColor"
{
    Properties
    {
        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        _OutlineColor("OutlineColor", Color) = (0,0,0,1)
        _OutlineScale("OutlineScale", Range(0, 1)) = 1
        
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }
    
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _OutlineColor;
        float _OutlineScale;
        float4 _MainTex_ST;
        
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
            float3 normalOS: NORMAL;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;

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
                 o.uv =i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
            
                // //在模型空间沿法线外扩
                // i.positionOS.xyz += i.normalOS * _OutlineScale * 0.01;
                //
                // o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                

                // 在裁剪空间沿法线外扩
                 VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS.xyz);
                float2 normalCS = TransformWorldToHClipDir(normalInput.normalWS,true).xy; // 世界空间->裁剪空间，只留下xy，不要z的
                o.positionCS.xy += normalCS * _OutlineScale * 0.01 * o.positionCS.w;

                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}