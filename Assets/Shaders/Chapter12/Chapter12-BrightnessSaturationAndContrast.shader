// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//调整屏幕的亮度、饱和度和对比度
Shader "Unity Shaders Book/Chapter 12/Brightness Saturation And Contrast" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Brightness ("Brightness", Float) = 1
		_Saturation("Saturation", Float) = 1
		_Contrast("Contrast", Float) = 1
	}
	SubShader {
		Pass {  
			//屏幕后处理标配
			//屏幕后处理实际上是在场景中绘制了一个与屏幕同宽同高的四边形面片
			//关闭了深度写入，是为了防止它“挡住”在其后面被渲染的物体。
			//例如，如果当前的OnRenderImage函数在所有不透明的Pass执行完毕后立即被调用，不关闭深度写入就会影响后面透明的Pass的渲染
			ZTest Always 
			Cull Off 
			ZWrite Off
			
			CGPROGRAM  
			#pragma vertex vert  
			#pragma fragment frag  
			  
			#include "UnityCG.cginc"  
			  
			sampler2D _MainTex;  
			half _Brightness;
			half _Saturation;
			half _Contrast;
			  
			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv: TEXCOORD0;
			};
			  
			v2f vert(appdata_img v) {
				v2f o;
				
				o.pos = UnityObjectToClipPos(v.vertex);
				
				//使用的是Sprite Renderer，不需要手动对UV进行转换
				o.uv = v.texcoord;
						 
				return o;
			}
		
			fixed4 frag(v2f i) : SV_Target {
				fixed4 renderTex = tex2D(_MainTex, i.uv);  
				  
				// Apply brightness
				//亮度 = 原颜色 * 亮度系数_Brightness
				fixed3 finalColor = renderTex.rgb * _Brightness;
				
				// Apply saturation
				//亮度值，通过对每个颜色分量乘以一个特定的系数再相加得到的
				fixed luminance = 0.2125 * renderTex.r + 0.7154 * renderTex.g + 0.0721 * renderTex.b;
				//使用该亮度值创建了一个饱和度为0的颜色值
				fixed3 luminanceColor = fixed3(luminance, luminance, luminance);
				//Saturation属性在其和上一步得到的颜色之间进行插值，从而得到希望的饱和度颜色
				finalColor = lerp(luminanceColor, finalColor, _Saturation);
				
				// Apply contrast
				//对比度为0的颜色值（各分量均为0.5）
				fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
				//使用_Contrast属性在其和上一步得到的颜色之间进行插值
				finalColor = lerp(avgColor, finalColor, _Contrast);
				
				return fixed4(finalColor, renderTex.a);  
			}  
			  
			ENDCG
		}  
	}
	
	Fallback Off
}
