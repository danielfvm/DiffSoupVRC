
using UdonSharp;
using UnityEngine;

public class DiffSoupModel : UdonSharpBehaviour
{
    public MeshRenderer meshRenderer;
    public Matrix4x4[] W1, W2, W3;
    public Vector4[] B1, B2;
    public Vector4 B3;

    public void Start() => Init();

    public void Init()
    {
        var propertyBlock = new MaterialPropertyBlock();
        propertyBlock.SetMatrixArray("_W1", W1);
        propertyBlock.SetVectorArray("_B1", B1);
        propertyBlock.SetMatrixArray("_W2", W2);
        propertyBlock.SetVectorArray("_B2", B2);
        propertyBlock.SetMatrixArray("_W3", W3);
        propertyBlock.SetVector("_B3", B3);
        meshRenderer.SetPropertyBlock(propertyBlock);
    }
}
