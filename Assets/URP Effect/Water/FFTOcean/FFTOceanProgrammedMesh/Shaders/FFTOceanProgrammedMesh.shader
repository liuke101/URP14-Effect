Shader "FFTOcean/FFTOceanProgrammedMesh"
{
    Properties
    {
        _OceanColorShallow ("Ocean Color Shallow", Color) = (1, 1, 1, 1)
        _OceanColorDeep ("Ocean Color Deep", Color) = (1, 1, 1, 1)
        _BubblesColor ("Bubbles Color", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
        _FresnelScale ("Fresnel Scale", Range(0, 1)) = 0.5
        _Displace ("Displace", 2D) = "black" { }
        _Normal ("Normal", 2D) = "black" { }
        _Bubbles ("Bubbles", 2D) = "black" { }
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
        float4 _OceanColorShallow;
        float4 _OceanColorDeep;
        float4 _BubblesColor;
        float4 _Specular;
        float _Gloss;
        float _FresnelScale;
        float4 _Displace_ST;
        CBUFFER_END


        TEXTURE2D(_Displace);
        SAMPLER(sampler_Displace);
        TEXTURE2D(_Normal);
        SAMPLER(sampler_Normal);
        TEXTURE2D(_Bubbles);
        SAMPLER(sampler_Bubbles);

        struct Attributes
    {
        float4 positionOS : POSITION;
        float4 color : COLOR;
        float3 normalOS : NORMAL;
        float4 tangentOS : TANGENT;
        float2 uv : TEXCOORD0;
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float4 color : COLOR0;
        float2 uv : TEXCOORD0;
        float3 positionWS: TEXCOORD1;
        float3 normalWS : TEXCOORD2;
        float4 tangentWS : TEXCOORD3;
        float3 bitangentWS : TEXCOORD4;
        float3 viewDirWS : TEXCOORD5;
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
                o.uv = TRANSFORM_TEX(i.uv, _Displace);
                float4 displace = SAMPLE_TEXTURE2D_LOD(_Displace, sampler_Displace, o.uv, 0);
                i.positionOS += float4(displace.xyz,0);  //顶点偏移

                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);

                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;

                //TBN
                o.normalWS = normalInput.normalWS;
                o.tangentWS = float4(normalInput.tangentWS.xyz, i.tangentOS.w * GetOddNegativeScale());
                o.bitangentWS = normalInput.bitangentWS;
                
                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {

                //纹理采样
                float3 normal = UnpackNormal(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, i.uv));
                float bubbles = SAMPLE_TEXTURE2D(_Bubbles, sampler_Bubbles, i.uv).r;

                //向量计算
                float3x3 TBN = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz);
                float3 N = TransformTangentToWorld(normal, TBN, true);
                float3 L = normalize(_MainLightPosition.xyz);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);
                float NdotL = dot(N, L);
                float NdotH = dot(N, H);
                
                
                //菲涅尔
                float fresnel = saturate(_FresnelScale + (1 - _FresnelScale) * pow(1 - dot(normal, V), 5));
                
                half facing = saturate(dot(V, normal));                
                float3 oceanColor = lerp(_OceanColorShallow.rgb, _OceanColorDeep.rgb, facing);
                
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
                //泡沫颜色
                float3 bubblesDiffuse = _BubblesColor.rbg * _MainLightColor.rgb * saturate(dot(L, normal));
                //海洋颜色
                float3 oceanDiffuse = oceanColor * _MainLightColor.rgb * saturate(dot(L, normal));
                float3 halfDir = normalize(L + V);
                float3 specular = _MainLightColor.rgb * _Specular.rgb * pow(max(0, dot(normal, halfDir)), _Gloss);
                
                float3 diffuse = lerp(oceanDiffuse, bubblesDiffuse, bubbles);
                
                float3 col = (ambient + diffuse + specular)*fresnel ;
                
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}