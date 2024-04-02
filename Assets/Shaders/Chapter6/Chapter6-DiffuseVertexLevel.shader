// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//逐顶点光照
Shader "Unity Shaders Book/Chapter 6/Diffuse Vertex-Level" {
	Properties {
		//顶点漫反射颜色
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1) 
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
		//与属性相匹配的变量
			fixed4 _Diffuse; 
			
			struct a2v {
				//POSITION语义，模型空间下顶点坐标
				float4 vertex : POSITION;
				//NORMAL语义来告诉Unity要把模型顶点的法线信息存储到normal变量
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				//把在顶点着色器中计算得到的光照颜色传递给片元着色器,也可以是TEXCOORD0
				fixed3 color : COLOR; 
			};
			
			//逐顶点着色器中计算光照
			v2f vert(a2v v) {
				v2f o; //顶点着色器最基本的任务就是把顶点位置从模型空间转换到裁剪空间
				// Transform the vertex from object space to projection space
				// 顶点位置从模型空间转换到裁剪空间
				//老版本使用mul(UNITY_MATRIX_MVP, v.vertex)
				o.pos = UnityObjectToClipPos(v.vertex); 
				
				// Get ambient term
				//环境光，内置变量UNITY_LIGHTMODEL_AMBIENT得到了环境光部分
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// Transform the normal from object space to world space
				//模型空间下法线转换为世界空间下法线。
				//模型空间到世界空间的变换矩阵的逆矩阵_World2Object，
				//然后通过调换它在mul函数中的位置，得到和转置矩阵相同的矩阵乘法。
				//由于法线是一个三维矢量，因此我们只需要截取_World2Object的前三行前三列即可
				fixed3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
				// Get the light direction in world space
				//光源方向可以由_WorldSpaceLightPos0，如果只有一个光且是平行光可以使用
				fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
				// Compute diffuse term
				//在得到了世界空间中的法线和光源方向后，我们需要对它们进行归一化操作。
				//在得到它们点积的结果后，我们需要防止这个结果为负值。为此，我们使用了saturate函数。
				//saturate函数是Cg提供的一种函数，它的作用是可以把参数截取到[0, 1]的范围内。
				//最后，再与光源的颜色和强度以及材质的漫反射颜色相乘即可得到最终的漫反射光照部分
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));
				
				//环境光和漫反射光部分相加，得到最终的光照结果
				o.color = ambient + diffuse;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				return fixed4(i.color, 1.0);
			}
			
			ENDCG
		}
	}
	FallBack "Diffuse"
}
