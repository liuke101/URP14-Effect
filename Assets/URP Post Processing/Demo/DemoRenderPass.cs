using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DemoRenderPass : ScriptableRenderPass
{
    //------------------------------------------------------
    // 变量
    //------------------------------------------------------
    private RTHandle m_CameraRT;
    private Material m_BlitMaterial;
    private float m_Intensity;
    
    //CPU和GPU分析采样器的包装器。将此与ProfileScope一起使用可以评测一段代码。
    //标记Profiling后，可在FrameDebugger中直接查看标记Profiling的对象
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler("DemoRenderPass");
    
    //------------------------------------------------------
    // 构造函数
    //------------------------------------------------------
    public DemoRenderPass(Material blitMaterial)
    {
        m_BlitMaterial = blitMaterial;
    }
    
    //------------------------------------------------------
    // //设置RenderPass参数
    //------------------------------------------------------
    public void SetRenderPass(RTHandle colorHandle, float intensity)
    {
        m_CameraRT = colorHandle;
        m_Intensity = intensity;
    }
    
    //------------------------------------------------------
    // 在渲染相机之前调用
    // 1.配置 Render Target 和它们的 Clear State
    // 2.创建临时渲染目标纹理。
    // 3.不要调用 CommandBuffer.SetRenderTarget. 而应该是 ConfigureTarget 和 ConfigureClear`）
    //------------------------------------------------------
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
       
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
        m_BlitMaterial.SetFloat("_Intensity", m_Intensity);
        Blit(cmd, m_CameraRT, m_CameraRT, m_BlitMaterial, 0);
    }

    //------------------------------------------------------
    // 相机堆栈中的所有相机都会调用
    // 释放创建的资源
    //------------------------------------------------------
    public override void OnCameraCleanup(CommandBuffer cmd)
    {
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