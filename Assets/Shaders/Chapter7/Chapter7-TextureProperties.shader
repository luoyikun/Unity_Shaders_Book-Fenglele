// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 7/Texture Properties" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {}
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag

			#include "Lighting.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;

			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;//将模型的第一组纹理坐标存储到该变量中
			};
			
			struct v2f {
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert(a2v v) {
			 	v2f o;
			 	// Transform the vertex from object space to projection space
				//固定格式，模型空闲下顶点坐标转投影空间
			 	o.position = UnityObjectToClipPos(v.vertex);

				//固定格式，纹理属性转uv坐标
			 	o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
			 	
			 	return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				//采样纹理，固定格式，第一个参数为纹理属性，第二个参数为uv
				fixed4 c = tex2D(_MainTex, i.uv);

				return fixed4(c.rgb, 1.0);
			}
			
			ENDCG
		}
	} 
	FallBack "Diffuse"
}
