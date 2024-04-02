// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//高斯模糊
Shader "Unity Shaders Book/Chapter 12/Gaussian Blur" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		//采样距离，越大越模糊，过大的_BlurSize值会造成虚影
		_BlurSize ("Blur Size", Float) = 1.0
	}
	SubShader {
		//这些代码不需要包含在任何Pass语义块中，在使用时，我们只需要在Pass中直接指定需要使用的顶点着色器和片元着色器函数名即可。
		//CGINCLUDE类似于C++中头文件的功能。
		//由于高斯模糊需要定义两个Pass，但它们使用的片元着色器代码是完全相同的，使用CGINCLUDE可以避免我们编写两个完全一样的frag函数。
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;  //不需要定义float4 _MainTex_ST吗
		
		half4 _MainTex_TexelSize; //Unity提供的_MainTex_TexelSize变量，以计算相邻像素的纹理坐标偏移量
		float _BlurSize;
		  
		struct v2f {
			float4 pos : SV_POSITION;
			//一个5×5的二维高斯核可以拆分成两个大小为5的一维高斯核，因此我们只需要计算5个纹理坐标即可
			//一个5维的纹理坐标数组
			//数组的第一个坐标存储了当前的采样纹理，而剩余的四个坐标则是高斯模糊中对邻域采样时使用的纹理坐标
			//计算采样纹理坐标的代码从片元着色器中转移到顶点着色器中，可以减少运算，提高性能
			half2 uv[5]: TEXCOORD0; 
		};
		  
		//竖直方向上采样
		v2f vertBlurVertical(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			half2 uv = v.texcoord;//第一套纹理
			
			o.uv[0] = uv;
			//属性_BlurSize相乘来控制采样距离
			o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
			o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
			o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
			o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
					 
			return o;
		}
		
		v2f vertBlurHorizontal(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			half2 uv = v.texcoord;
			
			o.uv[0] = uv;
			o.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
			o.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
			o.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
			o.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
					 
			return o;
		}
		
		//两个pass共用的frag
		fixed4 fragBlur(v2f i) : SV_Target {
			//一个5×5的二维高斯核可以拆分成两个大小为5的一维高斯核，并且由于它的对称性，我们只需要记录3个高斯权重
			//5x5怎么变5*1，最后又变3*1
			//本来是 {0.0545,0.2442,0.4026, 0.2442, 0.0545}
			float weight[3] = {0.4026, 0.2442, 0.0545};

			//sum初始化为当前的像素值乘以它的权重值，这个是中间像素
			fixed3 sum = tex2D(_MainTex, i.uv[0]).rgb * weight[0];
			
			//遍历某个像素的4个方向，对应uv1，uv2，uv3，uv4
			//							+1, -1, +2 , -2												
			//优化，本来是4次的，使用对称性，变为2次
			for (int it = 1; it < 3; it++) {
				sum += tex2D(_MainTex, i.uv[it*2-1]).rgb * weight[it];
				sum += tex2D(_MainTex, i.uv[it*2]).rgb * weight[it];
			}
			
			return fixed4(sum, 1.0);
		}
		    
		ENDCG
		
		ZTest Always Cull Off ZWrite Off
		
		Pass {
			//字符串中内容要全大写，不然的话其他pass用不了
			NAME "GAUSSIAN_BLUR_VERTICAL"
			
			CGPROGRAM
			  
			#pragma vertex vertBlurVertical  
			#pragma fragment fragBlur
			  
			ENDCG  
		}
		
		Pass {  
			NAME "GAUSSIAN_BLUR_HORIZONTAL"
			
			CGPROGRAM  
			
			#pragma vertex vertBlurHorizontal  
			#pragma fragment fragBlur
			
			ENDCG
		}
	} 
	FallBack "Diffuse"
}
