// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//图片边缘检测
Shader "Unity Shaders Book/Chapter 12/Edge Detection" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		//当edgesOnly值为0时，边缘将会叠加在原渲染图像上；
		//当edgesOnly值为1时，则会只显示边缘，不显示原渲染图像。
		_EdgeOnly ("Edge Only", Float) = 1.0
		//边缘的颜色
		_EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
		//背景色
		_BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
	}
	SubShader {
		Pass {  
			//屏幕后处理标配
			ZTest Always 
			Cull Off 
			ZWrite Off
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			
			#pragma vertex vert  
			#pragma fragment fragSobel
			
			sampler2D _MainTex;  
			//xxx_TexelSize是Unity为我们提供的访问xxx纹理对应的每个纹素的大小。
			//例如，一张512×512大小的纹理，该值大约为0.001953（即1/512）。
			//由于卷积需要对相邻区域内的纹理进行采样，因此我们需要利用_MainTex_TexelSize来计算各个相邻区域的纹理坐标
			uniform half4 _MainTex_TexelSize;
			fixed _EdgeOnly; //因为只需要0-1，所以用这范围
			fixed4 _EdgeColor;
			fixed4 _BackgroundColor;
			
			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv[9] : TEXCOORD0; //维数为9的纹理数组，对应了使用Sobel算子采样时需要的9个邻域纹理坐标
			};
			  
			v2f vert(appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				half2 uv = v.texcoord;
				
				//过把计算采样纹理坐标的代码从片元着色器中转移到顶点着色器中，可以减少运算，提高性能
				//由于从顶点着色器到片元着色器的插值是线性的，因此这样的转移并不会影响纹理坐标的计算结果
				//9个相邻坐标，通过[-1,0,1]
				//_MainTex_TexelSize.xy为每一小块纹身大小
				o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
				o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
				o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
				o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
				o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
				o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
				o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
				o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
				o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);
						 
				return o;
			}
			
			fixed luminance(fixed4 color) {
				return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
			}
			
			half Sobel(v2f i) {
				//水平方向和竖直方向使用的卷积核Gx 和Gy
				const half Gx[9] = {-1,  0,  1,
										-2,  0,  2,
										-1,  0,  1};
				const half Gy[9] = {-1, -2, -1,
										0,  0,  0,
										1,  2,  1};		
				
				half texColor;
				half edgeX = 0;
				half edgeY = 0;
				//依次对9个像素进行采样，计算它们的亮度值，再与卷积核Gx 和Gy 中对应的权重相乘后，叠加到各自的梯度值上
				for (int it = 0; it < 9; it++) {
					//亮度
					texColor = luminance(tex2D(_MainTex, i.uv[it]));
					edgeX += texColor * Gx[it];
					edgeY += texColor * Gy[it];
				}
				
				//从1中减去水平方向和竖直方向的梯度值的绝对值，得到edge。
				//edge值越小，表明该位置越可能是一个边缘点
				half edge = 1 - abs(edgeX) - abs(edgeY);
				
				return edge;
			}
			
			fixed4 fragSobel(v2f i) : SV_Target {
				half edge = Sobel(i);
				
				fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge);
				fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
				return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
 			}
			
			ENDCG
		} 
	}
	FallBack Off
}
