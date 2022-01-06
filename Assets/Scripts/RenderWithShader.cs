using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RenderWithShader : MonoBehaviour
{
    public RenderTexture sourceRT;
    public RenderTexture targetRT;
    // Start is called before the first frame update
    void Start()
    {
        //targetRT = Blur(sourceRT, 1);
    }

    // Update is called once per frame
    void Update()
    {
        Blur(5);
    }

    public void Blur(int iterations)
    {
        RenderTexture rt = sourceRT;
        Material mat = new Material(Shader.Find("Blur"));
        RenderTexture blit = targetRT;
        for (int i = 0; i < iterations; i++)
        {
            Graphics.SetRenderTarget(blit);
            GL.Clear(true, true, Color.black);
            Graphics.Blit(rt, blit, mat);
            Graphics.SetRenderTarget(rt);
            GL.Clear(true, true, Color.black);
            Graphics.Blit(blit, rt, mat);
        }
    }

}
