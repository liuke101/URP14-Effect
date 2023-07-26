Shader "Custom/SimpleColor"
{
    Properties
    {
        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
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
        float4 _BaseColor;
        float4 _MainTex_ST;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
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
                "LightMode" = "Test1"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;

                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv =i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 finalColor = MainTex * _BaseColor;
                return finalColor*2;
            }
            ENDHLSL
        }
        
        Pass
        {
            Tags
            {
                "LightMode" = "Test2"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;

                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv =i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 finalColor = MainTex * _BaseColor;
                return finalColor*0.1;
            }
            ENDHLSL
        }
        
         Pass
        {
            Tags
            {
                "LightMode" = "Test3"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;

                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv =i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 finalColor = MainTex * _BaseColor;
                return finalColor*0.8;
            }
            ENDHLSL
        }
        
        
        
       
    }
}