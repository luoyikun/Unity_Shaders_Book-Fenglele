// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//水波
Shader "Unity Shaders Book/Chapter 11/Water" {
	Properties {
		//河流纹理
		_MainTex ("Main Tex", 2D) = "white" {}
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		//水流波动的幅度
		_Magnitude ("Distortion Magnitude", Float) = 1
		//频率
 		_Frequency ("Distortion Frequency", Float) = 1
		//波长的倒数（_InvWaveLength越大，波长越小）
 		_InvWaveLength ("Distortion Inverse Wave Length", Float) = 10
		//河流纹理的移动速度
 		_Speed ("Speed", Float) = 0.5
	}
	SubShader {
		// Need to disable batching because of the vertex animation
		//批处理会合并所有相关的模型，而这些模型各自的模型空间就会丢失。
		//而在本例中，我们需要在物体的模型空间下对顶点位置进行偏移。因此，在这里需要取消对该Shader的批处理操作。
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			//关闭剔除，水流的每个面都能显示
			Cull Off
			
			CGPROGRAM  
			#pragma vertex vert 
			#pragma fragment frag
			
			#include "UnityCG.cginc" 
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			float _Magnitude;
			float _Frequency;
			float _InvWaveLength;
			float _Speed;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert(a2v v) {
				v2f o;
				//顶点的位移量
				float4 offset;
				//只希望对顶点的x方向进行位移，因此yzw的位移量被设置为0
				offset.yzw = float3(0.0, 0.0, 0.0);
				//_Frequency属性和内置的_Time.y变量来控制正弦函数的频率。
				//为了让不同位置具有不同的位移，我们对上述结果加上了模型空间下的位置分量，并乘以_InvWaveLength来控制波长。
				//最后，我们对结果值乘以_Magnitude属性来控制波动幅度，得到最终的位移。
				offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
				o.pos = UnityObjectToClipPos(v.vertex + offset);
				
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				//纹理动画，使用_Time.y和_Speed来控制在水平方向上的纹理动画
				o.uv +=  float2(0.0, _Time.y * _Speed);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed4 c = tex2D(_MainTex, i.uv);
				c.rgb *= _Color.rgb;
				
				return c;
			} 
			
			ENDCG
		}
	}
	FallBack "Transparent/VertexLit"
}
