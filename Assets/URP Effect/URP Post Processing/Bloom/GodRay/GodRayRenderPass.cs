using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GodRayRenderPass : ScriptableRenderPass
{
    //------------------------------------------------------
    // 变量
    //------------------------------------------------------
    
    private int m_iterations;       //模糊迭代次数
    private float m_bloomRadius;    //模糊范围
    private int m_downSample;       //降采样
    private float m_luminanceThreshold; //亮度阈值
    private float m_bloomIntensity; //Bloom强度
    private Vector2 m_radialCenter; //径向轴心
    private int m_radialOffsetIterations; //径向偏移迭代次数
    
    private Material m_blitMaterial;
    private RTHandle m_cameraRT;
    private RTHandle m_tempRT0;
    private RTHandle m_tempRT1;
    private RenderTextureDescriptor m_rtDescriptor;
    
    private static readonly int s_SceneColor = Shader.PropertyToID("_SceneColor");
    private static readonly int s_BlurOffset = Shader.PropertyToID("_BlurOffset");
    private static readonly int s_LuminanceThreshold = Shader.PropertyToID("_LuminanceThreshold");
    private static readonly int s_BloomIntensity = Shader.PropertyToID("_BloomIntensity");
    private static readonly int s_BloomTexture = Shader.PropertyToID("_BloomTexture");
    private static readonly int s_RadialCenter = Shader.PropertyToID("_RadialCenter");
    private static readonly int s_RadialOffsetIterations = Shader.PropertyToID("_RadialOffsetIterations");
    
    //FrameDebugger标记
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler("GodRay Pass");

    //------------------------------------------------------
    // 构造函数
    //------------------------------------------------------
    public GodRayRenderPass(Material blitMaterial)
    {
        m_blitMaterial = blitMaterial;
    }
    
    //------------------------------------------------------
    // //设置RenderPass参数
    //------------------------------------------------------
    public void SetRenderPass(RTHandle colorHandle, int iterations, float blurRadius, int downSample, float luminanceThreshold, float bloomIntensity, Vector2 radialCenter, int radialOffsetIterations)
    {
        m_cameraRT = colorHandle;
        m_iterations = iterations;
        m_bloomRadius = blurRadius;
        m_downSample = downSample;
        m_luminanceThreshold = luminanceThreshold;
        m_bloomIntensity = bloomIntensity;
        m_radialCenter = radialCenter;
        m_radialOffsetIterations = radialOffsetIterations;
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
        m_blitMaterial.SetFloat(s_BlurOffset, m_bloomRadius);
        //设置亮度阈值
        m_blitMaterial.SetFloat(s_LuminanceThreshold, m_luminanceThreshold);
        //设置Bloom强度
        m_blitMaterial.SetFloat(s_BloomIntensity, m_bloomIntensity);
        //设置径向轴心
        m_blitMaterial.SetVector(s_RadialCenter, m_radialCenter);
        //设置径向偏移迭代次数
        m_blitMaterial.SetInt(s_RadialOffsetIterations, m_radialOffsetIterations);
        
        //降采样
        m_rtDescriptor.width /= m_downSample; 
        m_rtDescriptor.height /= m_downSample;

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
        RenderingUtils.ReAllocateIfNeeded(ref m_tempRT0, m_rtDescriptor,FilterMode.Bilinear);
        
        
        Blitter.BlitCameraTexture(cmd,m_cameraRT,m_tempRT0,m_blitMaterial,0);
        
        //保存场景原图
        m_blitMaterial.SetTexture(s_SceneColor, m_cameraRT.rt);
        
        for (int i = 0; i < m_iterations; i++)
        {
            //2.径向模糊对应第二个Pass，模糊后的较亮区域存在m_TempRT0
            //创建临时RT1
            RenderingUtils.ReAllocateIfNeeded(ref m_tempRT1, m_rtDescriptor, FilterMode.Bilinear);
            Blitter.BlitCameraTexture(cmd, m_tempRT0, m_tempRT1, m_blitMaterial, 1);
            CoreUtils.Swap(ref m_tempRT0, ref m_tempRT1);
            m_tempRT1?.Release();
        }
        // 3.将完成模糊后的结果传递给材质中的_Bloom纹理属性
        m_blitMaterial.SetTexture(s_BloomTexture, m_tempRT0.rt);
        
        // 4.最后调用第三个pass， RT0 -> destination
        Blitter.BlitCameraTexture(cmd, m_tempRT0, m_cameraRT, m_blitMaterial, 2);
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