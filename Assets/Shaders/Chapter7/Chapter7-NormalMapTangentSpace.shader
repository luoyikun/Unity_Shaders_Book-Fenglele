// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 7/Normal Map In Tangent Space" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		//（隆起）法线纹理_BumpMap，
		//我们使用"bump"作为它的默认值。
		//"bump"是Unity内置的法线纹理，当没有提供任何法线纹理时，"bump"就对应了模型自带的法线信息
		_BumpMap ("Normal Map", 2D) = "bump" {}
		//用于控制凹凸程度的，当它为0时，意味着该法线纹理不会对光照产生任何影响
		_BumpScale ("Bump Scale", Float) = 1.0
		_Specular ("Specular", Color) = (1, 1, 1, 1) //镜面
		_Gloss ("Gloss", Range(8.0, 256)) = 20 //光滑
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			//每个纹理都需要Name_ST,为了得到平铺和偏移系数
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float _BumpScale;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;//模型空间下顶点坐标
				float3 normal : NORMAL; //模型空间下法线
				//告诉Unity把顶点的切线方向填充到tangent变量中
				//tangent的类型是float4，需要使用tangent.w分量来决定切线空间中的第三个坐标轴——副切线的方向性
				float4 tangent : TANGENT; 
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 lightDir: TEXCOORD1;//切线空间下光线方向
				float3 viewDir : TEXCOORD2;//切线空间下视角方向
			};

			// Unity doesn't support the 'inverse' function in native shader
			// so we write one by our own
			// Note: this function is just a demonstration, not too confident on the math or the speed
			// Reference: http://answers.unity3d.com/questions/218333/shader-inversefloat4x4-function.html
			float4x4 inverse(float4x4 input) {
				#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
				
				float4x4 cofactors = float4x4(
				     minor(_22_23_24, _32_33_34, _42_43_44), 
				    -minor(_21_23_24, _31_33_34, _41_43_44),
				     minor(_21_22_24, _31_32_34, _41_42_44),
				    -minor(_21_22_23, _31_32_33, _41_42_43),
				    
				    -minor(_12_13_14, _32_33_34, _42_43_44),
				     minor(_11_13_14, _31_33_34, _41_43_44),
				    -minor(_11_12_14, _31_32_34, _41_42_44),
				     minor(_11_12_13, _31_32_33, _41_42_43),
				    
				     minor(_12_13_14, _22_23_24, _42_43_44),
				    -minor(_11_13_14, _21_23_24, _41_43_44),
				     minor(_11_12_14, _21_22_24, _41_42_44),
				    -minor(_11_12_13, _21_22_23, _41_42_43),
				    
				    -minor(_12_13_14, _22_23_24, _32_33_34),
				     minor(_11_13_14, _21_23_24, _31_33_34),
				    -minor(_11_12_14, _21_22_24, _31_32_34),
				     minor(_11_12_13, _21_22_23, _31_32_33)
				);
				#undef minor
				return transpose(cofactors) / determinant(input);
			}

			v2f vert(a2v v) {
				v2f o;
				//固定格式，模型空间下顶点转投影空间
				o.pos = UnityObjectToClipPos(v.vertex);
				
				//uv.xy 为普通纹理的uv值
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				//uv.zw 为法线纹理uv值
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				///
				/// Note that the code below can handle both uniform and non-uniform scales
				///

				// Construct a matrix that transforms a point/vector from tangent space to world space
				//模型空间下法线转世界坐标
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				//模型空间下切线转世界坐标
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz); 
				//世界空间下副法线：根据定义得到由法线，切线*向内向外
				//v.tangent.w和叉积结果进行相乘，这是因为和切线与法线方向都垂直的方向有两个，而w决定了我们选择其中哪一个方向
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 

				/*
				float4x4 tangentToWorld = float4x4(worldTangent.x, worldBinormal.x, worldNormal.x, 0.0,
												   worldTangent.y, worldBinormal.y, worldNormal.y, 0.0,
												   worldTangent.z, worldBinormal.z, worldNormal.z, 0.0,
												   0.0, 0.0, 0.0, 1.0);
				// The matrix that transforms from world space to tangent space is inverse of tangentToWorld
				float3x3 worldToTangent = inverse(tangentToWorld);
				*/
				
				//wToT = the inverse of tToW = the transpose of tToW as long as tToW is an orthogonal matrix.
				//
				float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

				// Transform the light and view dir from world space to tangent space
				//切线空间下光线方向
				o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
				//切线空间下视角方向
				o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));

				///
				/// Note that the code below can only handle uniform scales, not including non-uniform scales
				/// 

				// Compute the binormal
//				float3 binormal = cross( normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w;
//				// Construct a matrix which transform vectors from object space to tangent space
//				float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
				// Or just use the built-in macro
//				TANGENT_SPACE_ROTATION;
//				
//				// Transform the light direction from object space to tangent space
//				o.lightDir = mul(rotation, normalize(ObjSpaceLightDir(v.vertex))).xyz;
//				// Transform the view direction from object space to tangent space
//				o.viewDir = mul(rotation, normalize(ObjSpaceViewDir(v.vertex))).xyz;
				
				return o;
			}
			
			//采样得到切线空间下的法线方向，再在切线空间下进行光照计算
			fixed4 frag(v2f i) : SV_Target {				
				fixed3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentViewDir = normalize(i.viewDir);
				
				// Get the texel in the normal map
				// 法线图的纹素值
				fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
				fixed3 tangentNormal;
				// If the texture is not marked as "Normal map"
//				tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;
//				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				
				// Or mark the texture as "Normal map", and use the built-in funciton
				//如果没把法线贴图设置为Normal map，所以通过代码反映射回来
				tangentNormal = UnpackNormal(packedNormal);
				//_BumpScale（控制凹凸程度）来得到tangentNormal的xy分量
				tangentNormal.xy *= _BumpScale;
				//由于法线都是单位矢量，因此tangentNormal.z分量可以由tangentNormal.xy计算而得。
				//由于我们使用的是切线空间下的法线纹理，因此可以保证法线方向的z分量为正
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				
				//反射率，采用主纹理
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				//环境光 = 
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

				fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}
			
			ENDCG
		}
	} 
	FallBack "Specular"
}
