using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class ConfigureInputRenderFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        private RTHandle m_cameraColorRT;
        private RTHandle m_tempRT0;
        private RenderTextureDescriptor m_rtDescriptor;
        private ProfilingSampler m_profilingSampler = new ProfilingSampler("Configure Input");
        private string m_grabTextureName;
        private bool m_isGrab;
        
        //------------------------------------------------------
        // //设置RenderPass参数
        //------------------------------------------------------
        public void SetRenderPass(RTHandle cameraColorTargetHandle,string grabTextureName,bool isGrab)
        {
            m_cameraColorRT = cameraColorTargetHandle;
            m_grabTextureName = grabTextureName;
            m_isGrab = isGrab;
        }
        
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //获取RTDescriptor，描述RT的信息
            m_rtDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_rtDescriptor.depthBufferBits = 0; //必须声明！Color and depth cannot be combined in RTHandles
        }
        
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            //相机RT
            ConfigureTarget(m_cameraColorRT);
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            //获取新的命令缓冲区并为其指定一个名称
            CommandBuffer cmd = CommandBufferPool.Get("URP Configure Input");
            
            //ProfilingScope
            using (new ProfilingScope(cmd, m_profilingSampler))
            {
                if (m_isGrab)
                {
                    RenderingUtils.ReAllocateIfNeeded(ref m_tempRT0, m_rtDescriptor);
                    Blitter.BlitCameraTexture(cmd, m_cameraColorRT, m_tempRT0);
                    cmd.SetGlobalTexture(m_grabTextureName, m_tempRT0);
                    Blitter.BlitCameraTexture(cmd, m_tempRT0, m_cameraColorRT);
                }
            }
        
            //执行命令缓冲区中的命令
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            //释放命令缓冲区
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            m_tempRT0?.Release();
        }
    }

    public bool grabFullScreenTexture = false;
    public string  grabFullScreenTextureName = "_GrabFullScreenTexture";
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    private CustomRenderPass m_scriptablePass;
    public ScriptableRenderPassInput renderPassInput  = ScriptableRenderPassInput.Color | ScriptableRenderPassInput.Depth| ScriptableRenderPassInput.Normal;
    
        
    public override void Create()
    {
        m_scriptablePass = new CustomRenderPass();
    }
    
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (renderingData.cameraData.postProcessEnabled && renderingData.cameraData.cameraType == CameraType.Game)
        {
            m_scriptablePass.renderPassEvent = renderPassEvent;
            m_scriptablePass.SetRenderPass(renderer.cameraColorTargetHandle,grabFullScreenTextureName,grabFullScreenTexture);
            // RenderPass配置输入
            // Color: CopyColor & _CameraOpaqueTexture
            // Depth: DepthPrePass & _CameraDepthTexture
            // Normal: DepthNormalPrePass & _CameraDepthNormalsTexture
            // Motion: MotionVectors & _CameraMotionVectorsTexture
            m_scriptablePass.ConfigureInput(renderPassInput);
        }
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.postProcessEnabled && renderingData.cameraData.cameraType == CameraType.Game)
        {
            renderer.EnqueuePass(m_scriptablePass);
        }
    }
    
}


