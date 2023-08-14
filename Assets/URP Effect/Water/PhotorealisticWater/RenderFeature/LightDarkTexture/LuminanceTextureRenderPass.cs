using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LuminanceTextureRenderPass : ScriptableRenderPass
{
    #region 渲染设置
    private RenderQueueType m_renderQueueType;
    private RenderPassEvent m_renderPassEvent;
    private FilteringSettings m_filteringSettings;
    private string m_commandBufferTag;
    private string m_profilerTag;
    private ProfilingSampler m_profilingSampler; //FrameDebugger标记
    List<ShaderTagId> m_shaderTagIdList = new List<ShaderTagId>();
    #endregion
    
    //------------------------------------------------------
    // 变量
    //------------------------------------------------------
    
    private int m_iterations;       //模糊迭代次数
    private float m_blurRadius;    //模糊范围
    private int m_downSample;     //降采样
    private float m_luminanceThreshold; //亮度阈值
    private float m_lightDarkIntensity; //Bloom强度
    private Material m_waterMaterial;   //水材质
    
    private Material m_blitMaterial;
    private RTHandle m_cameraColorRT;
    private RTHandle m_tempRT0;
    private RTHandle m_tempRT1;
    private RenderTextureDescriptor m_rtDescriptor;
    
    private static readonly int s_BlurOffset = Shader.PropertyToID("_BlurOffset");
    private static readonly int s_LuminanceThreshold = Shader.PropertyToID("_LuminanceThreshold");
    private static readonly int s_LightDarkIntensity = Shader.PropertyToID("_LightDarkIntensity");
    private static readonly int s_LightDarkTexture = Shader.PropertyToID("_LightDarkTexture");
    
    //------------------------------------------------------
    // 构造函数
    //------------------------------------------------------
    public LuminanceTextureRenderPass(string commandBufferTag, string profilerTag,RenderPassEvent renderPassEvent,string[] shaderTags,RenderQueueType renderQueueType, int layerMask, Material blitMaterial)
    {
        #region 渲染设置相关参数
        base.profilingSampler = new ProfilingSampler(nameof(LuminanceTextureRenderPass));
        m_commandBufferTag = commandBufferTag;
        m_profilerTag = profilerTag;
        m_profilingSampler = new ProfilingSampler(profilerTag);
        this.renderPassEvent = renderPassEvent; 
        m_renderQueueType = renderQueueType;
        RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
            ? RenderQueueRange.transparent
            : RenderQueueRange.opaque;
        m_filteringSettings = new FilteringSettings(renderQueueRange, layerMask);
        if (shaderTags != null && shaderTags.Length > 0)
        {
            foreach (var passName in shaderTags)
                m_shaderTagIdList.Add(new ShaderTagId(passName));
        }
        else
        {
            m_shaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
            m_shaderTagIdList.Add(new ShaderTagId("UniversalForward"));
            m_shaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));
        }
        #endregion
        
        //Blit材质
        m_blitMaterial = blitMaterial;
    }
    
    //------------------------------------------------------
    // //设置RenderPass参数
    //------------------------------------------------------
    public void SetRenderPass(RTHandle cameraColorTargetHandle, int iterations, float blurRadius, int downSample, float luminanceThreshold, float lightDarkIntensity, Material waterMaterial)
    {
        m_cameraColorRT = cameraColorTargetHandle;
        m_iterations = iterations;
        m_blurRadius = blurRadius;
        m_downSample = downSample;
        m_luminanceThreshold = luminanceThreshold;
        m_lightDarkIntensity = lightDarkIntensity;
        m_waterMaterial = waterMaterial;
    }
   
    
    //------------------------------------------------------
    // 在渲染相机之前调用
    // 1.配置 Render Target 和它们的 Clear State
    // 2.创建临时渲染目标纹理。
    // 3.不要调用 CommandBuffer.SetRenderTarget. 而应该是 ConfigureTarget 和 ConfigureClear）
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
        ConfigureTarget(m_cameraColorRT);
        //清除颜色
        //ConfigureClear(ClearFlag.All, Color.clear);
    }

    //------------------------------------------------------
    // 每帧执行渲染逻辑
    //------------------------------------------------------
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        #region sortingCriteria|drawingSettings
        //排序设置
        SortingCriteria sortingCriteria = (m_renderQueueType == RenderQueueType.Transparent)
            ? SortingCriteria.CommonTransparent
            : renderingData.cameraData.defaultOpaqueSortFlags;
        //设置渲染的Shader Pass和渲染排序
        DrawingSettings drawingSettings = CreateDrawingSettings(m_shaderTagIdList, ref renderingData, sortingCriteria);
        
        
        #endregion
        
        if (m_blitMaterial == null)
            return;
        
        //设置模糊半径
        m_blitMaterial.SetFloat(s_BlurOffset, m_blurRadius);
        //设置亮度阈值
        m_blitMaterial.SetFloat(s_LuminanceThreshold, m_luminanceThreshold);
        //设置Bloom强度
        m_blitMaterial.SetFloat(s_LightDarkIntensity, m_lightDarkIntensity);
        //降采样
        m_rtDescriptor.width /= m_downSample; 
        m_rtDescriptor.height /= m_downSample;
        
        //获取新的命令缓冲区并为其指定一个名称
        CommandBuffer cmd = CommandBufferPool.Get(m_commandBufferTag);
        
        //ProfilingScope
        using (new ProfilingScope(cmd, m_profilingSampler))
        {
            Render(cmd);
        }
        //执行命令缓冲区中的命令
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        
        //绘制对象
        context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_filteringSettings);
        
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
        
        Blitter.BlitCameraTexture(cmd,m_cameraColorRT,m_tempRT0,m_blitMaterial,0);
        
        for (int i = 0; i < m_iterations; i++)
        {
            //2.高斯模糊对应第二个和第三个Pass，模糊后的较亮区域存在m_TempRT0
            //第一轮 RT0 -> RT1
            //创建临时RT1
            RenderingUtils.ReAllocateIfNeeded(ref m_tempRT1, m_rtDescriptor,FilterMode.Bilinear);
            Blitter.BlitCameraTexture(cmd, m_tempRT0, m_tempRT1, m_blitMaterial, 1);
            m_tempRT0?.Release();
            //第二轮 RT1 -> RT0
            //创建临时RT0
            RenderingUtils.ReAllocateIfNeeded(ref m_tempRT0, m_rtDescriptor,FilterMode.Bilinear);
            Blitter.BlitCameraTexture(cmd, m_tempRT1, m_tempRT0, m_blitMaterial, 2);
            m_tempRT1?.Release();
        }
        // 3.将完成高斯模糊后的结果传递给材质中的_Bloom纹理属性
        //cmd.SetGlobalTexture(s_LightDarkTexture, m_tempRT0.rt);
        m_waterMaterial.SetTexture(s_LightDarkTexture, m_tempRT0.rt);
        // 4.最后调用第四个pass， 将明暗度贴图输出到屏幕(测试用)
        // Blitter.BlitCameraTexture(cmd, m_tempRT0, m_cameraColorRT, m_blitMaterial, 3);
        // m_tempRT0?.Release();
    }

    
    //------------------------------------------------------
    // 渲染后，相机堆栈中的所有相机每帧都会调用
    // 释放创建的资源（如果在多个帧中不需要这些资源）
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