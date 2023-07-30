using Unity.Properties;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class DepthNormalTextureOutlineRenderFeature : ScriptableRendererFeature
{
    /// <summary>
    /// 渲染参数
    /// </summary>
    [System.Serializable]
    public class RenderParameters
    {
        [Range(0, 1)]
        public float edgesOnly = 0.0f; //边缘线强度,0为边缘线叠加到原图像，1为只显示边缘线
        public Color edgeColor = Color.black; //描边颜色
        public Color backgroundColor = Color.white; //背景颜色
        
        public float sampleDistance = 1.0f; //采样距离,越大描边越粗
        
        //当邻域的深度值或法线相差多少时，被认为是边界
        public float sensitivityDepth = 1.0f; //深度敏感度
        public float sensitivityNormals = 1.0f; //法线敏感度
    }

    private DepthNormalTextureOutlineRenderPass m_renderPass; //RenderPass
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
        public string profilerTag = "DepthNormalTextureOutlinePass";

        //插入位置
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        
        //配置输入
        public ScriptableRenderPassInput renderPassInput = ScriptableRenderPassInput.Color|ScriptableRenderPassInput.Normal;

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
        //this.name = "DepthNormalTextureOutlineRF";

        FilterSettings filter = settings.filterSettings;

        //shader创建材质
        m_blitMaterial = CoreUtils.CreateEngineMaterial(blitShader);

        //创建RenderPass
        m_renderPass = new DepthNormalTextureOutlineRenderPass(settings.commandBufferTag, settings.profilerTag, settings.renderPassEvent,
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
            m_renderPass.SetRenderPass(renderer.cameraColorTargetHandle, parameters.edgesOnly, parameters.edgeColor,
                parameters.backgroundColor, parameters.sampleDistance, parameters.sensitivityDepth,parameters.sensitivityNormals);

            // 配置RenderPass
            // 使用ScriptableRenderPassInput.Color参数调用ConfigureInput
            // 确保不透明纹理可用于渲染过程
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
        base.Dispose(disposing);
        CoreUtils.Destroy(m_blitMaterial);
    }
}