using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RTSaver : MonoBehaviour
{
    public string saveName;
    public RenderTexture rt;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    static public Texture2D RT2Tex2D(RenderTexture rTex, TextureFormat format = TextureFormat.RGBA32)
    {
        Texture2D tex = new Texture2D(rTex.width, rTex.height, format, false);
        RenderTexture.active = rTex;
        tex.ReadPixels(new Rect(0, 0, rTex.width, rTex.height), 0, 0);
        tex.Apply();

        return tex;
    }
}
