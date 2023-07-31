using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenuForRenderPipeline("Custom/GaussianBloom",typeof(UniversalRenderPipeline))]
public class BloomEffectComponent : VolumeComponent,IPostProcessComponent
{
    [Header("Bloom Settings")] public FloatParameter threshold = new FloatParameter(0.9f, true);
    public FloatParameter intensity = new FloatParameter(0.5f, true);
    public ClampedFloatParameter scatter = new ClampedFloatParameter(0.7f, 0, 1,true);
    public IntParameter clamp = new IntParameter(65472, true);
    public ClampedIntParameter maxInterations = new ClampedIntParameter(6,0,10);
    public NoInterpColorParameter tint = new NoInterpColorParameter(Color.white);

    [Header("Dots")] public IntParameter dotsDensity = new IntParameter(10, true);
    public ClampedFloatParameter dotsCutoff = new ClampedFloatParameter(0.4f, 0, 1, true);
    public Vector2Parameter scrollDirection = new Vector2Parameter(new Vector2());
    
    
    
    public bool IsActive()
    {
        throw new System.NotImplementedException();
    }

    public bool IsTileCompatible()
    {
        throw new System.NotImplementedException();
    }
}
