using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(ImageCut))]
public class ImageCutEditor : Editor
{
    ImageCut Target;
    string saveFolder = "Assets";
    void OnEnable()
    {
        Target = (ImageCut)target;
    }

    //@@@
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Cut3"))
        {
            var tex = Target.tex;
            Debug.Log(tex.width);

            int w = tex.width;        
            int h = tex.height;
            if (w % 3 != 0)
            {
                Debug.Log("w NOT 3");
            }
            else
            {
                int cw = w / 3;
                var oTex = new Texture2D(cw, h, tex.format, false);
                for (int j = 0; j < h; j++)
                {
                    for (int i = 0; i < cw; i++)
                    {
                        oTex.SetPixel(i, j, tex.GetPixel(i, j));
                        //break;
                    }
                }
                System.IO.File.WriteAllBytes(saveFolder + "/t1.png", oTex.EncodeToPNG());
                AssetDatabase.Refresh();
            }
        }
    }
}
