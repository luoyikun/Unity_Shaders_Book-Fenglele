// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//逐顶点高光
Shader "Unity Shaders Book/Chapter 6/Specular Vertex-Level" {
	Properties {
		//漫反射颜色
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		//控制材质的高光反射颜色
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		//控制高光区域的大小
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}
	SubShader {
		Pass { 
			//只有定义了正确的LightMode，我们才能得到一些Unity的内置光照变量，例如_LightColor0
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION; //模型空间下顶点坐标
				float3 normal : NORMAL; // 模型空间下法线
			};
			
			struct v2f {
				float4 pos : SV_POSITION; //裁剪空间下顶点坐标
				fixed3 color : COLOR;  //顶点着色器输出颜色
			};
			
			v2f vert(a2v v) {
				v2f o;
				// Transform the vertex from object space to projection space
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// Get ambient term
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// Transform the normal from object space to world space
				fixed3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
				// Get the light direction in world space
				//_WorldSpaceLightPos0 为世界空间原点指向方向光的方向
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				
				// Compute diffuse term
				//计算出漫反射部分
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));
				
				// Get the reflect direction in world space
				//入射光线方向关于表面法线的反射方向
				//由于Cg的reflect函数的入射方向要求是由光源指向交点处的，因此我们需要对worldLightDir取反后再传给reflect函数
				fixed3 reflectDir = normalize(reflect(-worldLightDir, worldNormal));
				// Get the view direction in world space
				//世界坐标下的视角方向，由模型顶点指向摄像机
				// mul(unity_ObjectToWorld, v.vertex).xyz 模型空间转为世界空间下的顶点坐标。
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, v.vertex).xyz);
				
				// Compute specular term
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);
				
				o.color = ambient + diffuse + specular;
							 	
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				return fixed4(i.color, 1.0);
			}
			
			ENDCG
		}
	} 
	FallBack "Specular"
}
