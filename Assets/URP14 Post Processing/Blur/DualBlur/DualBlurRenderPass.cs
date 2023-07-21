using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DualBlurRenderPass : ScriptableRenderPass
{
    //------------------------------------------------------
    // 变量
    //------------------------------------------------------
    
    private int m_Iterations; //模糊迭代次数
    private float m_BlurRadius;    //模糊范围
    private int m_DownSample;     //降采样
    
    private Material m_BlitMaterial;
    private RTHandle m_CameraRT;
    private RTHandle m_TempRT0;
    private RTHandle m_TempRT1;
    private RenderTextureDescriptor m_RTDescriptor;
    
    //FrameDebugger标记
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler("DualBlur Pass"); 
    
    //------------------------------------------------------
    // 构造函数
    //------------------------------------------------------
    public DualBlurRenderPass(Material blitMaterial)
    {
        m_BlitMaterial = blitMaterial;
    }
    
    //------------------------------------------------------
    // //设置RenderPass参数
    //------------------------------------------------------
    public void SetRenderPass(RTHandle colorHandle, int iterations, float blurRadius, int downSample)
    {
        m_CameraRT = colorHandle;
        m_Iterations = iterations;
        m_BlurRadius = blurRadius;
        m_DownSample = downSample;
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
        m_BlitMaterial.SetFloat("_BlurOffset", m_BlurRadius);
        
        //降采样
        m_RTDescriptor.width /= m_DownSample; 
        m_RTDescriptor.height /= m_DownSample;
        
        //获取新的命令缓冲区并为其指定一个名称
        CommandBuffer cmd = CommandBufferPool.Get("L Post Processing");
            
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
        //创建临时RT0
        RenderingUtils.ReAllocateIfNeeded(ref m_TempRT0, m_RTDescriptor);
        Blitter.BlitCameraTexture(cmd, m_CameraRT, m_TempRT0);

        //DowmSample
        for (int i = 0; i < m_Iterations; i++)
        {
            //创建临时RT1
            RenderingUtils.ReAllocateIfNeeded(ref m_TempRT1, m_RTDescriptor);
            Blitter.BlitCameraTexture(cmd, m_TempRT0, m_TempRT1, m_BlitMaterial, 0);
            CoreUtils.Swap(ref m_TempRT0, ref m_TempRT1);
            m_TempRT1?.rt.Release();
            //Debug.Log(m_RTDescriptor.width+", "+m_RTDescriptor.height);
            
            if(i==m_Iterations-1)
                break;
            
            //每次循环降低RT的分辨率
            m_RTDescriptor.width /= 2;
            m_RTDescriptor.height /= 2;
        }


        //UpSample
        for (int i = 0; i < m_Iterations; i++)
        {
            //创建临时RT1
            RenderingUtils.ReAllocateIfNeeded(ref m_TempRT1, m_RTDescriptor);
            Blitter.BlitCameraTexture(cmd, m_TempRT0, m_TempRT1, m_BlitMaterial, 1);
            CoreUtils.Swap(ref m_TempRT0, ref m_TempRT1);
            m_TempRT1?.rt.Release();
            
            //Debug.Log(m_RTDescriptor.width+", "+m_RTDescriptor.height);
           
            if(i==m_Iterations-1)
                break;
            
            //每次循环降低RT的分辨率
            m_RTDescriptor.width *= 2;
            m_RTDescriptor.height *= 2;
        }
        
        //最后 RT0 -> destination
        Blitter.BlitCameraTexture(cmd, m_TempRT0, m_CameraRT);
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