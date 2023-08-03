using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Serialization;

public class SceneDissolve : MonoBehaviour
{
    private MeshRenderer[] m_meshRenderers;
    private float m_maxDistance;
    public Vector3 dissolveStartPoint;
    public float dissolveDiffuse;
    
    private static readonly int s_StartPoint = Shader.PropertyToID("_StartPoint");
    private static readonly int s_MaxVertexDistance = Shader.PropertyToID("_MaxVertexDistance");
    private static readonly int s_DissolveDiffuse = Shader.PropertyToID("_DissolveDiffuse");

    // Start is called before the first frame update
    void Start()
    {
        //将脚本呢挂载到场景的根物体上
        //计算所有子物体到消融开始点的最大距离
        MeshFilter[] meshFilters = GetComponentsInChildren<MeshFilter>();
        m_maxDistance = 0;
        for (int i = 0; i < meshFilters.Length; i++)
        {
            float distance  = CalculationMaxDistance(meshFilters[i].mesh.vertices);
            if(distance>m_maxDistance)
                m_maxDistance = distance;
        }
        m_meshRenderers = GetComponentsInChildren<MeshRenderer>();
    }

    // Update is called once per frame
    void Update()
    {
        for(int i =0;i<m_meshRenderers.Length;i++)
        {
            m_meshRenderers[i].material.SetVector(s_StartPoint, dissolveStartPoint);
            m_meshRenderers[i].material.SetFloat(s_MaxVertexDistance,m_maxDistance);
            m_meshRenderers[i].material.SetFloat(s_DissolveDiffuse, dissolveDiffuse);
        }
    }
    
    //计算给定顶点集到消融开始点的最大距离
    float CalculationMaxDistance(Vector3[] vertices)
    {
        float maxDistance = 0;
        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 vert = vertices[i];
            float distance = (vert - dissolveStartPoint).magnitude;
            if(distance>maxDistance)
                maxDistance = distance;
        }

        return maxDistance;
    }
}
