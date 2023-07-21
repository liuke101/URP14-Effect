using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GaussianBloomRenderPass : ScriptableRenderPass
{
    //------------------------------------------------------
    // 变量
    //------------------------------------------------------
    
    private int m_Iterations;       //模糊迭代次数
    private float m_BloomRadius;    //模糊范围
    private int m_DownSample;       //降采样
    private float m_LuminanceThreshold; //亮度阈值
    private float m_BloomIntensity; //Bloom强度
    
    private Material m_BlitMaterial;
    private RTHandle m_CameraRT;
    private RTHandle m_TempRT0;
    private RTHandle m_TempRT1;
    private RenderTextureDescriptor m_RTDescriptor;
    
    private static readonly int SceneColor = Shader.PropertyToID("_SceneColor");
    private static readonly int BlurOffset = Shader.PropertyToID("_BlurOffset");
    private static readonly int LuminanceThreshold = Shader.PropertyToID("_LuminanceThreshold");
    private static readonly int BloomIntensity = Shader.PropertyToID("_BloomIntensity");
    private static readonly int BloomTexture = Shader.PropertyToID("_BloomTexture");
    
    //FrameDebugger标记
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler("GaussianBloom Pass");
    


    //------------------------------------------------------
    // 构造函数
    //------------------------------------------------------
    public GaussianBloomRenderPass(Material blitMaterial)
    {
        m_BlitMaterial = blitMaterial;
    }
    
    //------------------------------------------------------
    // //设置RenderPass参数
    //------------------------------------------------------
    public void SetRenderPass(RTHandle colorHandle, int iterations, float blurRadius, int downSample, float luminanceThreshold, float bloomIntensity)
    {
        m_CameraRT = colorHandle;
        m_Iterations = iterations;
        m_BloomRadius = blurRadius;
        m_DownSample = downSample;
        m_LuminanceThreshold = luminanceThreshold;
        m_BloomIntensity = bloomIntensity;
    }
    
    //------------------------------------------------------
    // 在渲染相机之前调用
    // 1.配置 Render Target 和它们的 Clear State
    // 2.创建临时渲染目标纹理。
    // 3.不要调用 CommandBuffer.SetRenderTarget. 而应该是 ConfigureTarget 和 ConfigureClear`）
    //------------------------------------------------------
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        //获取RTDescriptor，描述RT的信息
        m_RTDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_RTDescriptor.depthBufferBits = 0; //必须声明！Color and depth cannot be combined in RTHandles
    }
    
    //------------------------------------------------------
    // 在执行RenderPass之前调用，功能同OnCameraSetup
    //------------------------------------------------------
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //相机RT
        ConfigureTarget(m_CameraRT);
        //清除颜色
        //ConfigureClear(ClearFlag.All, Color.clear);
    }

    //------------------------------------------------------
    // 每帧执行渲染逻辑
    //------------------------------------------------------
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (m_BlitMaterial == null)
            return;
        //设置模糊半径
        m_BlitMaterial.SetFloat(BlurOffset, m_BloomRadius);
        //设置亮度阈值
        m_BlitMaterial.SetFloat(LuminanceThreshold, m_LuminanceThreshold);
        //设置Bloom强度
        m_BlitMaterial.SetFloat(BloomIntensity, m_BloomIntensity);
        //降采样
        m_RTDescriptor.width /= m_DownSample; 
        m_RTDescriptor.height /= m_DownSample;

        //获取新的命令缓冲区并为其指定一个名称
        CommandBuffer cmd = CommandBufferPool.Get("URP Post Processing");
            
        //ProfilingScope
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            Render(cmd);
        }
        
        //执行命令缓冲区中的命令
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        //释放命令缓冲区
        CommandBufferPool.Release(cmd);
    }

    //------------------------------------------------------
    // 渲染逻辑
    //------------------------------------------------------
    private void Render(CommandBuffer cmd)
    {
        //1.用第一个pass提取较亮的区域
        RenderingUtils.ReAllocateIfNeeded(ref m_TempRT0, m_RTDescriptor,FilterMode.Bilinear);
        
        
        Blitter.BlitCameraTexture(cmd,m_CameraRT,m_TempRT0,m_BlitMaterial,0);
        
        //保存场景原图
        m_BlitMaterial.SetTexture(SceneColor, m_CameraRT.rt);
        
        for (int i = 0; i < m_Iterations; i++)
        {
            //2.高斯模糊对应第二个和第三个Pass，模糊后的较亮区域存在m_TempRT0
            //第一轮 RT0 -> RT1
            //创建临时RT1
            RenderingUtils.ReAllocateIfNeeded(ref m_TempRT1, m_RTDescriptor,FilterMode.Bilinear);
            Blitter.BlitCameraTexture(cmd, m_TempRT0, m_TempRT1, m_BlitMaterial, 1);
            m_TempRT0?.rt.Release();
            //第二轮 RT1 -> RT0
            //创建临时RT0
            RenderingUtils.ReAllocateIfNeeded(ref m_TempRT0, m_RTDescriptor,FilterMode.Bilinear);
            Blitter.BlitCameraTexture(cmd, m_TempRT1, m_TempRT0, m_BlitMaterial, 2);
            m_TempRT1?.rt.Release();
        }
        // 3.将完成高斯模糊后的结果传递给材质中的_Bloom纹理属性
        m_BlitMaterial.SetTexture(BloomTexture, m_TempRT0.rt);
        
        // 4.最后调用第四个pass， RT0 -> destination
        Blitter.BlitCameraTexture(cmd, m_TempRT0, m_CameraRT, m_BlitMaterial, 3);
        m_TempRT0?.rt.Release();
    }
    
    //------------------------------------------------------
    // 相机堆栈中的所有相机都会调用
    // 释放创建的资源
    //------------------------------------------------------
    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        base.OnCameraCleanup(cmd);
    }
    
    //------------------------------------------------------
    // 渲染完相机堆栈中的最后一个相机后调用一次
    // 释放创建的资源
    //------------------------------------------------------
    public override void OnFinishCameraStackRendering(CommandBuffer cmd)
    {
        base.OnFinishCameraStackRendering(cmd);
    }
}