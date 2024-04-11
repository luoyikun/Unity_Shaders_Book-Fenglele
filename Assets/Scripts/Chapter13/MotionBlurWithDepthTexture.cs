using UnityEngine;
using System.Collections;

public class MotionBlurWithDepthTexture : PostEffectsBase {

	public Shader motionBlurShader;
	private Material motionBlurMaterial = null;

	public Material material {  
		get {
			motionBlurMaterial = CheckShaderAndCreateMaterial(motionBlurShader, motionBlurMaterial);
			return motionBlurMaterial;
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

	[Range(0.0f, 1.0f)]
	public float blurSize = 0.5f;

    //保存上一帧摄像机的视角*投影矩阵
    private Matrix4x4 previousViewProjectionMatrix;
	
	void OnEnable() {
        //需要获取摄像机的深度纹理，设置摄像机的状态
        camera.depthTextureMode |= DepthTextureMode.Depth;

        //camera.projectionMatrix 是当前帧的摄像机投影矩阵，用于将场景中的物体投影到摄像机视锥体上。
        //camera.worldToCameraMatrix 是将世界坐标系中的点转换为摄像机坐标系的矩阵。
        //将这两个矩阵相乘得到的结果是上一帧的视图投影矩阵。
        previousViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
	}
	
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			material.SetFloat("_BlurSize", blurSize);
            //上一帧视角*投影矩阵
            material.SetMatrix("_PreviousViewProjectionMatrix", previousViewProjectionMatrix);
			Matrix4x4 currentViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
			Matrix4x4 currentViewProjectionInverseMatrix = currentViewProjectionMatrix.inverse;
            //当前帧视角*投影矩阵的逆矩阵
            material.SetMatrix("_CurrentViewProjectionInverseMatrix", currentViewProjectionInverseMatrix);
            //当前帧赋值给上一帧
            previousViewProjectionMatrix = currentViewProjectionMatrix;

			Graphics.Blit (src, dest, material);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
