// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//使用深度纹理雾
Shader "Unity Shaders Book/Chapter 13/Fog With Depth Texture" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FogDensity ("Fog Density", Float) = 1.0
		_FogColor ("Fog Color", Color) = (1, 1, 1, 1)
		_FogStart ("Fog Start", Float) = 0.0
		_FogEnd ("Fog End", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		//由c#传递Matrix4x4到shader的float4x4
		float4x4 _FrustumCornersRay;
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		//深度纹理_CameraDepthTexture，Unity会在背后把得到的深度纹理传递给该值
		sampler2D _CameraDepthTexture;
		half _FogDensity;
		fixed4 _FogColor;
		float _FogStart;
		float _FogEnd;
		
		struct v2f {
			float4 pos : SV_POSITION;//裁剪空间下模型顶点位置
			half2 uv : TEXCOORD0;//屏幕图像
			half2 uv_depth : TEXCOORD1;//深度纹理坐标
			float4 interpolatedRay : TEXCOORD2;//存储插值后的像素向量
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			//深度纹理的采样坐标进行了平台差异化处理
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
			
			//该点对应了4个角中的哪个角
			//从左下角为(0,0),右上角为(1,1),左下角为索引0，然后逆时针递增
			//尽管我们这里使用了很多判断语句，但由于屏幕后处理所用的模型是一个四边形网格，只包含4个顶点，因此这些操作不会对性能造成很大影响。
			int index = 0;
			if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5) {
				index = 0;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5) {
				index = 1;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5) {
				index = 2;
			} else {
				index = 3;
			}

			//DirectX和Metal这样的平台,图像进行了翻转。左上角对应了(0, 0)，然后顺时针递增。因为图像是上下颠倒
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				index = 3 - index;
			#endif
			
			//使用索引值来获取_FrustumCornersRay中对应的行作为该顶点的interpolatedRay值
			o.interpolatedRay = _FrustumCornersRay[index];
				 	 
			return o;
		}
		
		fixed4 frag(v2f i) : SV_Target {
			//线性深度值。使用SAMPLE_DEPTH_TEXTURE对深度纹理进行采样，再使用LinearEyeDepth得到视角空间下的线性深度值
			float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
			//与interpolatedRay相乘后再和世界空间下的摄像机位置相加，即可得到世界空间下的位置。
			float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;

			//高度雾计算公式得到雾效系数			
			float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart); 
			//saturate函数截取到[0, 1]范围内
			fogDensity = saturate(fogDensity * _FogDensity);
			
			//颜色混合，根据某个高度的雾效系数进行插值
			fixed4 finalColor = tex2D(_MainTex, i.uv);
			finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);
			
			return finalColor;
		}
		
		ENDCG
		
		Pass {
			//ZTest Always 是一种 Z 测试模式，其含义是无论 Z 缓冲中的值如何，总是进行绘制。
			//换句话说，不管其他像素的深度值如何，当前像素都会被绘制在屏幕上。
			//这通常用于实现一些特殊的效果，比如全屏后处理效果或者在绘制 GUI 元素时。
			ZTest Always 
			//关闭了背面剔除，即不管三角形面是正面还是背面，都会被绘制。这意味着场景中的所有三角形面都会被渲染，不再考虑其朝向。
			//通常情况下，开启背面剔除可以有效地减少不可见的三角形面的绘制，提高渲染效率。
			//但在某些情况下，比如需要渲染双面材质或者特定的后处理效果时，可能需要关闭背面剔除，这时就可以使用 Cull Off。
			Cull Off 
			//开启深度写入是必要的，因为它可以确保后绘制的像素不会被之前绘制的像素所遮挡。
			//但在某些情况下，比如绘制透明物体或实现特定的后处理效果时，可能需要关闭深度写入，这时就可以使用 ZWrite Off。
			ZWrite Off
			     	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG  
		}
	} 
	FallBack Off
}
