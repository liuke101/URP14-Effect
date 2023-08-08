using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

public class FFTOcean : MonoBehaviour
{

    [Range(3, 14)]
    public int fftPow = 10;         //生成海洋纹理大小 2的次幂，例 为10时，纹理大小为1024*1024
    public int meshSize = 250;		//网格长宽数量
    public float meshLength = 10;	//网格长度
    public float a = 10;			//phillips谱参数，影响波浪高度
    public float lambda = -1;       //用来控制偏移大小
    public float heightScale = 1;   //高度影响
    public float bubblesScale = 1;  //泡沫强度
    public float bubblesThreshold = 1;//泡沫阈值
    public float windScale = 2;     //风强
    public float timeScale = 1;     //时间影响
    public Vector4 windAndSeed = new Vector4(0.1f, 0.2f, 0, 0);//风向和随机种子 xy为风, zw为两个随机种子
    public ComputeShader oceanCs;   //计算海洋的cs
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
    
    private int m_fftSize;			//fft纹理大小 = pow(2,FFTPow)
    private float m_time = 0;             //时间

    private int[] m_vertIndexs;		//网格三角形索引
    private Vector3[] m_positions;    //位置
    private Vector2[] m_uvs; 			//uv坐标
    private Mesh m_mesh;
    private MeshFilter m_filetr;
    private MeshRenderer m_render;



    private int m_kernelComputeGaussianRandom;            //计算高斯随机数
    private int m_kernelCreateHeightSpectrum;             //创建高度频谱
    private int m_kernelCreateDisplaceSpectrum;           //创建偏移频谱
    private int m_kernelFFTHorizontal;                    //FFT横向
    private int m_kernelFFTHorizontalEnd;                 //FFT横向，最后阶段
    private int m_kernelFFTVertical;                      //FFT纵向
    private int m_kernelFFTVerticalEnd;                   //FFT纵向,最后阶段
    private int m_kernelTextureGenerationDisplace;        //生成偏移纹理
    private int m_kernelTextureGenerationNormalBubbles;   //生成法线和泡沫纹理
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
        //添加网格及渲染组件
        m_filetr = gameObject.GetComponent<MeshFilter>();
        if (m_filetr == null)
        {
            m_filetr = gameObject.AddComponent<MeshFilter>();
        }
        m_render = gameObject.GetComponent<MeshRenderer>();
        if (m_render == null)
        {
            m_render = gameObject.AddComponent<MeshRenderer>();
        }
        m_mesh = new Mesh();
        m_filetr.mesh = m_mesh;
        m_render.material = oceanMaterial;
    }

    private void Start()
    {
        //创建网格
        CreateMesh();
        //初始化ComputerShader相关数据
        InitializeCSvalue();
    }
    private void Update()
    {
        m_time += Time.deltaTime * timeScale;
        //计算海洋数据
        ComputeOceanValue();
    }


    /// <summary>
    /// 初始化Computer Shader相关数据
    /// </summary>
    private void InitializeCSvalue()
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

        //获取所有kernelID
        m_kernelComputeGaussianRandom = oceanCs.FindKernel("ComputeGaussianRandom");
        m_kernelCreateHeightSpectrum = oceanCs.FindKernel("CreateHeightSpectrum");
        m_kernelCreateDisplaceSpectrum = oceanCs.FindKernel("CreateDisplaceSpectrum");
        m_kernelFFTHorizontal = oceanCs.FindKernel("FFTHorizontal");
        m_kernelFFTHorizontalEnd = oceanCs.FindKernel("FFTHorizontalEnd");
        m_kernelFFTVertical = oceanCs.FindKernel("FFTVertical");
        m_kernelFFTVerticalEnd = oceanCs.FindKernel("FFTVerticalEnd");
        m_kernelTextureGenerationDisplace = oceanCs.FindKernel("TextureGenerationDisplace");
        m_kernelTextureGenerationNormalBubbles = oceanCs.FindKernel("TextureGenerationNormalBubbles");

        //设置ComputerShader数据
        oceanCs.SetInt("N", m_fftSize);
        oceanCs.SetFloat("OceanLength", meshLength);


        //生成高斯随机数
        oceanCs.SetTexture(m_kernelComputeGaussianRandom, "GaussianRandomRT", m_gaussianRandomRT);
        oceanCs.Dispatch(m_kernelComputeGaussianRandom, m_fftSize / 8, m_fftSize / 8, 1);

    }
    /// <summary>
    /// 计算海洋数据
    /// </summary>
    private void ComputeOceanValue()
    {
        oceanCs.SetFloat("A", a);
        windAndSeed.z = Random.Range(1, 10f);
        windAndSeed.w = Random.Range(1, 10f);
        Vector2 wind = new Vector2(windAndSeed.x, windAndSeed.y);
        wind.Normalize();
        wind *= windScale;
        oceanCs.SetVector("WindAndSeed", new Vector4(wind.x, wind.y, windAndSeed.z, windAndSeed.w));
        oceanCs.SetFloat("Time", m_time);
        oceanCs.SetFloat("Lambda", lambda);
        oceanCs.SetFloat("HeightScale", heightScale);
        oceanCs.SetFloat("BubblesScale", bubblesScale);
        oceanCs.SetFloat("BubblesThreshold",bubblesThreshold);

        //生成高度频谱
        oceanCs.SetTexture(m_kernelCreateHeightSpectrum, "GaussianRandomRT", m_gaussianRandomRT);
        oceanCs.SetTexture(m_kernelCreateHeightSpectrum, "HeightSpectrumRT", m_heightSpectrumRT);
        oceanCs.Dispatch(m_kernelCreateHeightSpectrum, m_fftSize / 8, m_fftSize / 8, 1);

        //生成偏移频谱
        oceanCs.SetTexture(m_kernelCreateDisplaceSpectrum, "HeightSpectrumRT", m_heightSpectrumRT);
        oceanCs.SetTexture(m_kernelCreateDisplaceSpectrum, "DisplaceXSpectrumRT", m_displaceXSpectrumRT);
        oceanCs.SetTexture(m_kernelCreateDisplaceSpectrum, "DisplaceZSpectrumRT", m_displaceZSpectrumRT);
        oceanCs.Dispatch(m_kernelCreateDisplaceSpectrum, m_fftSize / 8, m_fftSize / 8, 1);


        if (controlM == 0)
        {
            SetMaterialTex();
            return;
        }

        //进行横向FFT
        for (int m = 1; m <= fftPow; m++)
        {
            int ns = (int)Mathf.Pow(2, m - 1);
            oceanCs.SetInt("Ns", ns);
            //最后一次进行特殊处理
            if (m != fftPow)
            {
                ComputeFFT(m_kernelFFTHorizontal, ref m_heightSpectrumRT);
                ComputeFFT(m_kernelFFTHorizontal, ref m_displaceXSpectrumRT);
                ComputeFFT(m_kernelFFTHorizontal, ref m_displaceZSpectrumRT);
            }
            else
            {
                ComputeFFT(m_kernelFFTHorizontalEnd, ref m_heightSpectrumRT);
                ComputeFFT(m_kernelFFTHorizontalEnd, ref m_displaceXSpectrumRT);
                ComputeFFT(m_kernelFFTHorizontalEnd, ref m_displaceZSpectrumRT);
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
            oceanCs.SetInt("Ns", ns);
            //最后一次进行特殊处理
            if (m != fftPow)
            {
                ComputeFFT(m_kernelFFTVertical, ref m_heightSpectrumRT);
                ComputeFFT(m_kernelFFTVertical, ref m_displaceXSpectrumRT);
                ComputeFFT(m_kernelFFTVertical, ref m_displaceZSpectrumRT);
            }
            else
            {
                ComputeFFT(m_kernelFFTVerticalEnd, ref m_heightSpectrumRT);
                ComputeFFT(m_kernelFFTVerticalEnd, ref m_displaceXSpectrumRT);
                ComputeFFT(m_kernelFFTVerticalEnd, ref m_displaceZSpectrumRT);
            }
            if (!isControlH && controlM == m)
            {
                SetMaterialTex();
                return;
            }
        }

        //计算纹理偏移
        oceanCs.SetTexture(m_kernelTextureGenerationDisplace, "HeightSpectrumRT", m_heightSpectrumRT);
        oceanCs.SetTexture(m_kernelTextureGenerationDisplace, "DisplaceXSpectrumRT", m_displaceXSpectrumRT);
        oceanCs.SetTexture(m_kernelTextureGenerationDisplace, "DisplaceZSpectrumRT", m_displaceZSpectrumRT);
        oceanCs.SetTexture(m_kernelTextureGenerationDisplace, "DisplaceRT", m_displaceRT);
        oceanCs.Dispatch(m_kernelTextureGenerationDisplace, m_fftSize / 8, m_fftSize / 8, 1);

        //生成法线和泡沫纹理
        oceanCs.SetTexture(m_kernelTextureGenerationNormalBubbles, "DisplaceRT", m_displaceRT);
        oceanCs.SetTexture(m_kernelTextureGenerationNormalBubbles, "NormalRT", m_normalRT);
        oceanCs.SetTexture(m_kernelTextureGenerationNormalBubbles, "BubblesRT", m_bubblesRT);
        oceanCs.Dispatch(m_kernelTextureGenerationNormalBubbles, m_fftSize / 8, m_fftSize / 8, 1);

        SetMaterialTex();
    }

    /// <summary>
    /// 创建网格
    /// </summary>
    private void CreateMesh()
    {
        //fftSize = (int)Mathf.Pow(2, FFTPow);
        m_vertIndexs = new int[(meshSize - 1) * (meshSize - 1) * 6];
        m_positions = new Vector3[meshSize * meshSize];
        m_uvs = new Vector2[meshSize * meshSize];

        int inx = 0;
        for (int i = 0; i < meshSize; i++)
        {
            for (int j = 0; j < meshSize; j++)
            {
                int index = i * meshSize + j;
                m_positions[index] = new Vector3((j - meshSize / 2.0f) * meshLength / meshSize, 0, (i - meshSize / 2.0f) * meshLength / meshSize);
                m_uvs[index] = new Vector2(j / (meshSize - 1.0f), i / (meshSize - 1.0f));

                if (i != meshSize - 1 && j != meshSize - 1)
                {
                    m_vertIndexs[inx++] = index;
                    m_vertIndexs[inx++] = index + meshSize;
                    m_vertIndexs[inx++] = index + meshSize + 1;

                    m_vertIndexs[inx++] = index;
                    m_vertIndexs[inx++] = index + meshSize + 1;
                    m_vertIndexs[inx++] = index + 1;
                }
            }
        }
        m_mesh.vertices = m_positions;
        m_mesh.SetIndices(m_vertIndexs, MeshTopology.Triangles, 0);
        m_mesh.uv = m_uvs;
    }

    //创建渲染纹理
    private RenderTexture CreateRT(int size)
    {
        RenderTexture rt = new RenderTexture(size, size, 0, RenderTextureFormat.ARGBFloat);
        rt.enableRandomWrite = true;
        rt.Create();
        return rt;
    }
    
    //计算fft
    private void ComputeFFT(int kernel, ref RenderTexture input)
    {
        oceanCs.SetTexture(kernel, "InputRT", input);
        oceanCs.SetTexture(kernel, "OutputRT", m_outputRT);
        oceanCs.Dispatch(kernel, m_fftSize / 8, m_fftSize / 8, 1);

        //交换输入输出纹理
        RenderTexture rt = input;
        input = m_outputRT;
        m_outputRT = rt;
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
