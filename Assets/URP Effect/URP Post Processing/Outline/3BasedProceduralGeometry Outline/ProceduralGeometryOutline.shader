Shader "Custom/ProceduralGeometryOutline"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        [HDR]_EdgeColor("EdgeColor", Color) = (0,0,0,0)
        _EdgeScale("EdgeScale", Range(0, 1)) = 0.01
        _NormalZ("NormalZ", Range(-1, 1)) = 0.5
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
        float4 _MainTex_ST;
        float4 _OutlineColor;
        float _OutlineWidth;
        float _OutlineSpace;
        float _NormalZ;
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
            Name "Outline"
            Tags
            {
                "LightMode" = "SRPDefaultUnlit"
            }
            Cull Front

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;
                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                i.normalOS.z =_NormalZ;
                i.positionOS.xyz += normalize(i.normalOS) * _OutlineWidth;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Shading"
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
    }
}