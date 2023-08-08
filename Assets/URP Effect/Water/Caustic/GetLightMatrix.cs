using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GetLightMatrix : MonoBehaviour
{
    public Material causticsMaterial;
    private Matrix4x4 m_lightMatrix;
    private static readonly int s_MainLightDirection = Shader.PropertyToID("_MainLightDirection");

    void Update()
    {
        //局部空间转换到世界空间的矩阵
        m_lightMatrix = RenderSettings.sun.transform.localToWorldMatrix;
        causticsMaterial.SetMatrix(s_MainLightDirection, m_lightMatrix);
    }
}
