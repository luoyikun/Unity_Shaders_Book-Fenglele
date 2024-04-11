using UnityEngine;
using System.Collections;
//边缘检测使用法相与深度图
public class EdgeDetectNormalsAndDepth : PostEffectsBase {

	public Shader edgeDetectShader;
	private Material edgeDetectMaterial = null;
	public Material material {  
		get {
			edgeDetectMaterial = CheckShaderAndCreateMaterial(edgeDetectShader, edgeDetectMaterial);
			return edgeDetectMaterial;
		}  
	}
    //边缘线强度
    [Range(0.0f, 1.0f)]
	public float edgesOnly = 0.0f;

	public Color edgeColor = Color.black;

	public Color backgroundColor = Color.white;

    //采样距离，sampleDistance值越大，描边越宽
    public float sampleDistance = 1.0f;
    //深度灵敏度，如果很大，即使很小的变化也会形成一条边
	public float sensitivityDepth = 1.0f;
    //法线灵敏度
	public float sensitivityNormals = 1.0f;
	
	void OnEnable() {
        //获取摄像机的深度+法线纹理，我们在脚本的OnEnable函数中设置摄像机的相应状态
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
	}

    //指定相机渲染目标的 Alpha 通道是否为不透明
    [ImageEffectOpaque]
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			material.SetFloat("_EdgeOnly", edgesOnly);
			material.SetColor("_EdgeColor", edgeColor);
			material.SetColor("_BackgroundColor", backgroundColor);
			material.SetFloat("_SampleDistance", sampleDistance);
			material.SetVector("_Sensitivity", new Vector4(sensitivityNormals, sensitivityDepth, 0.0f, 0.0f));

			Graphics.Blit(src, dest, material);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
