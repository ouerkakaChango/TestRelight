using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(RTSaver))]
public class RTSaverEditor : Editor
{
    RTSaver Target;
    string saveFolder = "Assets";
    void OnEnable()
    {
        Target = (RTSaver)target;
    }

    //@@@
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Save"))
        {
            var tex = RTSaver.RT2Tex2D(Target.rt);
            System.IO.File.WriteAllBytes(saveFolder + "/"+Target.saveName+".png", tex.EncodeToPNG());
            AssetDatabase.Refresh();
        }
    }
}
