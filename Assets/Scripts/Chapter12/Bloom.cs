using UnityEngine;
using System.Collections;

public class Bloom : PostEffectsBase {

	public Shader bloomShader;
	private Material bloomMaterial = null;
	public Material material {  
		get {
			bloomMaterial = CheckShaderAndCreateMaterial(bloomShader, bloomMaterial);
			return bloomMaterial;
		}  
	}

	// Blur iterations - larger number means more blur.
	[Range(0, 4)]
	public int iterations = 3;
	
	// Blur spread for each iteration - larger value means more blur
	[Range(0.2f, 3.0f)]
	public float blurSpread = 0.6f;

    //将采样分辨率从二分之一下降为四分之一是一种常见的优化手段，可以有效减少处理的像素数量，从而提高性能。
    //这意味着在进行 Bloom 效果处理时，可以使用较低分辨率的 RenderTexture 来进行处理，然后再将处理后的结果缩放回原始分辨率。
    [Range(1, 8)]
	public int downSample = 2;

    //较亮区域时使用的阈值大小
    //尽管在绝大多数情况下，图像的亮度值不会超过1。
    //但如果我们开启了HDR，硬件会允许我们把颜色值存储在一个更高精度范围的缓冲中，此时像素的亮度值可能会超过1。
    //因此，在这里我们把luminanceThreshold的值规定在[0, 4]范围内。
    [Range(0.0f, 4.0f)]
	public float luminanceThreshold = 0.6f;

	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			material.SetFloat("_LuminanceThreshold", luminanceThreshold);

			int rtW = src.width/downSample;
			int rtH = src.height/downSample;
			
			RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
			buffer0.filterMode = FilterMode.Bilinear;
            //用Shader中的第一个Pass提取图像中的较亮区域，提取得到的较亮区域将存储在buffer0中
            Graphics.Blit(src, buffer0, material, 0);

            //高斯模糊迭代处理，模糊后的较亮区域将会存储在buffer0中
            for (int i = 0; i < iterations; i++) {
				material.SetFloat("_BlurSize", 1.0f + i * blurSpread);
				
				RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                // Render the vertical pass
                Graphics.Blit(buffer0, buffer1, material, 1);
				
				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
				buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
				
				// Render the horizontal pass
				Graphics.Blit(buffer0, buffer1, material, 2);
				
				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
			}
            //我们再把buffer0传递给材质中的_Bloom纹理属性，并调用Graphics.Blit (src, dest, material, 3)
            //使用Shader中的第四个Pass来进行最后的混合，将结果存储在目标渲染纹理dest中
            material.SetTexture ("_Bloom", buffer0);  
			Graphics.Blit (src, dest, material, 3);
            //释放临时缓存
            RenderTexture.ReleaseTemporary(buffer0);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
