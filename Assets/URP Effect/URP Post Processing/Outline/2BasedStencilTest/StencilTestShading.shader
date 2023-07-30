Shader "Custom/StencilTestOutline"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        [HDR]_EdgeColor("EdgeColor", Color) = (0,0,0,0)
        _EdgeScale("EdgeScale", Range(0, 1)) = 0.01
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }

        Stencil
        {
            Ref 0
            Comp Equal
            Pass IncrSat //通过则stencilBufferValue加1
            Fail Keep //保留当前缓冲区中的内容，即stencilBUfferValue不变
            ZFail keep
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _EdgeColor;
        float _EdgeScale;
        float _OutlineSpace;
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
            float3 normal : TEXCOORD1;
        };
        ENDHLSL


        Pass
        {
            Name "Shading"
            Tags
            {
                "LightMode" = "SRPDefaultUnlit"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv = i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 finalColor = MainTex;
                return finalColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Outline"
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
                o.uv = TRANSFORM_TEX(i.uv, _MainTex);

                //模型空间描边，远近粗细不同
                i.positionOS.xyz += normalize(i.normalOS) * _EdgeScale;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                return _EdgeColor;
            }
            ENDHLSL
        }
    }

}