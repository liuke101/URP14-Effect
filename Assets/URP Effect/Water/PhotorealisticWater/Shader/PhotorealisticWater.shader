Shader "Water/PhotorealisticWater"
{
    Properties
    {
        [Header(Depth)][Space]
        [Space]
        _MaxDepth("最大深度", Range(0, 1000)) = 10
        [HDR]_DepthColor("深水区颜色", Color) = (0,0,1,1)
        [HDR]_ShallowColor("浅水区颜色", Color) = (0,1,1,1)
        
        [Header(FFT)][Space]
        _FFTDisplace ("FFT偏移纹理", 2D) = "black" { }
        _FFTNormal ("FFT法线纹理", 2D) = "black" { }
        _FFTBubbles ("FFT泡沫纹理", 2D) = "black" { }

        [Header(Foam)][Space]
        _SurfaceNoise("水面噪声贴图", 2D) = "white" {}
        _SurfaceNoiseCutoff("噪声贴图裁切", Range(0, 1)) = 0.777
        _FoamMaxDistance("Foam Maximum Distance", Range(0,10)) = 0.4
        _FoamMinDistance("Foam Minimum Distance", Range(0,10)) = 0.04
        _FoamEdgeFade("Foam Edge Fade", Range(0,1)) = 0.5

        [Header(FlowMap)][Space]
        _FlowMap("FlowMap", 2D) = "white" {}
        _FlowSpeed("向量场速度", Range(0, 10)) = 1

        [Header(Settings)][Space]
        _TimeSpeed("水流速度", Vector) = (0.03,0.03,0,1)

        [Header(Refract)][Space]
        _RefractFactor("折射系数", Range(0, 100)) = 1
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalScale("NormalScale", Range(0, 10)) = 1


        [Header(Reflect)][Space]
        _SpecularPower("SpecularPower", Range(0, 256)) = 32
        _SpecularScale("SpecularScale", Range(0, 100)) = 1
        _FresnelPower("FresnelPower", Range(0, 32)) = 5
        _FresnelScale("FresnelScale", Range(0, 10)) = 1
        _CubeMap("CubeMap", CUBE) = "white" {}
        _ReflectNormalLerp("ReflectNormalLerp", Range(0, 1)) = 0.05

        [Header(Caustic)][Space]
        _CausticTex("CausticTex", 2D) = "white" {}

        [Header(Tessellation)][Space]
        [KeywordEnum(CUSTOM, VIEW)] _FactorType("Factor Type", Float) = 0
        //CUSTOM:细分因子由_EdgeFactor和_InsideFactor控制
        //VIEW:细分因子由相机距离和_TessFactor控制
        _EdgeFactor("Edge Factor", Range(1.0, 64)) = 1.0
        _InsideFactor("Inside Factor", Range(1.0,64)) = 1.0
        _TessFactor("Tessellation Base Factor", Range(1,1000)) = 10
        _TessFadeDist("Tessellation Fade Distance", Range(1,1000)) = 5
        _TessMinDist("Tessellation Min Distance", Range(0.1, 10)) = 1
        
        [Header(Option)][Space]
        [Enum(UnityEngine.Rendering.BlendOp)]  _BlendOp  ("BlendOp", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", Float) = 10
        [Enum(Off, 0, On, 1)]_ZWriteMode ("ZWriteMode", float) = 0
        [Enum(UnityEngine.Rendering.CullMode)]_CullMode ("CullMode", float) = 0
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

    CBUFFER_START(UnityPerMaterial)

    //Depth
    float _MaxDepth;
    float4 _DepthColor;
    float4 _ShallowColor;

    //FFT
    float4 _FFTDisplace_ST;
    //Foam
    float4 _SurfaceNoise_ST;
    float _SurfaceNoiseCutoff;
    float _FoamMaxDistance;
    float _FoamMinDistance;
    float _FoamEdgeFade;


    //FlowMap
    float _FlowSpeed;

    //Settings
    float2 _TimeSpeed;

    //Reflect
    float _RefractFactor;
    float _NormalScale;
    float4 _NormalMap_ST;
    float _SpecularPower;
    float _SpecularScale;
    float _FresnelPower;
    float _FresnelScale;
    float _ReflectNormalLerp;

    //caustic
    float4 _CausticTex_ST;

    //Tessellation
    float _EdgeFactor;
    float _InsideFactor;
    float _TessFadeDist;
    float _TessMinDist;
    float _TessFactor;
    float _HeightScale;
    
    CBUFFER_END

    TEXTURE2D(_NormalMap);
    SAMPLER(sampler_NormalMap);
    TEXTURE2D(_FFTDisplace);
    SAMPLER(sampler_FFTDisplace);
    TEXTURE2D(_FFTNormal);
    SAMPLER(sampler_FFTNormal);
    TEXTURE2D(_FFTBubbles);
    SAMPLER(sampler_FFTBubbles);
    TEXTURE2D(_SurfaceNoise);
    SAMPLER(sampler_SurfaceNoise);
    TEXTURE2D(_FlowMap);
    SAMPLER(sampler_FlowMap);
    TEXTURE2D(_CausticTex);
    SAMPLER(sampler_CausticTex);
    TEXTURE2D(_CameraOpaqueTexture);
    SAMPLER(sampler_CameraOpaqueTexture);
    TEXTURECUBE(_CubeMap);
    SAMPLER(sampler_CubeMap);
    float4 _CameraOpaqueTexture_TexelSize;
    SAMPLER(sampler_unity_SpecCube0);

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
        float edgeFactor[3] : SV_TessFactor; //边细分因子
        float insideFactor : SV_InsideTessFactor; //内部细分因子
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float4 color : COLOR0;
        float2 uv : TEXCOORD0;
        float3 positionWS: TEXCOORD1;
        float3 normalWS : TEXCOORD2;
        float2 normalUV : TEXCOORD3;
        float3 normalVS : TEXCOORD4;
        float4 tangentWS : TEXCOORD5;
        float3 bitangentWS : TEXCOORD6;
        float3 viewDirWS : TEXCOORD7;
        float2 noiseUV : TEXCOORD8;
        float3 positionVS : TEXCOORD9;
    };
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }
        Pass
        {
            Name "Tessellation"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Cull [_CullMode]
            BlendOp [_BlendOp]
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWriteMode]

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
                o.uv = TRANSFORM_TEX(i.uv, _FFTDisplace);
                float4 displace = SAMPLE_TEXTURE2D_LOD(_FFTDisplace, sampler_FFTDisplace, o.uv, 0);
                i.positionOS += float4(displace.xyz, 0); //顶点偏移
        
                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);
        
                //o.uv = i.uv;
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;
                o.positionVS = vertexInput.positionVS;

                //TBN
                o.normalWS = normalInput.normalWS;
                o.normalVS = TransformWorldToViewNormal(o.normalWS);
                o.tangentWS = float4(normalInput.tangentWS.xyz, i.tangentOS.w * GetOddNegativeScale());
                o.bitangentWS = normalInput.bitangentWS;

                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);

                //扰动UV
                o.normalUV = TRANSFORM_TEX(float2(i.uv + _TimeSpeed*_Time.y), _NormalMap);
                o.noiseUV = TRANSFORM_TEX(float2(i.uv + _TimeSpeed*_Time.y), _SurfaceNoise);
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                //--------------------------------------------
                // 折射
                //--------------------------------------------
                //屏幕UV
                float2 ScreenUV = GetNormalizedScreenSpaceUV(i.positionCS);
                //扭曲：法线纹理采样

                //法线贴图扰动屏幕UV
                float3 normalMap = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.normalUV), _NormalScale);
                float3x3 TBN = CreateTangentToWorld(i.normalWS, i.tangentWS.xyz, i.tangentWS.w);
                float3 N = TransformTangentToWorld(normalMap, TBN, true);
                float2 bias = N.xy * _CameraOpaqueTexture_TexelSize.xy * _RefractFactor;
                float2 ScreenUVRefract = ScreenUV + bias;

                //--------------------------------------------
                // FFT
                //--------------------------------------------
                float3 fftNormal = SAMPLE_TEXTURE2D(_FFTNormal, sampler_FFTNormal, i.uv).rgb;
                //float3 fftDisplace = SAMPLE_TEXTURE2D(_FFTDisplace, sampler_FFTDisplace, i.uv).rgb;
                //--------------------------------------------
                // 基于深度着色
                //--------------------------------------------
                //1 水下不透明物体在深度纹理中的观察空间深度
                //没有被扰动的
                #if UNITY_REVERSED_Z
                float opaqueDepth = SampleSceneDepth(ScreenUV);
                #else
                float opaqueDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUV)); 
                #endif
                float opaqueDepthVS = LinearEyeDepth(opaqueDepth, _ZBufferParams);
                
                //被扰动的
                #if UNITY_REVERSED_Z
                float opaqueDepthRefract = SampleSceneDepth(ScreenUVRefract);
                #else
                float opaqueDepthRefract = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(ScreenUVRefract)); 
                #endif
                float opaqueDepthRefractVS = LinearEyeDepth(opaqueDepthRefract, _ZBufferParams); //线性
                
                //2 水面的观察空间深度
                float waterSurfaceDepth = i.positionCS.w; //或= -i.positionVS.z
                //3 计算水深
                float waterDepth = opaqueDepthVS - waterSurfaceDepth;
                float waterDepthRefract = opaqueDepthRefractVS - waterSurfaceDepth;

                //4 除以最大水深，归一化深度
                float waterDepthNormalize = saturate(waterDepthRefract / _MaxDepth);
                //5 插值深度着色
                float4 waterColor = lerp(_ShallowColor, _DepthColor, waterDepthNormalize);

                //--------------------------------------------
                // 判断水上水下，水上用屏幕UV，水下用扭曲UV，来采样不透明纹理
                //--------------------------------------------
                if (waterDepth < 0)
                {
                    ScreenUVRefract = ScreenUV;
                }
                float4 OpaqueTexture = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture,ScreenUVRefract);
                //--------------------------------------------
                // 泡沫(采用未扰动的UV和深度)
                //--------------------------------------------
                //FlowMap来处理噪声贴图
                float3 flowDir = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, i.uv).rgb * 2.0 - 1.0;
                flowDir *= _FlowSpeed;
                float phase0 = frac(_Time.y * _TimeSpeed.x);
                float phase1 = frac(_Time.y * _TimeSpeed.x + 0.5);
                float tex0 = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, i.noiseUV-flowDir.xy*phase0).r;
                float tex1 = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, i.noiseUV-flowDir.xy*phase1).r;
                float NoiseFlowTex = lerp(tex0, tex1, abs((0.5 - phase0) / 0.5));

                //泡沫深度
                float3 NormalsTexture = normalize(SampleSceneNormals(ScreenUV));

                float normalDot = saturate(dot(NormalsTexture, i.normalVS)); //法线纹理点积观察空间法线

                float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
                float foamDepthDifference = saturate(waterDepth / foamDistance);

                //越深裁剪值越大
                float FoamNoiseCutoff = foamDepthDifference * _SurfaceNoiseCutoff;
                //抗锯齿：平滑过渡
                float FoamNoise = smoothstep(FoamNoiseCutoff - _FoamEdgeFade, FoamNoiseCutoff + _FoamEdgeFade,
                                             NoiseFlowTex);

                //--------------------------------------------
                // 反射
                //--------------------------------------------
                //高光反射
                //向量计算
                float3 L = normalize(_MainLightPosition.xyz);
                float3 V = normalize(i.viewDirWS);
                float3 H = normalize(L + V);
                float3 ReflectN = lerp(i.normalWS, N, _ReflectNormalLerp);
                float NdotH = dot(N, H);
                float3 specular = pow(max(0, NdotH), _SpecularPower) * _SpecularScale * _MainLightColor.rgb;
                
                //Fresnel
                float fresnel = pow(1 - saturate(dot(i.normalWS, V)), _FresnelPower) * _FresnelScale;

                //环境反射
                //CubeMap
                float3 R = normalize(reflect(-V, ReflectN));
                float4 cubeMap = SAMPLE_TEXTURECUBE(_CubeMap, sampler_CubeMap, R);
                float3 cubeMapcolor = DecodeHDREnvironment(cubeMap, unity_SpecCube0_HDR);
                //实时环境反射：反射探针
                // float4 environment = SAMPLE_TEXTURECUBE(unity_SpecCube0,sampler_unity_SpecCube0, R); 
                // float3 envcolor = DecodeHDREnvironment(environment, unity_SpecCube0_HDR); 


                //--------------------------------------------
                // 焦散(深度重建世界坐标xz分量采样焦散贴图)
                //--------------------------------------------
                // float3 rebuildPosWS = ComputeWorldSpacePosition(ScreenUV, opaqueDepthRefract, UNITY_MATRIX_I_VP);
                // float4 CausticTex = SAMPLE_TEXTURE2D(_CausticTex, sampler_CausticTex, float2((rebuildPosWS.xz + _TimeSpeed * _Time.y) * _CausticTex_ST.xy +_CausticTex_ST.zw))*waterDepth;
                //卡通水
                float4 finalColor = waterColor * OpaqueTexture + FoamNoise + float4(cubeMapcolor + specular + fresnel, 1);

                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}