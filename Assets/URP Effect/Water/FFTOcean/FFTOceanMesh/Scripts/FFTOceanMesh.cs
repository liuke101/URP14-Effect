using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

public class FFTOceanMesh : MonoBehaviour
{

    [Range(3, 14)]
    public int fftPow = 10;         //生成海洋纹理大小 2的次幂，例 为10时，纹理大小为1024*1024
    public float a = 10;			//phillips谱参数，影响波浪高度
    public float lambda = -1;       //用来控制偏移大小
    public float heightScale = 1;   //高度影响
    public float bubblesScale = 1;  //泡沫强度
    public float bubblesThreshold = 1;//泡沫阈值
    public float windScale = 2;     //风强
    public float timeScale = 1;     //时间影响
    public Vector4 windAndSeed = new Vector4(0.1f, 0.2f, 0, 0);//风向和随机种子 xy为风, zw为两个随机种子
    public ComputeShader computeShader;   //计算海洋的ComputeShader
    public Material oceanMaterial;  //渲染海洋的材质
    public Material displaceXMat;   //x偏移材质
    public Material displaceYMat;   //y偏移材质
    public Material displaceZMat;   //z偏移材质
    public Material displaceMat;    //偏移材质
    public Material normalMat;      //法线材质
    public Material bubblesMat;     //泡沫材质
    
    [Range(0, 12)]
    public int controlM = 12;       //控制m,控制FFT变换阶段
    public bool isControlH = true;  //是否控制横向FFT，否则控制纵向FFT
    
    private float m_meshLength;	    //Mesh网格长度
    private int m_fftSize;			//fft纹理大小 = pow(2,FFTPow)
    private float m_time;           //时间


    //KernelIndex
    private int m_computeGaussianRandomKernelIndex;            //计算高斯随机数
    private int m_createHeightSpectrumKernelIndex;             //创建高度频谱
    private int m_createDisplaceSpectrumKernelIndex;           //创建偏移频谱
    private int m_fftHorizontalKernelIndex;                    //FFT横向
    private int m_fftHorizontalEndKernelIndex;                 //FFT横向，最后阶段
    private int m_fftVerticalKernelIndex;                      //FFT纵向
    private int m_fftVerticalEndKernelIndex;                   //FFT纵向,最后阶段
    private int m_textureGenerationDisplaceKernelIndex;        //生成偏移纹理
    private int m_textureGenerationNormalBubblesKernelIndex;   //生成法线和泡沫纹理
    
    //RenderTexture
    private RenderTexture m_gaussianRandomRT;             //高斯随机数
    private RenderTexture m_heightSpectrumRT;             //高度频谱
    private RenderTexture m_displaceXSpectrumRT;          //X偏移频谱
    private RenderTexture m_displaceZSpectrumRT;          //Z偏移频谱
    private RenderTexture m_displaceRT;                   //偏移频谱
    private RenderTexture m_outputRT;                     //临时储存输出纹理
    private RenderTexture m_normalRT;                     //法线纹理
    private RenderTexture m_bubblesRT;                    //泡沫纹理

    private void Awake()
    {
        //获取mesh的长度
        m_meshLength = transform.localScale.x;
    }

    private void Start()
    {
        //初始化ComputerShader相关数据
        InitializeComputeShader();
    }
    private void Update()
    {
        m_time += UnityEngine.Time.deltaTime * timeScale;
        //计算海洋数据
        ComputeOceanValue();
    }

    
    /// <summary>
    /// 初始化Computer Shader相关数据
    /// </summary>
    private void InitializeComputeShader()
    {
        m_fftSize = (int)Mathf.Pow(2, fftPow);

        //创建渲染纹理
        if (m_gaussianRandomRT != null && m_gaussianRandomRT.IsCreated())
        {
            m_gaussianRandomRT.Release();
            m_heightSpectrumRT.Release();
            m_displaceXSpectrumRT.Release();
            m_displaceZSpectrumRT.Release();
            m_displaceRT.Release();
            m_outputRT.Release();
            m_normalRT.Release();
            m_bubblesRT.Release();
        }
        
        m_gaussianRandomRT = CreateRT(m_fftSize);
        m_heightSpectrumRT = CreateRT(m_fftSize);
        m_displaceXSpectrumRT = CreateRT(m_fftSize);
        m_displaceZSpectrumRT = CreateRT(m_fftSize);
        m_displaceRT = CreateRT(m_fftSize);
        m_outputRT = CreateRT(m_fftSize);
        m_normalRT = CreateRT(m_fftSize);
        m_bubblesRT = CreateRT(m_fftSize);

        //获取所有核函数索引
        m_computeGaussianRandomKernelIndex = computeShader.FindKernel("ComputeGaussianRandom");
        m_createHeightSpectrumKernelIndex = computeShader.FindKernel("CreateHeightSpectrum");
        m_createDisplaceSpectrumKernelIndex = computeShader.FindKernel("CreateDisplaceSpectrum");
        m_fftHorizontalKernelIndex = computeShader.FindKernel("FFTHorizontal");
        m_fftHorizontalEndKernelIndex = computeShader.FindKernel("FFTHorizontalEnd");
        m_fftVerticalKernelIndex = computeShader.FindKernel("FFTVertical");
        m_fftVerticalEndKernelIndex = computeShader.FindKernel("FFTVerticalEnd");
        m_textureGenerationDisplaceKernelIndex = computeShader.FindKernel("TextureGenerationDisplace");
        m_textureGenerationNormalBubblesKernelIndex = computeShader.FindKernel("TextureGenerationNormalBubbles");

        //设置ComputerShader数据
        computeShader.SetInt("N", m_fftSize); 
        computeShader.SetFloat("OceanLength", m_meshLength);


        //生成高斯随机数
        computeShader.SetTexture(m_computeGaussianRandomKernelIndex, "GaussianRandomRT", m_gaussianRandomRT);
        computeShader.Dispatch(m_computeGaussianRandomKernelIndex, m_fftSize / 8, m_fftSize / 8, 1);
    }
    
    /// <summary>
    /// 创建渲染纹理
    /// </summary>
    private RenderTexture CreateRT(int size)
    {
        RenderTexture rt = new RenderTexture(size, size, 0, RenderTextureFormat.ARGBFloat);
        rt.enableRandomWrite = true;
        rt.Create();
        return rt;
    }
    
    /// <summary>
    /// 计算海洋数据
    /// </summary>
    private void ComputeOceanValue()
    {
        computeShader.SetFloat("A", a);
        windAndSeed.z = Random.Range(1, 10f);
        windAndSeed.w = Random.Range(1, 10f);
        Vector2 wind = new Vector2(windAndSeed.x, windAndSeed.y);
        wind.Normalize();
        wind *= windScale;
        computeShader.SetVector("WindAndSeed", new Vector4(wind.x, wind.y, windAndSeed.z, windAndSeed.w));
        computeShader.SetFloat("Time", m_time);
        computeShader.SetFloat("Lambda", lambda);
        computeShader.SetFloat("HeightScale", heightScale);
        computeShader.SetFloat("BubblesScale", bubblesScale);
        computeShader.SetFloat("BubblesThreshold",bubblesThreshold);

        //生成高度频谱
        computeShader.SetTexture(m_createHeightSpectrumKernelIndex, "GaussianRandomRT", m_gaussianRandomRT); //将初始化好的高斯随机数传入这个核函数
        computeShader.SetTexture(m_createHeightSpectrumKernelIndex, "HeightSpectrumRT", m_heightSpectrumRT);
        computeShader.Dispatch(m_createHeightSpectrumKernelIndex, m_fftSize / 8, m_fftSize / 8, 1);

        //生成偏移频谱
        computeShader.SetTexture(m_createDisplaceSpectrumKernelIndex, "HeightSpectrumRT", m_heightSpectrumRT);
        computeShader.SetTexture(m_createDisplaceSpectrumKernelIndex, "DisplaceXSpectrumRT", m_displaceXSpectrumRT);
        computeShader.SetTexture(m_createDisplaceSpectrumKernelIndex, "DisplaceZSpectrumRT", m_displaceZSpectrumRT);
        computeShader.Dispatch(m_createDisplaceSpectrumKernelIndex, m_fftSize / 8, m_fftSize / 8, 1);


        if (controlM == 0)
        {
            SetMaterialTex();
            return;
        }

        //进行横向FFT
        for (int m = 1; m <= fftPow; m++)
        {
            int ns = (int)Mathf.Pow(2, m - 1);
            computeShader.SetInt("Ns", ns);
            
            if (m != fftPow)
            {
                ComputeFFT(m_fftHorizontalKernelIndex, ref m_heightSpectrumRT);
                ComputeFFT(m_fftHorizontalKernelIndex, ref m_displaceXSpectrumRT);
                ComputeFFT(m_fftHorizontalKernelIndex, ref m_displaceZSpectrumRT);
            }
            //最后阶段进行特殊处理
            else
            {
                ComputeFFT(m_fftHorizontalEndKernelIndex, ref m_heightSpectrumRT);
                ComputeFFT(m_fftHorizontalEndKernelIndex, ref m_displaceXSpectrumRT);
                ComputeFFT(m_fftHorizontalEndKernelIndex, ref m_displaceZSpectrumRT);
            }
            if (isControlH && controlM == m)
            {
                SetMaterialTex();
                return;
            }
        }
        //进行纵向FFT
        for (int m = 1; m <= fftPow; m++)
        {
            int ns = (int)Mathf.Pow(2, m - 1);
            computeShader.SetInt("Ns", ns);
            
            if (m != fftPow)
            {
                ComputeFFT(m_fftVerticalKernelIndex, ref m_heightSpectrumRT);
                ComputeFFT(m_fftVerticalKernelIndex, ref m_displaceXSpectrumRT);
                ComputeFFT(m_fftVerticalKernelIndex, ref m_displaceZSpectrumRT);
            }
            //最后阶段进行特殊处理
            else
            {
                ComputeFFT(m_fftVerticalEndKernelIndex, ref m_heightSpectrumRT);
                ComputeFFT(m_fftVerticalEndKernelIndex, ref m_displaceXSpectrumRT);
                ComputeFFT(m_fftVerticalEndKernelIndex, ref m_displaceZSpectrumRT);
            }
            if (!isControlH && controlM == m)
            {
                SetMaterialTex();
                return;
            }
        }

        //将所需RT传入核函数
        //计算纹理偏移Dy,Dx,Dz
        computeShader.SetTexture(m_textureGenerationDisplaceKernelIndex, "HeightSpectrumRT", m_heightSpectrumRT); 
        computeShader.SetTexture(m_textureGenerationDisplaceKernelIndex, "DisplaceXSpectrumRT", m_displaceXSpectrumRT);
        computeShader.SetTexture(m_textureGenerationDisplaceKernelIndex, "DisplaceZSpectrumRT", m_displaceZSpectrumRT);
        computeShader.SetTexture(m_textureGenerationDisplaceKernelIndex, "DisplaceRT", m_displaceRT);
        computeShader.Dispatch(m_textureGenerationDisplaceKernelIndex, m_fftSize / 8, m_fftSize / 8, 1);

        //生成法线和泡沫纹理
        computeShader.SetTexture(m_textureGenerationNormalBubblesKernelIndex, "DisplaceRT", m_displaceRT);
        computeShader.SetTexture(m_textureGenerationNormalBubblesKernelIndex, "NormalRT", m_normalRT);
        computeShader.SetTexture(m_textureGenerationNormalBubblesKernelIndex, "BubblesRT", m_bubblesRT);
        computeShader.Dispatch(m_textureGenerationNormalBubblesKernelIndex, m_fftSize / 8, m_fftSize / 8, 1);

        SetMaterialTex();
    }
    
    //计算fft
    private void ComputeFFT(int kernel, ref RenderTexture input)
    {
        computeShader.SetTexture(kernel, "InputRT", input);
        computeShader.SetTexture(kernel, "OutputRT", m_outputRT);
        computeShader.Dispatch(kernel, m_fftSize / 8, m_fftSize / 8, 1);

        //交换输入输出纹理
        (input, m_outputRT) = (m_outputRT, input);

        // 等价实现：
        // RenderTexture rt = input;
        // input = m_outputRT;
        // m_outputRT = rt;
    }
    //设置材质纹理
    private void SetMaterialTex()
    {
        //设置海洋材质纹理
        oceanMaterial.SetTexture("_Displace", m_displaceRT);
        oceanMaterial.SetTexture("_Normal", m_normalRT);
        oceanMaterial.SetTexture("_Bubbles", m_bubblesRT);

        //设置显示纹理
        displaceXMat.SetTexture("_MainTex", m_displaceXSpectrumRT);
        displaceYMat.SetTexture("_MainTex", m_heightSpectrumRT);
        displaceZMat.SetTexture("_MainTex", m_displaceZSpectrumRT);
        displaceMat.SetTexture("_MainTex", m_displaceRT);
        normalMat.SetTexture("_MainTex", m_normalRT);
        bubblesMat.SetTexture("_MainTex", m_bubblesRT);
    }
}
