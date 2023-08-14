Shader "Custom/GetInputs"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalScale("NormalScale", Range(0, 10)) = 1

        [Header(Specular)]
        _SpecularExp("SpecularExp", Range(1, 100)) = 32
        _SpecularStrength("SpecularStrength", Range(0, 10)) = 1
        _SpecularColor("SpecularColor", Color) = (1,1,1,1)

        _depthThickness("depthThickness",Range(0,1))=0.01
        
        [Header(RayMarching)]
        _maxRayMarchingStep("maxRayMarchingStep",Range(0,100))=10
        _maxRayMarchingDistance("maxRayMarchingDistance",Range(0,100))=10
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _BaseColor;
    float _NormalScale;
    float _SpecularExp;
    float _SpecularStrength;
    float4 _SpecularColor;
    
    float _depthThickness;
    float _maxRayMarchingStep;
    float _maxRayMarchingDistance;

    CBUFFER_END

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    TEXTURE2D(_NormalMap);
    SAMPLER(sampler_NormalMap);

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

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Varyings vert(Attributes i)
            {
                Varyings o = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);

                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;

                //TBN
                o.normalWS = normalInput.normalWS;
                o.tangentWS = float4(normalInput.tangentWS.xyz, i.tangentOS.w * GetOddNegativeScale());
                o.bitangentWS = normalInput.bitangentWS;

                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);

                return o;
            }

            // bool checkDepthCollision(float4 positionCS, float2 ScreenUV, float3 linearEyeDepth)
            // {
            //     return ScreenUV.x >= 0 &&
            //         ScreenUV.x <= 1 &&
            //         ScreenUV.y >= 0 &&
            //         ScreenUV.y <= 1 &&
            //         linearEyeDepth < positionCS.w &&
            //         linearEyeDepth + _depthThickness < positionCS.w;
            // }
            //
            // bool viewSpaceRayMarching(
            //     float3 rayOri,
            //     float3 rayDir,
            //     float currentRayMarchingStepSize,
            //     inout float depthDistance,
            //     inout float3 currentViewPos,
            //     inout float2 hitScreenPos)
            // {
            //
            //     int maxStep = _maxRayMarchingStep;
            //
            //     UNITY_LOOP
            //     for (int i = 0; i < maxStep; i++)
            //     {
            //         float3 currentPos = rayOri + rayDir * currentRayMarchingStepSize * i;
            //
            //         if (length(rayOri - currentPos) > _maxRayMarchingDistance)
            //             return false;
            //         if (checkDepthCollision(currentPos, hitScreenPos, depthDistance))
            //         {
            //             currentViewPos = currentPos;
            //             return true;
            //         }
            //     }
            //     return false;
            // }

            float4 frag(Varyings i) : SV_Target
            {
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                #if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(ScreenUV);
                #else
                 float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uvSS));
                #endif
                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
                float3 SceneNormal = SampleSceneNormals(ScreenUV);


                //纹理采样
                float4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float3 normalMap = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);

                //向量计算
                float3x3 TBN = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz);
                float3 N = TransformTangentToWorld(normalMap, TBN, true);
                float3 L = normalize(_MainLightPosition.xyz);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);
                float NdotL = dot(N, L);
                float NdotH = dot(N, H);
                //颜色计算
                float3 diffuse = (0.5 * NdotL + 0.5) * _BaseColor.rgb * _MainLightColor.rgb;
                float3 specular = pow(max(0, NdotH), _SpecularExp) * _SpecularStrength * _SpecularColor.rgb *
                    _MainLightColor.rgb;


                float4 finalColor = MainTex * float4((diffuse + _GlossyEnvironmentColor.rgb) + specular, 1);
                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}