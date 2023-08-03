using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ConfigureInputRenderFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;
    public ScriptableRenderPassInput renderPassInput =
        ScriptableRenderPassInput.Color | ScriptableRenderPassInput.Depth| ScriptableRenderPassInput.Normal;
    
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();

        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }
    
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        // RenderPass配置输入
        // Color: CopyColor & _CameraOpaqueTexture
        // Depth: DepthPrePass & _CameraDepthTexture
        // Normal: DepthNormalPrePass & _CameraDepthNormalsTexture
        // Motion: MotionVectors & _CameraMotionVectorsTexture
        m_ScriptablePass.ConfigureInput(renderPassInput);
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    
}


