using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(RenderWithShader))]
public class RenderWithShaderEditor : Editor
{
    RenderWithShader Target;

    void OnEnable()
    {
        Target = (RenderWithShader)target;
    }

    //@@@
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Blur"))
        {
            Target.Blur(5);
        }
    }
}
