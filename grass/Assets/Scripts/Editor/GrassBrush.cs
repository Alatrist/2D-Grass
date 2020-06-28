using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(GrassField))]
public class GrassBrushEditor : Editor
{
    public void OnSceneGUI()
    {
        var grassField = (GrassField)serializedObject.targetObject;

        if (grassField.Clean)
        {
            grassField.vertices = new List<Vector3>();
            grassField.Clean = false;
            grassField.instances = null;
            grassField.Start();
        }
        if (grassField.RefreshInstances)
        {
            grassField.Reinstantiate();
            grassField.RefreshInstances = false;
        }
        if (grassField.Edit)
        {
            Event e = Event.current;
            if (e.type == EventType.MouseDown && e.button == 0)
            {

                var mousePos = (Vector2)HandleUtility.GUIPointToWorldRay(e.mousePosition).origin;

                if (grassField.Delete)
                    grassField.vertices.RemoveAll((v) => Vector2.Distance(v, mousePos) < grassField.Radius);
                else
                    grassField.vertices.Add(new Vector3(mousePos.x, mousePos.y, mousePos.y / 100.0f));
                grassField.InitMesh();
                e.Use();
            }


        }
    }


}
