Shader "Custom/Tessellation"
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
        
        [Header(Tessellation)]
        [KeywordEnum(CUSTOM, VIEW)] _FactorType("Factor Type", Float) = 0
        _EdgeFactor("Edge Factor", Range(1.0, 20)) = 1.0
        _InsideFactor("Inside Factor", Range(1.0, 20)) = 1.0
        _TessFactor("Tessellation Base Factor", Range(1,64)) = 10
        _TessFadeDist("Tessellation Fade Distance", Range(1,1000)) = 5
        _TessMinDist("Tessellation Min Distance", Range(0.1, 10)) = 1

        _HeightMap("Height Map", 2D) = "white" {}
        _HeightScale("Height Scale", Range(0,10)) = 1
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"

    CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _BaseColor;
    float _NormalScale;
    float _SpecularExp;
    float _SpecularStrength;
    float4 _SpecularColor;
    
    float _EdgeFactor;
    float _InsideFactor;
    float _TessFadeDist;
    float _TessMinDist;
    float _TessFactor;
    float _HeightScale;
    CBUFFER_END

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    TEXTURE2D(_NormalMap);
    SAMPLER(sampler_NormalMap);
    TEXTURE2D(_HeightMap);
    SAMPLER(sampler_HeightMap);

    struct Attributes
    {
        float4 positionOS : POSITION;
        float4 color : COLOR;
        float3 normalOS : NORMAL;
        float4 tangentOS : TANGENT;
        float2 uv : TEXCOORD0;
    };

    struct ControlPoint
    {
        float4 positionOS : INTERNALTESSPOS; //代替 POSITION 语义，否则编译器会报位置语义的重用
        float4 color : COLOR;
        float3 normalOS : NORMAL;
        float4 tangentOS : TANGENT;
        float2 uv : TEXCOORD0;
    };

    struct TessellationFactors
    {
        float edgeFactor[3] : SV_TessFactor;   //边细分因子
        float insideFactor : SV_InsideTessFactor;//内部细分因子
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
            Name "Tessellation"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            
            #pragma target 4.6
            #pragma vertex vert
            #pragma hull HullProgram
            #pragma domain DomainProgram
            #pragma fragment frag
            #pragma shader_feature _ _FACTORTYPE_CUSTOM _FACTORTYPE_VIEW 

            ControlPoint vert(Attributes i)
            {
                ControlPoint o = (ControlPoint)0;
                o.positionOS = i.positionOS;
                o.color = i.color;
                o.normalOS = i.normalOS;
                o.tangentOS = i.tangentOS;
                o.uv = i.uv;

                return o;
            }

            //将顶点数据传递到镶嵌阶段
            [domain("tri")]
            [outputcontrolpoints(3)]
            [partitioning("fractional_odd")] 
            [outputtopology("triangle_cw")]
            [patchconstantfunc("PatchConstantFunction")]
            [maxtessfactor(64.0)]
            ControlPoint HullProgram(InputPatch<ControlPoint, 3> patch, uint controlPointID : SV_OutputControlPointID)
            {
                return patch[controlPointID];
            }

            //LOD
            #ifdef _FACTORTYPE_VIEW
            float3 GetDistanceBasedTessFactor(float3 p0, float3 p1, float3 p2, float3 cameraPosWS, float tessMinDist, float tessMaxDist) 
            {
                float3 edgePosition0 = 0.5 * (p1 + p2);
                float3 edgePosition1 = 0.5 * (p0 + p2);
                float3 edgePosition2 = 0.5 * (p0 + p1);

                // In case camera-relative rendering is enabled, 'cameraPosWS' is statically known to be 0,
                // so the compiler will be able to optimize distance() to length().
                float dist0 = distance(edgePosition0, cameraPosWS);
                float dist1 = distance(edgePosition1, cameraPosWS);
                float dist2 = distance(edgePosition2, cameraPosWS);

                // The saturate will handle the produced NaN in case min == max
                float fadeDist = tessMaxDist - tessMinDist;
                float3 tessFactor;
                tessFactor.x = saturate(1.0 - (dist0 - tessMinDist) / fadeDist);
                tessFactor.y = saturate(1.0 - (dist1 - tessMinDist) / fadeDist);
                tessFactor.z = saturate(1.0 - (dist2 - tessMinDist) / fadeDist);

                return tessFactor;//[0,1] from distance
            }

            float4 CalcTriTessFactorsFromEdgeTessFactors(float3 triVertexFactors)
            {
                float4 tess;
                tess.x = triVertexFactors.x;
                tess.y = triVertexFactors.y;
                tess.z = triVertexFactors.z;
                tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0;

                return tess;
            }
            #endif

            TessellationFactors PatchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                TessellationFactors o;
                #ifdef _FACTORTYPE_VIEW
                    float3 cameraPosWS = _WorldSpaceCameraPos.xyz;

                    float3 p0 = TransformObjectToWorld(patch[0].positionOS.xyz);
                    float3 p1 = TransformObjectToWorld(patch[1].positionOS.xyz);
                    float3 p2 = TransformObjectToWorld(patch[2].positionOS.xyz);

                    float3 factors = GetDistanceBasedTessFactor(p0,p1,p2, cameraPosWS, _TessMinDist, _TessMinDist + _TessFadeDist);
                    float4 finalfactors = _TessFactor * CalcTriTessFactorsFromEdgeTessFactors(factors);

                    o.edgeFactor[0] = max(1.0, finalfactors.x);
                    o.edgeFactor[1] = max(1.0, finalfactors.y);
                    o.edgeFactor[2] = max(1.0, finalfactors.z);
                    o.insideFactor = max(1.0, finalfactors.w);

                #elif _FACTORTYPE_CUSTOM
                    o.edgeFactor[0] = _EdgeFactor;
                    o.edgeFactor[1] = _EdgeFactor;
                    o.edgeFactor[2] = _EdgeFactor;
                    o.insideFactor = _InsideFactor;
                #else
                    o.edgeFactor[0] = 1.0;
                    o.edgeFactor[1] = 1.0;
                    o.edgeFactor[2] = 1.0;
                    o.insideFactor = 1.0;
                #endif

                    return o;
            }

            //Hull着色器和Domain着色器都作用于相同的域，即三角形。我们通过domain属性再次发出信号
            [domain("tri")] 
            Varyings DomainProgram(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch,float3 barycentricCoordinates : SV_DomainLocation)
            {
                Attributes i;

                //为了找到该顶点的位置，我们必须使用重心坐标在原始三角形范围内进行插值,为此定义一个宏
                #define DOMAIN_BARYCOORD_INTERPOLATE(fieldName) i.fieldName = \
                        patch[0].fieldName * barycentricCoordinates.x + \
                        patch[1].fieldName * barycentricCoordinates.y + \
                        patch[2].fieldName * barycentricCoordinates.z;

                //对位置、颜色、UV、法线切线和所有UV坐标进行插值
                DOMAIN_BARYCOORD_INTERPOLATE(positionOS)
                DOMAIN_BARYCOORD_INTERPOLATE(color)
                DOMAIN_BARYCOORD_INTERPOLATE(normalOS)
                DOMAIN_BARYCOORD_INTERPOLATE(tangentOS)
                DOMAIN_BARYCOORD_INTERPOLATE(uv)

                //域着色器接管了原始顶点程序的职责
                Varyings o = (Varyings)0;
        
                float height = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv, 0).r * _HeightScale;
                 i.positionOS.y += height;
        
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

            float4 frag(Varyings i) : SV_Target
            {
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
                float3 specular = pow(max(0, NdotH), _SpecularExp) * _SpecularStrength * _SpecularColor.rgb * _MainLightColor.rgb;

                float4 finalColor = MainTex * float4((diffuse + _GlossyEnvironmentColor.rgb) + specular, 1);
                return finalColor;
                //return SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, i.uv);
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}