using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BoxBlurRenderPass : ScriptableRenderPass
{
    //------------------------------------------------------
    // 变量
    //------------------------------------------------------
    
    private int m_iterations; //模糊迭代次数
    private float m_blurRadius;    //模糊范围
    private int m_downSample;     //降采样
    
    private Material m_blitMaterial;
    private RTHandle m_cameraRT;
    private RTHandle m_tempRT0;
    private RTHandle m_tempRT1;
    private RenderTextureDescriptor m_rtDescriptor;
    
    //FrameDebugger标记
    ProfilingSampler m_profilingSampler = new ProfilingSampler("BoxBlur Pass");
    
    private static readonly int s_BlurOffset = Shader.PropertyToID("_BlurOffset");

    //------------------------------------------------------
    // 构造函数
    //------------------------------------------------------
    public BoxBlurRenderPass(Material blitMaterial)
    {
        m_blitMaterial = blitMaterial;
    }
    
    //------------------------------------------------------
    // //设置RenderPass参数
    //------------------------------------------------------
    public void SetRenderPass(RTHandle colorHandle, int iterations, float blurRadius, int downSample)
    {
        m_cameraRT = colorHandle;
        m_iterations = iterations;
        m_blurRadius = blurRadius;
        m_downSample = downSample;
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
        m_rtDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        m_rtDescriptor.depthBufferBits = 0; //必须声明！Color and depth cannot be combined in RTHandles
    }
    
    //------------------------------------------------------
    // 在执行RenderPass之前调用，功能同OnCameraSetup
    //------------------------------------------------------
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        //相机RT
        ConfigureTarget(m_cameraRT);
        //清除颜色
        //ConfigureClear(ClearFlag.All, Color.clear);
    }

    //------------------------------------------------------
    // 每帧执行渲染逻辑
    //------------------------------------------------------
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (m_blitMaterial == null)
            return;
        
        //设置模糊半径
        m_blitMaterial.SetFloat(s_BlurOffset, m_blurRadius);
        
        //降采样
        m_rtDescriptor.width /= m_downSample; 
        m_rtDescriptor.height /= m_downSample;
        
        //获取新的命令缓冲区并为其指定一个名称
        CommandBuffer cmd = CommandBufferPool.Get("URP Post Processing");
            
        //ProfilingScope
        using (new ProfilingScope(cmd, m_profilingSampler))
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
        //创建临时RT0
        RenderingUtils.ReAllocateIfNeeded(ref m_tempRT0, m_rtDescriptor, FilterMode.Bilinear);
        Blitter.BlitCameraTexture(cmd, m_cameraRT, m_tempRT0);
        for (int i = 0; i < m_iterations; i++)
        {
            //第一轮 RT0 -> RT1
            //创建临时RT1
            RenderingUtils.ReAllocateIfNeeded(ref m_tempRT1, m_rtDescriptor, FilterMode.Bilinear);
            Blitter.BlitCameraTexture(cmd, m_tempRT0, m_tempRT1, m_blitMaterial, 0);
            m_tempRT0?.Release();
            //第二轮 RT1 -> RT0
            //创建临时RT0
            RenderingUtils.ReAllocateIfNeeded(ref m_tempRT0, m_rtDescriptor, FilterMode.Bilinear);
            Blitter.BlitCameraTexture(cmd, m_tempRT1, m_tempRT0, m_blitMaterial, 1);
            m_tempRT1?.Release();
        }
        
        //最后 RT0 -> destination
        Blitter.BlitCameraTexture(cmd, m_tempRT0, m_cameraRT, m_blitMaterial, 1);
        m_tempRT0?.Release();
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