using UnityEngine;
using System.Collections;
//高斯模糊
public class GaussianBlur : PostEffectsBase {

	public Shader gaussianBlurShader;
	private Material gaussianBlurMaterial = null;

	public Material material {  
		get {
			gaussianBlurMaterial = CheckShaderAndCreateMaterial(gaussianBlurShader, gaussianBlurMaterial);
			return gaussianBlurMaterial;
		}  
	}

	// Blur iterations - larger number means more blur.
    //迭代次数
	[Range(0, 4)]
	public int iterations = 3;
	
	// Blur spread for each iteration - larger value means more blur
    //模糊扩展，值越大，离采样像素扩展的越远
	[Range(0.2f, 3.0f)]
	public float blurSpread = 0.6f;
	
	[Range(1, 8)]
    //downSample越大，需要处理的像素数越少，同时也能进一步提高模糊程度，性能越好
    //但过大的downSample可能会使图像像素化
    public int downSample = 2;

    /// 1st edition: just apply blur
    //	void OnRenderImage(RenderTexture src, RenderTexture dest) {
    //		if (material != null) {
    //			int rtW = src.width;
    //			int rtH = src.height;
    //          //分配了一块与屏幕图像大小相同的缓冲区。这是因为，高斯模糊需要调用两个Pass，我们需要使用一块中间缓存来存储第一个Pass执行完毕后得到的模糊结果    
    //			RenderTexture buffer = RenderTexture.GetTemporary(rtW, rtH, 0);
    //
    //			// Render the vertical pass
    //			Graphics.Blit(src, buffer, material, 0);
    //			// Render the horizontal pass
    //			Graphics.Blit(buffer, dest, material, 1);
    //          
    //          //释放之前分配的缓存
    //			RenderTexture.ReleaseTemporary(buffer);
    //		} else {
    //			Graphics.Blit(src, dest);
    //		}
    //	} 

    /// 2nd edition: scale the render texture
    /// 利用缩放对图像进行降采样，从而减少需要处理的像素个数，提高性能
    //	void OnRenderImage (RenderTexture src, RenderTexture dest) {
    //		if (material != null) {
    //			int rtW = src.width/downSample;
    //			int rtH = src.height/downSample;
    //          //声明缓冲区的大小时，使用了小于原屏幕分辨率的尺寸，并将该临时渲染纹理的滤波模式设置为双线性
    //          //尽管downSample值越大，性能越好，但过大的downSample可能会造成图像像素化
    //			RenderTexture buffer = RenderTexture.GetTemporary(rtW, rtH, 0);
    //			buffer.filterMode = FilterMode.Bilinear;
    //
    //			// Render the vertical pass
    //			Graphics.Blit(src, buffer, material, 0);
    //			// Render the horizontal pass
    //			Graphics.Blit(buffer, dest, material, 1);
    //
    //			RenderTexture.ReleaseTemporary(buffer);
    //		} else {
    //			Graphics.Blit(src, dest);
    //		}
    //	}

    /// 3rd edition: use iterations for larger blur
    /// 使用了高斯迭代次数
    void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			int rtW = src.width/downSample;
			int rtH = src.height/downSample;

			RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
			buffer0.filterMode = FilterMode.Bilinear;
            //src中的图像缩放后存储到buffer0中
            Graphics.Blit(src, buffer0);
            //利用两个临时缓存在迭代之间进行交替的过程
            for (int i = 0; i < iterations; i++) {
				material.SetFloat("_BlurSize", 1.0f + i * blurSpread);

				RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                // Render the vertical pass
                //在执行第一个Pass时，输入是buffer0，输出是buffer1,
                Graphics.Blit(buffer0, buffer1, material, 0);
                //完毕后首先把buffer0释放
                RenderTexture.ReleaseTemporary(buffer0);
                //再把结果值buffer1存储到buffer0中
                buffer0 = buffer1;
				buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

				// Render the horizontal pass
				Graphics.Blit(buffer0, buffer1, material, 1);

				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
			}

			Graphics.Blit(buffer0, dest);
			RenderTexture.ReleaseTemporary(buffer0);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
