// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//序列帧动画
Shader "Unity Shaders Book/Chapter 11/Image Sequence Animation" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Image Sequence", 2D) = "white" {}
		//水平上图像个数
    	_HorizontalAmount ("Horizontal Amount", Float) = 4
		//竖直方向上图像个数
    	_VerticalAmount ("Vertical Amount", Float) = 4
    	_Speed ("Speed", Range(1, 100)) = 30
	}
	SubShader {
		//图像是透明纹理
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			
			CGPROGRAM
			
			#pragma vertex vert  
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _HorizontalAmount;
			float _VerticalAmount;
			float _Speed;
			  
			struct a2v {  
			    float4 vertex : POSITION; 
			    float2 texcoord : TEXCOORD0;//模型空间的纹理坐标
			};  
			
			struct v2f {  
			    float4 pos : SV_POSITION;
			    float2 uv : TEXCOORD0;
			};  
			
			v2f vert (a2v v) {  
				v2f o;  
				o.pos = UnityObjectToClipPos(v.vertex);  
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);  
				return o;
			}  
			
			fixed4 frag (v2f i) : SV_Target {
				//_Time.y 自该场景加载后所经过的时间
				//模拟时间，相当于当前总时间，或者说走过的时间
				float time = floor(_Time.y * _Speed);  
				//time除以_HorizontalAmount的结果值的商来作为当前对应的行索引
				float row = floor(time / _HorizontalAmount);
				//除法结果的余数则是列索引
				float column = time - row * _HorizontalAmount;
				
				//8等分uv，原纹理坐标i.uv按行数和列数进行等分，得到每个子图像的纹理坐标范围
				half2 uv = float2(i.uv.x /_HorizontalAmount, i.uv.y / _VerticalAmount);
				//x需要偏移为 + (当前列 / 总列)
				uv.x += column / _HorizontalAmount;
				//y需要偏移为 - (当前行 / 总行)，因为UV.y 是从上到下，为1-0，所需需要反过来
				uv.y -= row / _VerticalAmount;


				//优化，乘法的性能更高
				// half2 uv = i.uv + half2(column, -row);

				// uv.x /=  _HorizontalAmount;
				// uv.y /= _VerticalAmount;
				
				fixed4 c = tex2D(_MainTex, uv);
				c.rgb *= _Color;
				
				return c;
			}
			
			ENDCG
		}  
	}
	FallBack "Transparent/VertexLit"
}
