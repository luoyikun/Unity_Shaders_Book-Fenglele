// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//卡通渲染
Shader "Unity Shaders Book/Chapter 14/Toon Shading" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		//_Ramp是用于控制漫反射色调的渐变纹理
		_Ramp ("Ramp Texture", 2D) = "white" {}
		//_Outline用于控制轮廓线宽度
		_Outline ("Outline", Range(0, 1)) = 0.1
		//描边颜色
		_OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
		//高光反射颜色
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		//高光反射时使用的阈值
		_SpecularScale ("Specular Scale", Range(0, 0.1)) = 0.01
	}
    SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		Pass {
			//Pass的NAME必须全大写
			NAME "OUTLINE"
			//正面的三角面片剔除，而只渲染背面
			Cull Front
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			float _Outline;
			fixed4 _OutlineColor;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			}; 
			
			struct v2f {
				//SV_POSITION 裁剪空间下顶点坐标
			    float4 pos : SV_POSITION;
			};
			
			v2f vert (a2v v) {
				v2f o;
				//顶点变换到视角空间下
				float4 pos = mul(UNITY_MATRIX_MV, v.vertex); 
				//法线变换到视角空间下
				float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);  
				//设置法线的z 分量，对其归一化后再将顶点沿其方向扩张，得到扩张后的顶点坐标。
				//对法线的处理是为了尽可能避免背面扩张后的顶点挡住正面的面片。
				normal.z = -0.5;
				pos = pos + float4(normalize(normal), 0) * _Outline;
				//顶点从视角空间变换到裁剪空间
				o.pos = mul(UNITY_MATRIX_P, pos);
				
				return o;
			}
			
			float4 frag(v2f i) : SV_Target { 
				//用轮廓线颜色渲染整个背面
				return float4(_OutlineColor.rgb, 1);               
			}
			
			ENDCG
		}
		
		Pass {
			//LightMode设置为ForwardBase，并且使用#pragma语句设置了编译指令，这些都是为了让Shader中的光照变量可以被正确赋值。
			Tags { "LightMode"="ForwardBase" }
			
			//裁剪掉背面
			Cull Back
		
			CGPROGRAM
		
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_fwdbase
		
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Ramp;
			fixed4 _Specular;
			fixed _SpecularScale;
		
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;//
				float4 tangent : TANGENT;
			}; 
		
			struct v2f {
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;//除了纹理坐标，TEXCOORD0 也可以用于传递其他自定义数据，比如法线、颜色等。这样可以在顶点着色器中计算或处理这些数据，然后将结果传递给片段着色器进行进一步处理或渲染。
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};
			
			v2f vert (a2v v) {
				v2f o;
				
				o.pos = UnityObjectToClipPos( v.vertex);
				o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
				//世界空间下法线
				o.worldNormal  = UnityObjectToWorldNormal(v.normal);
				//世界空间下顶点
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				//阴影
				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			float4 frag(v2f i) : SV_Target { 
				//光照模型中需要的各个方向矢量，并对它们进行了归一化处理
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
				
				fixed4 c = tex2D (_MainTex, i.uv);
				//材质的反射率albedo
				fixed3 albedo = c.rgb * _Color.rgb;
				//环境光照ambient
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				//UNITY_LIGHT_ ATTENUATION宏来计算当前世界坐标下的阴影值
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				//半兰伯特漫反射系数
				fixed diff =  dot(worldNormal, worldLightDir);
				//阴影值相乘得到最终的漫反射系数
				diff = (diff * 0.5 + 0.5) * atten;
				//漫反射系数对渐变纹理_Ramp进行采样，并将结果和材质的反射率、光照颜色相乘，作为最后的漫反射光照
				fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;
				
				fixed spec = dot(worldNormal, worldHalfDir);
				fixed w = fwidth(spec) * 2.0;
				//使用fwidth对高光区域的边界进行抗锯齿处理，并将计算而得的高光反射系数和高光反射颜色相乘，得到高光反射的光照部分
				//使用了step(0.000 1, _SpecularScale)，这是为了在_SpecularScale为0时，可以完全消除高光反射的光照
				fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);
				//返回环境光照、漫反射光照和高光反射光照叠加的结果
				return fixed4(ambient + diffuse + specular, 1.0);
			}
		
			ENDCG
		}
	}
	FallBack "Diffuse"
}
