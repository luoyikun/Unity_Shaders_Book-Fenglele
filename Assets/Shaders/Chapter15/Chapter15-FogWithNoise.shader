// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//噪音雾，非均匀，飘动
Shader "Unity Shaders Book/Chapter 15/Fog With Noise" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FogDensity ("Fog Density", Float) = 1.0
		_FogColor ("Fog Color", Color) = (1, 1, 1, 1)
		_FogStart ("Fog Start", Float) = 0.0
		_FogEnd ("Fog End", Float) = 1.0
		_NoiseTex ("Noise Texture", 2D) = "white" {}
		_FogXSpeed ("Fog Horizontal Speed", Float) = 0.1
		_FogYSpeed ("Fog Vertical Speed", Float) = 0.1
		_NoiseAmount ("Noise Amount", Float) = 1
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		//矩阵未声明在面板上，虽然没有在Properties中声明，但仍可由脚本传递给Shader
		float4x4 _FrustumCornersRay;
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		//深度纹理_CameraDepthTexture，Unity会在背后把得到的深度纹理传递给该值
		sampler2D _CameraDepthTexture;
		half _FogDensity;
		fixed4 _FogColor;
		float _FogStart;
		float _FogEnd;
		sampler2D _NoiseTex;
		half _FogXSpeed;
		half _FogYSpeed;
		half _NoiseAmount;
		
		struct v2f {
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
			float2 uv_depth : TEXCOORD1;
			float4 interpolatedRay : TEXCOORD2;
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
			
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
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				index = 3 - index;
			#endif
			
			o.interpolatedRay = _FrustumCornersRay[index];
				 	 
			return o;
		}
		
		fixed4 frag(v2f i) : SV_Target {
			float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
			//根据深度纹理来重建该像素在世界空间中的位置
			float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;
			//内置的_Time.y变量和_FogXSpeed、_FogYSpeed属性计算出当前噪声纹理的偏移量
			float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);
			//对噪声纹理进行采样，得到噪声值。
			//噪声纹理中的数据存储在红色通道中
			//- 0.5：这一步是对噪声值进行调整，通常是为了将噪声范围从 [0, 1] 转换到 [-0.5, 0.5]
			float noise = (tex2D(_NoiseTex, i.uv + speed).r - 0.5) * _NoiseAmount;
			//雾效浓度的计算公式，根据高度，世界坐标		
			float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart); 
			//雾效系数返回[0,1]
			fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));
			//漫反射原本颜色
			fixed4 finalColor = tex2D(_MainTex, i.uv);
			//插值雾效颜色，t 是插值因子，它决定了在起始值和结束值之间取多少比例的值。t 的取值范围通常在 [0, 1] 之间，当 t 为 0 时返回起始值 a，当 t 为 1 时返回结束值 b
			finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);
			
			return finalColor;
		}
		
		ENDCG
		
		Pass {          	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG
		}
	} 
	FallBack Off
}
