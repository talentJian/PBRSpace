using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeShaterTest : MonoBehaviour
{

    public ComputeShader mComputeShader;

    public RenderTexture resultText;

    struct VecMatPari
    {
        public Vector3 point;
        public Matrix4x4 matrix;
    }
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {

    }

    void OnGUI()
    {
        if (GUILayout.Button("Run"))
        {
            RunShaderFillWITHRed();
        }
    }

    void OnDestroy()
    {
        if (resultText != null)
            resultText.Release();
    }
    void RunShaderMain()
    {
        int kernelHandle = mComputeShader.FindKernel("CSMain");

        RenderTexture tex = new RenderTexture(256, 256, 24);
        tex.enableRandomWrite = true;
        tex.Create();
        resultText = tex;
        mComputeShader.SetTexture(kernelHandle, "Result", tex);
        mComputeShader.Dispatch(kernelHandle, 256 / 8, 258 / 8, 1);
    }

    void RunShaderMultiply()

    {
        VecMatPari[] data =new VecMatPari[5];

        ComputeBuffer buffer = new ComputeBuffer(data.Length,76);
        int kernel = mComputeShader.FindKernel("Multiply");

        mComputeShader.SetBuffer(kernel,"dataBuffer",buffer);
        mComputeShader.Dispatch(kernel,data.Length,1,1);
    }

    void RunShaderFillWITHRed()

    {
        int kernelHandle = mComputeShader.FindKernel("FillWithRed");

        RenderTexture tex = new RenderTexture(256, 256, 24);
        tex.enableRandomWrite = true;
        tex.Create();
        resultText = tex;
        mComputeShader.SetTexture(kernelHandle, "resRed", tex);
        mComputeShader.Dispatch(kernelHandle, 512, 512 , 1);
    }
}
