using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;
using UnityEditor;
using UnityEngine;

public class DiffSoup : MonoBehaviour
{
    private static Matrix4x4[] TileWeightsToMat4(float[] W, int outDim, int inDim)
    {
        Matrix4x4[] mats = new Matrix4x4[16];

        for (int i = 0; i < 16; i++)
            mats[i] = new Matrix4x4();

        for (int tr = 0; tr < 4; ++tr)
        {
            for (int tc = 0; tc < 4; ++tc)
            {
                Matrix4x4 m = mats[tr * 4 + tc];

                for (int c = 0; c < 4; ++c)
                {
                    for (int r = 0; r < 4; ++r)
                    {
                        int gr = tr * 4 + r;
                        int gc = tc * 4 + c;

                        float value = (gr < outDim && gc < inDim)
                            ? W[gr * inDim + gc]
                            : 0f;

                        // Unity matrices are column-major: m[row, col]
                        m[r, c] = value;
                    }
                }

                mats[tr * 4 + tc] = m;
            }
        }

        return mats;
    }

    private static Matrix4x4[] TileW3ToMat4(float[] W3)
    {
        Matrix4x4[] mats = new Matrix4x4[4];

        for (int i = 0; i < 4; i++)
            mats[i] = new Matrix4x4();

        for (int tc = 0; tc < 4; ++tc)
        {
            Matrix4x4 m = mats[tc];

            for (int c = 0; c < 4; ++c)
            {
                for (int r = 0; r < 3; ++r)
                {
                    int gc = tc * 4 + c;

                    if (gc < 16)
                    {
                        m[r, c] = W3[r * 16 + gc];
                    }
                }
            }

            mats[tc] = m;
        }

        return mats;
    }

    private static Vector4[] PackBiasVec4(float[] b, int groups)
    {
        Vector4[] result = new Vector4[groups];

        for (int i = 0; i < groups; i++)
            result[i] = Vector4.zero;

        for (int i = 0; i < b.Length && i < groups * 4; ++i)
        {
            int groupIndex = i / 4;
            int component = i % 4;

            Vector4 v = result[groupIndex];
            v[component] = b[i];
            result[groupIndex] = v;
        }

        return result;
    }

    [MenuItem("DiffSoup/Reset Property Blocks")]
    public static void Reset()
    {
        foreach (var model in FindObjectsByType<DiffSoupModel>(FindObjectsSortMode.None))
            model.Init();
    }

    [MenuItem("DiffSoup/Load")]
    static void Load()
    {
        string absolutePath = EditorUtility.OpenFolderPanel("Select Model Folder", "Assets/", "");
        string folder = "Assets" + absolutePath.Substring(Application.dataPath.Length);
    
        var loader = new PlyLoader();
        var models = loader.load($"{folder}/mesh.ply");
        if (models.Length == 0)
            return;

        var obj = new GameObject(Path.GetFileName(folder));
        var meshFilter = obj.AddComponent<MeshFilter>();
        meshFilter.mesh = models[0];

        AssetDatabase.CreateAsset(models[0], $"{folder}/mesh.asset");
        AssetDatabase.SaveAssets();

        // Setup correct import
        for (int i = 0; i < 2; i++)
        {
            TextureImporter importer = (TextureImporter)AssetImporter.GetAtPath($"{folder}/lut{i}.png");

            TextureImporterPlatformSettings settings = importer.GetDefaultPlatformTextureSettings();
            settings.overridden = false;
            settings.format = TextureImporterFormat.Automatic;
            settings.textureCompression = TextureImporterCompression.CompressedHQ;

            importer.SetPlatformTextureSettings(settings);
            importer.sRGBTexture = false;
            importer.npotScale = TextureImporterNPOTScale.None;
            importer.textureCompression = TextureImporterCompression.CompressedHQ;
            importer.filterMode = FilterMode.Point;
            importer.maxTextureSize = 4096;
            importer.mipmapEnabled = false;
            importer.crunchedCompression = true;
            importer.compressionQuality = 50;
            importer.SaveAndReimport();
        }

        Texture2D lut0 = AssetDatabase.LoadAssetAtPath<Texture2D>($"{folder}/lut0.png");
        Texture2D lut1 = AssetDatabase.LoadAssetAtPath<Texture2D>($"{folder}/lut1.png");

        var data = JsonConvert.DeserializeObject<Dictionary<string, float[]>>(File.ReadAllText($"{folder}/mlp_weights.json"));
        var shader = Shader.Find("DiffSoup/Geometry");
        var material = new Material(shader);
        material.SetVector("_TriTexSize", new Vector2(lut0.width, lut0.height));
        material.SetTexture("_TriTex0", lut0);
        material.SetTexture("_TriTex1", lut1);
        material.SetFloat("_Level", 5); // This value is part of the meta.json

        AssetDatabase.CreateAsset(material, $"{folder}/material.mat");
        AssetDatabase.SaveAssets();

        var meshRenderer = obj.AddComponent<MeshRenderer>();
        meshRenderer.receiveShadows = false;
        meshRenderer.sharedMaterial = material; 

        var script = obj.AddComponent<DiffSoupModel>();
        script.meshRenderer = meshRenderer;
        script.W1 = TileWeightsToMat4(data["W1"], 16, 16);
        script.W2 = TileWeightsToMat4(data["W2"], 16, 16);
        script.W3 = TileW3ToMat4(data["W3"]);
        script.B1 = PackBiasVec4(data["b1"], 4);
        script.B2 = PackBiasVec4(data["b2"], 4);
        script.B3 = new Vector4(data["b3"][0], data["b3"][1], data["b3"][2], 0);
        script.Start();
    }
}

[InitializeOnLoad]
public static class DiffSoupModelInit
{
    static DiffSoupModelInit()
    {
        EditorApplication.playModeStateChanged += OnPlayModeChanged;
    }

    private static void OnPlayModeChanged(PlayModeStateChange state)
    {
        if (state == PlayModeStateChange.EnteredEditMode)
            DiffSoup.Reset();
    }
}