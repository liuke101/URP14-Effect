using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

public class CalcMaxVertexDistance : MonoBehaviour
{
    public Material material;
    private float m_maxDistance;
    private static readonly int s_MaxVertexDistance = Shader.PropertyToID("_MaxVertexDistance");

    void Start()
    {
        m_maxDistance = CalculationMaxDistance();
    }
    void Update()
    {
        material.SetFloat(s_MaxVertexDistance, m_maxDistance);
    }
    float CalculationMaxDistance()
    {
        float maxDistance = 0;
        Vector3[] vertices = GetComponent<MeshFilter>().mesh.vertices;
        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 v1 = vertices[i];
            for (int k = 0; k < vertices.Length; k++)
            {
                if (i == k) continue;
                Vector3 v2 = vertices[k];
                float mag = (v1 - v2).magnitude;
                if (mag > maxDistance)
                {
                    maxDistance = mag;
                }
            }
        }

        return maxDistance;
    }

}