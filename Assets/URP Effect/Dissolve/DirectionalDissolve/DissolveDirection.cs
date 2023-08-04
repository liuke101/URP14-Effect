using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

public class DissolveDirection : MonoBehaviour
{
    public Material material;
    
    private float m_minX;
    private float m_maxX;
    private static readonly int s_MinBorderX = Shader.PropertyToID("_MinBorderX");
    private static readonly int s_MaxBorderX = Shader.PropertyToID("_MaxBorderX");

    void Start()
    {
        CalculationBorderX(out m_minX, out m_maxX);
    }
    void Update()
    {
        material.SetFloat(s_MinBorderX, m_minX);
        material.SetFloat(s_MaxBorderX, m_maxX);
    }
    
    //计算X边界
    void CalculationBorderX(out float minX, out float maxX)
    {
        Vector3[] vertices = GetComponent<MeshFilter>().mesh.vertices;
        minX = vertices[0].x;
        maxX = vertices[0].x;
        
        for (int i = 1; i < vertices.Length; i++)
        {
           float x = vertices[i].x;
           if(x<minX)
               minX = x;
           if (x>maxX)
               maxX = x;
        }
    }
}