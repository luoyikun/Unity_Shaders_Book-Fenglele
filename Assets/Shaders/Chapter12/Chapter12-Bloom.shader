// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//bloom 花开效果，亮的部分向边缘扩散，朦胧感
Shader "Unity Shaders Book/Chapter 12/Bloom" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		//_Bloom是高斯模糊后的较亮区域
		_Bloom ("Bloom (RGB)", 2D) = "black" {}
		//LuminanceThreshold是用于提取较亮区域使用的阈值
		_LuminanceThreshold ("Luminance Threshold", Float) = 0.5
		//控制不同迭代之间高斯模糊的模糊区域范围
		_BlurSize ("Blur Size", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		sampler2D _Bloom;
		float _LuminanceThreshold;
		float _BlurSize;
		
		struct v2f {
			float4 pos : SV_POSITION; 
			half2 uv : TEXCOORD0;
		};	
		
		v2f vertExtractBright(appdata_img v) {
			v2f o;
			
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
					 
			return o;
		}
		
		fixed luminance(fixed4 color) {
			return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
		}
		
		fixed4 fragExtractBright(v2f i) : SV_Target {
			fixed4 c = tex2D(_MainTex, i.uv);
			//采样得到的亮度值减去阈值_LuminanceThreshold，并把结果截取到0～1范围内
			fixed val = clamp(luminance(c) - _LuminanceThreshold, 0.0, 1.0);
			//和原像素值相乘，得到提取后的亮部区域
			return c * val;
		}
		
		struct v2fBloom {
			float4 pos : SV_POSITION; 
			half4 uv : TEXCOORD0; //两个纹理坐标，并存储在同一个类型为half4的变量uv
		};
		
		v2fBloom vertBloom(appdata_img v) {
			v2fBloom o;
			
			o.pos = UnityObjectToClipPos (v.vertex);
			o.uv.xy = v.texcoord;	//_MainTex，即原图像的纹理坐标	
			o.uv.zw = v.texcoord; //zw分量是_Bloom，即模糊后的较亮区域的纹理坐标
			
			#if UNITY_UV_STARTS_AT_TOP			
			if (_MainTex_TexelSize.y < 0.0)
				o.uv.w = 1.0 - o.uv.w;
			#endif
				        	
			return o; 
		}
		
		fixed4 fragBloom(v2fBloom i) : SV_Target {
			return tex2D(_MainTex, i.uv.xy) + tex2D(_Bloom, i.uv.zw);
		} 
		
		ENDCG
		
		ZTest Always Cull Off ZWrite Off
		
		//第0个pass，用于得到图像中较为亮区域
		Pass {  
			CGPROGRAM  
			#pragma vertex vertExtractBright  
			#pragma fragment fragExtractBright  
			
			ENDCG  
		}
		
		//高斯迭代得到模糊效果
		//第1个和第2个Pass我们直接使用了12.4节高斯模糊中定义的两个Pass，这是通过UsePass语义指明它们的Pass名来实现的。
		//需要注意的是，由于Unity内部会把所有Pass的Name转换成大写字母表示，因此在使用UsePass命令时我们必须使用大写形式的名字。
		UsePass "Unity Shaders Book/Chapter 12/Gaussian Blur/GAUSSIAN_BLUR_VERTICAL"
		
		UsePass "Unity Shaders Book/Chapter 12/Gaussian Blur/GAUSSIAN_BLUR_HORIZONTAL"
		
		//第3个Pass使用Bloom混合效果
		Pass {  
			CGPROGRAM  
			#pragma vertex vertBloom  
			#pragma fragment fragBloom  
			
			ENDCG  
		}
	}
	FallBack Off
}
