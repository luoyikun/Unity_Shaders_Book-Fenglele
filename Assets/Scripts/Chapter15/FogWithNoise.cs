using UnityEngine;
using System.Collections;
//非均匀，飘动雾
public class FogWithNoise : PostEffectsBase {

	public Shader fogShader;
	private Material fogMaterial = null;

	public Material material {  
		get {
			fogMaterial = CheckShaderAndCreateMaterial(fogShader, fogMaterial);
			return fogMaterial;
		}  
	}
	
	private Camera myCamera;
	public Camera camera {
		get {
			if (myCamera == null) {
				myCamera = GetComponent<Camera>();
			}
			return myCamera;
		}
	}

	private Transform myCameraTransform;
	public Transform cameraTransform {
		get {
			if (myCameraTransform == null) {
				myCameraTransform = camera.transform;
			}
			
			return myCameraTransform;
		}
	}
    //fogDensity用于控制雾的浓度
    [Range(0.1f, 3.0f)]
	public float fogDensity = 1.0f;

	public Color fogColor = Color.white;

	public float fogStart = 0.0f;
	public float fogEnd = 2.0f;

    //noiseTexture是我们使用的噪声纹理
    public Texture noiseTexture;

	[Range(-0.5f, 0.5f)]
	public float fogXSpeed = 0.1f;

	[Range(-0.5f, 0.5f)]
	public float fogYSpeed = 0.1f;

    //noiseAmount用于控制噪声程度，当noiseAmount为0时，表示不应用任何噪声，即得到一个均匀的基于高度的全局雾效
    [Range(0.0f, 3.0f)]
	public float noiseAmount = 1.0f;

	void OnEnable() {
		GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
	}
		
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			Matrix4x4 frustumCorners = Matrix4x4.identity;
			
			float fov = camera.fieldOfView;
			float near = camera.nearClipPlane;
			float aspect = camera.aspect;//宽高比

            //近裁剪平面（Near Clipping Plane）上的一半高度
            float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
            //最右点位置。相对于摄像头为原点，这是一个偏移量
			Vector3 toRight = cameraTransform.right * halfHeight * aspect;
            //计算最上点位置相对于摄像机为原点的偏移。这个向量是摄像机上方方向上的偏移量。
            Vector3 toTop = cameraTransform.up * halfHeight;
			//首先得到近裁剪面一个点，再向上偏移，向左偏移，得到左上点坐标。世界空间下坐标
			Vector3 topLeft = cameraTransform.forward * near + toTop - toRight;
            //用于调整顶点的位置，使其位于摄像机近裁剪平面的正确位置
            float scale = topLeft.magnitude / near;
			
			topLeft.Normalize();
			topLeft *= scale;
			
			Vector3 topRight = cameraTransform.forward * near + toRight + toTop;
			topRight.Normalize();
			topRight *= scale;
			
			Vector3 bottomLeft = cameraTransform.forward * near - toTop - toRight;
			bottomLeft.Normalize();
			bottomLeft *= scale;
			
			Vector3 bottomRight = cameraTransform.forward * near + toRight - toTop;
			bottomRight.Normalize();
			bottomRight *= scale;

            //近裁剪平面的4个角对应的向量，并把它们存储在一个矩阵类型的变量（frustumCorners）中
            frustumCorners.SetRow(0, bottomLeft);
			frustumCorners.SetRow(1, bottomRight);
			frustumCorners.SetRow(2, topRight);
			frustumCorners.SetRow(3, topLeft);
			
			material.SetMatrix("_FrustumCornersRay", frustumCorners);

			material.SetFloat("_FogDensity", fogDensity);
			material.SetColor("_FogColor", fogColor);
			material.SetFloat("_FogStart", fogStart);
			material.SetFloat("_FogEnd", fogEnd);

			material.SetTexture("_NoiseTex", noiseTexture);
			material.SetFloat("_FogXSpeed", fogXSpeed);
			material.SetFloat("_FogYSpeed", fogYSpeed);
			material.SetFloat("_NoiseAmount", noiseAmount);

			Graphics.Blit (src, dest, material);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
