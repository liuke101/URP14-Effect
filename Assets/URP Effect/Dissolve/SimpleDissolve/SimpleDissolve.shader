Shader "Custom/SimpleDissolve"
{
    Properties
    {
        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        _NoiseTex("NoiseTex", 2D) = "white" {}
        _EdgeColor1("BaseColor", Color) = (1,0,0,1)
        _EdgeColor2("EdgeColor", Color) = (0,0,1,1)
        _EdgeWidth("EdgeWidth", Range(0, 1)) = 0.1
        _DissolveThreshold("DissolveThreshold", Range(0, 1)) = 0.5
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
        float4 _MainTex_ST;
        float4 _EdgeColor1;
        float4 _EdgeColor2;
        float _EdgeWidth;
        float _DissolveThreshold;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

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
                o.uv = i.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
            
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float Noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv).r;
                clip(Noise - _DissolveThreshold);
                
                //思路一：smoothstep区分溶解部分和不溶解部分
                //Noise- _DissolveThreshold < 0，返回0,t = 1,表示为溶解的部分
                //Noise- _DissolveThreshold > _EdgeWidth, 返回1，t = 0，表示为不溶解的部分
                //Noise- _DissolveThreshold 在(0, _EdgeWidth),返回(0, 1)的平滑过渡值
                
                //改进：当_DissolveThreshold=0时,由于Noise不一定大于_EdgeWidth，即t不一定为0，导致始终有一小部分被溶解。
                //我们需要规定当_DissolveThreshold=0时，t也为0
                //在计算finalColor时 t * step(0.0001,_DissolveThreshold)即可
                //(t<0.0001时，返回0)
                float t = 1.0 - smoothstep(0.0,_EdgeWidth,Noise - _DissolveThreshold);
                
                //使用t值，_EdgeColor1和_EdgeColor2进行插值，得到最终的颜色
                float4 dissolveColor = lerp(_EdgeColor1, _EdgeColor2, t);
                float4 finalColor = lerp(MainTex, dissolveColor, t * step(0.0001,_DissolveThreshold));
                return float4(finalColor.rgb,1);


                //方法二：
                //思路二：step算出溶解边缘
                // float internalEdge = step(Noise, _DissolveThreshold);
                // float externalEdge = step(Noise, _DissolveThreshold + _EdgeWidth);;
                // float edge = externalEdge - internalEdge;
                //
                // float4 finalColor = lerp(MainTex, _EdgeColor1, edge * step(0.0001,_DissolveThreshold));
                // return float4(finalColor.rgb,1);
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}