using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ABufferMotionBlurRenderPass : ScriptableRenderPass
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
    private float m_blurTrain; //模糊拖尾

    private Material m_blitMaterial;
    private RTHandle m_cameraRT;
    private RTHandle m_accumulationRT;
    private RenderTextureDescriptor m_rtDescriptor;
    private static readonly int s_BlurTrain = Shader.PropertyToID("_BlurTrain");

    //------------------------------------------------------
    // 构造函数
    //------------------------------------------------------
    public ABufferMotionBlurRenderPass(string commandBufferTag, string profilerTag, RenderPassEvent renderPassEvent,
        string[] shaderTags, RenderQueueType renderQueueType, int layerMask, Material blitMaterial)
    {
        #region 渲染设置相关参数

        base.profilingSampler = new ProfilingSampler(nameof(ABufferMotionBlurRenderPass));
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
    public void SetRenderPass(RTHandle colorHandle, float blurTrain)
    {
        m_cameraRT = colorHandle;
        m_blurTrain = blurTrain;
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

        //设置模糊拖尾
        m_blitMaterial.SetFloat(s_BlurTrain, m_blurTrain);

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
        RenderingUtils.ReAllocateIfNeeded(ref m_accumulationRT, m_rtDescriptor, FilterMode.Bilinear);
        Blitter.BlitCameraTexture(cmd, m_cameraRT, m_accumulationRT, m_blitMaterial, 0);
        Blitter.BlitCameraTexture(cmd, m_cameraRT, m_accumulationRT, m_blitMaterial, 1);
        Blitter.BlitCameraTexture(cmd, m_accumulationRT, m_cameraRT);
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