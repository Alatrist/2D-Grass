using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public interface IGrassCollider
{
    float Radius { get; }
    Vector2 Position { get; }
}

[ExecuteAlways]
public class GrassField : MonoBehaviour
{
    public bool Edit = false;
    public bool Delete = false;

    public float Radius = 5;

    // Update is called once per frame
    void Update()
    {
        Draw();
    }
    public List<GameObject> movingGameObjects;
    public IGrassCollider[] movingObjects;

    Vector4[] movingObjectPos;

    public List<Vector3> vertices;
    [HideInInspector]
    public List<Matrix4x4> instances;

    public float sampleRadius = 2;
    public float maxSize = 2;
    public float minSize = 1;

    [HideInInspector]
    public Mesh mesh;

    public Material Material;

    public bool Clean = false;
    public bool RefreshInstances = false;

    public void Start()
    {
        if (vertices == null)
        {
            vertices = new List<Vector3>();
        }

        if (instances == null)
        {
            instances = new List<Matrix4x4>();
            Reinstantiate();
        }
        InitMesh();
        movingObjects = new IGrassCollider[movingGameObjects.Count];
        for (int i = 0; i < movingGameObjects.Count; i++)
            movingObjects[i] = movingGameObjects[i].GetComponent<IGrassCollider>();
        movingObjectPos = new Vector4[movingObjects.Length];
    }

    public void Reinstantiate()
    {
        instances.Clear();
        float delta = 2 * sampleRadius / 10f;
        for (float x = -sampleRadius; x < sampleRadius; x += delta)
            for (float y = -sampleRadius; y < sampleRadius; y += delta)
            {

                Vector2 pos = new Vector2(x, y);
                if (pos.magnitude <= sampleRadius)        //is inside a circle
                {
                    Vector3 translation = new Vector3(x, y, y / 100f);
                    float scale = UnityEngine.Random.Range(minSize, maxSize);
                    var rotation = Quaternion.Euler(0, 0, UnityEngine.Random.Range(-10, 10));
                    instances.Add(Matrix4x4.TRS(translation, rotation, new Vector3(scale, scale, 1)));
                }
            }
    }

    public void InitMesh()
    {
        if (vertices.Count > 0)
        {
            mesh = new Mesh();
            mesh.vertices = vertices.ToArray();
            int[] indices = new int[vertices.Count];
            for (int i = 0; i < vertices.Count; i++)
                indices[i] = i;
            mesh.SetIndices(indices, MeshTopology.Points, 0);
        }
    }

    void Draw()
    {
        if (mesh == null)
            return;
        Material.SetFloat("u_time", Time.time);
        if (Application.isPlaying)
            if (movingObjects != null && movingObjects.Length > 0)
            {
                for (int i = 0; i < movingObjects.Length; i++)
                {
                    var pos = movingObjects[i].Position;
                    movingObjectPos[i] = new Vector4(pos.x, pos.y, 0, movingObjects[i].Radius);
                }
                Material.SetVectorArray("collision_distances", movingObjectPos);
                Material.SetInt("collision_count", movingObjectPos.Length);
               // Material.SetVector("wind_dir", (Vector4)Wind.Instance.WindDir);
               // Material.SetFloat("wind_strength", Wind.Instance.wind_strength);
               // Material.SetFloat("whirling_strength", Wind.Instance.wind_strength);
            }
        Graphics.DrawMeshInstanced(mesh, 0, Material, instances);
    }

    private void OnDrawGizmos()
    {

        var boxSize = new Vector3(0.05f, .05f, .05f);
        foreach (var i in instances)
        {
            Gizmos.color = Color.green;
            foreach (var v in vertices)
            {
                Gizmos.DrawCube(i.MultiplyPoint(v), boxSize);
            }
        }
    }
}
