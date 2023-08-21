using Unity.Properties;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class CustomRenderFeature : ScriptableRendererFeature
{
    /// <summary>
    /// 渲染参数
    /// </summary>
    [System.Serializable]
    public class RenderParameters
    {
        [Range(0, 10)] public int iterations = 1; //模糊迭代次数
        [Range(0.0f, 5.0f)] public float blurRadius = 0.0f; //模糊范围
        [Range(1, 8)] public int downSample = 2; //降采样
    }

    private CustomRenderPass m_renderPass; //RenderPass
    public RenderParameters parameters = new RenderParameters();
    public Shader blitShader; //手动在RF的Inspector界面设置shader
    private Material m_blitMaterial;
    public RenderSettings settings = new RenderSettings();

    //------------------------------------------
    /// <summary>
    /// 渲染设置
    /// </summary>
    [System.Serializable]
    public class RenderSettings
    {
        //CommandBuffer标签名
        public string commandBufferTag = "URP Post Processing";

        //profiler标签名
        public string profilerTag = "Custom Pass";

        //插入位置
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        
        //配置输入
        public ScriptableRenderPassInput renderPassInput = ScriptableRenderPassInput.Color | ScriptableRenderPassInput.Depth;
        
        //过滤设置
        public FilterSettings filterSettings = new FilterSettings();
    }


    /// <summary>
    /// 过滤设置
    /// </summary>
    [System.Serializable]
    public class FilterSettings
    {
        //构造函数
        public FilterSettings()
        {
            renderQueueType = RenderQueueType.Opaque;
            layerMask = 0;
        }

        public RenderQueueType renderQueueType;
        public LayerMask layerMask;
        public string[] lightModeTags;
    }

    //------------------------------------------------------
    //Unity 对以下事件调用此方法：
    //首次加载 RF 时：OnEnable()
    //在 RF 的 Inspector 中更改属性时:OnValidate()
    //启用或禁用 RF 时:OnValidate()
    //------------------------------------------------------
    public override void Create()
    {
        //该RenderFeature在Inspector面板显示的名字
        //this.name = "CustomRF";

        FilterSettings filter = settings.filterSettings;

        //shader创建材质
        m_blitMaterial = CoreUtils.CreateEngineMaterial(blitShader);

        //创建RenderPass
        m_renderPass = new CustomRenderPass(settings.commandBufferTag, settings.profilerTag, settings.renderPassEvent,
            filter.lightModeTags, filter.renderQueueType, filter.layerMask, m_blitMaterial);
    }

    //------------------------------------------------------
    //相机裁剪之前调用此方法
    //------------------------------------------------------
    public override void OnCameraPreCull(ScriptableRenderer renderer, in CameraData cameraData)
    {
        base.OnCameraPreCull(renderer, in cameraData);
    }

    //------------------------------------------------------
    //渲染目标初始化后调用，设置RenderPass（要先创建RenderPass）
    //------------------------------------------------------
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        //当前渲染的相机需要开启后处理
        if (renderingData.cameraData.postProcessEnabled && renderingData.cameraData.cameraType == CameraType.Game)
        {
            //设置RenderPass参数
            m_renderPass.SetRenderPass(renderer.cameraColorTargetHandle, parameters.iterations, parameters.blurRadius,
                parameters.downSample);

            // RenderPass配置输入
            // Color: CopyColor & _CameraOpaqueTexture
            // Depth: DepthPrePass & _CameraDepthTexture
            // Normal: DepthNormalPrePass & _CameraDepthNormalsTexture
            // Motion: MotionVectors & _CameraMotionVectorsTexture
            m_renderPass.ConfigureInput(settings.renderPassInput);
        }
    }

    //------------------------------------------------------
    // 插入Render Pass
    //------------------------------------------------------
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //当前渲染的相机需要开启后处理
        if (renderingData.cameraData.postProcessEnabled && renderingData.cameraData.cameraType == CameraType.Game)
        {
            //入队渲染队列
            renderer.EnqueuePass(m_renderPass);
        }
    }

    //------------------------------------------------------
    // 释放资源
    //------------------------------------------------------
    protected override void Dispose(bool disposing)
    {
        m_renderPass?.Dispose();
        m_renderPass = null;
        CoreUtils.Destroy(m_blitMaterial);
    }
}