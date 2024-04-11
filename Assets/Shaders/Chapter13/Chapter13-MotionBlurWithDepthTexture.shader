// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//运动模糊使用深度纹理
Shader "Unity Shaders Book/Chapter 13/Motion Blur With Depth Texture" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurSize ("Blur Size", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
		//主纹理的纹素大小，每个像素在世界坐标下大小
		half4 _MainTex_TexelSize;
		sampler2D _CameraDepthTexture;
		//并没有在Properties块中声明它们。
		//这是因为Unity没有提供矩阵类型的属性，但我们仍然可以在CG代码块中定义这些矩阵，并从脚本中设置它们
		float4x4 _CurrentViewProjectionInverseMatrix;
		float4x4 _PreviousViewProjectionMatrix;
		half _BlurSize;
		
		struct v2f {
			float4 pos : SV_POSITION;//裁剪空间下坐标
			half2 uv : TEXCOORD0;
			half2 uv_depth : TEXCOORD1;//深度纹理采样的纹理坐标变量
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			//DirectX这样的平台上，我们需要处理平台差异导致的图像翻转问题
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
					 
			return o;
		}
		
		fixed4 frag(v2f i) : SV_Target {
			// Get the depth buffer value at this pixel.
			//纹理坐标对深度纹理进行采样，得到了深度值d
			float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);
			// H is the viewport position at this pixel in the range -1 to 1.
			//d 是由NDC下的坐标映射而来的。
			//我们想要构建像素的NDC坐标H ，就需要把这个深度值重新映射回NDC。
			//这个映射很简单，只需要使用原映射的反函数即可，即d * 2-1
			float4 H = float4(i.uv.x * 2 - 1, i.uv.y * 2 - 1, d * 2 - 1, 1);
			// Transform by the view-projection inverse.
			//使用当前帧的视角*投影矩阵的逆矩阵对其进行变换
			float4 D = mul(_CurrentViewProjectionInverseMatrix, H);
			// Divide by w to get the world position. 
			//结果值除以它的w 分量来得到世界空间下的坐标表示worldPos
			float4 worldPos = D / D.w;
			
			// Current viewport position 
			float4 currentPos = H;
			// Use the world position, and transform by the previous view-projection matrix.  
			//使用前一帧的视角*投影矩阵对它进行变换，得到前一帧在NDC下的坐标previousPos
			float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
			// Convert to nonhomogeneous points [-1,1] by dividing by w.
			previousPos /= previousPos.w;
			
			// Use this frame's position and last frame's to compute the pixel velocity.
			//两帧的位置差，得到速度
			float2 velocity = (currentPos.xy - previousPos.xy)/2.0f;
			
			float2 uv = i.uv;
			float4 c = tex2D(_MainTex, uv);
			//邻域像素进行采样，相加后取平均值得到一个模糊的效果。
			//采样时我们还使用了_BlurSize来控制采样距离
			uv += velocity * _BlurSize;
			for (int it = 1; it < 3; it++, uv += velocity * _BlurSize) {
				float4 currentColor = tex2D(_MainTex, uv);
				c += currentColor;
			}
			c /= 3;
			
			return fixed4(c.rgb, 1.0);
		}
		
		ENDCG
		
		Pass {      
			ZTest Always Cull Off ZWrite Off
			    	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG  
		}
	} 
	FallBack Off
}
