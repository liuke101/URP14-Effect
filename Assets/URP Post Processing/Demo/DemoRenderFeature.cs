using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class DemoRenderFeature : ScriptableRendererFeature
{
    //------------------------------------------------------
    // 变量
    //------------------------------------------------------
    public Shader blitShader;
    [Range (0,1)]
    public float intensity; //颜色强度
    
    private Material m_BlitMaterial;
    private DemoRenderPass m_RenderPass = null;
    public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    //------------------------------------------------------
    //Unity 对以下事件调用此方法：
    //首次加载 RF 时：OnEnable()
    //在 RF 的 Inspector 中更改属性时:OnValidate()
    //启用或禁用 RF 时:OnValidate()
    //------------------------------------------------------
    public override void Create()
    {
        this.name = "ColorBlit";
        
        //shader创建材质
        m_BlitMaterial = CoreUtils.CreateEngineMaterial(blitShader);

        //创建RenderPass
        m_RenderPass = new DemoRenderPass(m_BlitMaterial);
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
            m_RenderPass.SetRenderPass(renderer.cameraColorTargetHandle, intensity);

            // 配置RenderPass
            // 使用ScriptableRenderPassInpu.Color参数调用ConfigureInput
            // 确保不透明纹理可用于渲染过程
            m_RenderPass.ConfigureInput(ScriptableRenderPassInput.Color);
            m_RenderPass.renderPassEvent = renderPassEvent; //插入位置
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
            renderer.EnqueuePass(m_RenderPass);
        }
    }

    //------------------------------------------------------
    // 释放资源
    //------------------------------------------------------
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(m_BlitMaterial);
    }
}