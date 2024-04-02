// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//玻璃折射
Shader "Unity Shaders Book/Chapter 10/Glass Refraction" {
	Properties {
		//玻璃的材质纹理，默认为白色纹理
		_MainTex ("Main Tex", 2D) = "white" {}
		//玻璃的法线纹理
		_BumpMap ("Normal Map", 2D) = "bump" {}
		//模拟反射的环境纹理
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}
		//控制模拟折射时图像的扭曲程度
		_Distortion ("Distortion", Range(0, 100)) = 10
		//控制折射程度，当_RefractAmount值为0时，该玻璃只包含反射效果，当_RefractAmount值为1时，该玻璃只包括折射效果
		_RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0
	}
	SubShader {
		// We must be transparent, so other objects are drawn before this one.
		//Queue设置成Transparent可以确保该物体渲染时，
		//其他所有不透明物体都已经被渲染到屏幕上了，否则就可能无法正确得到“透过玻璃看到的图像”
		//设置RenderType则是为了在使用着色器替换（Shader Replacement）时，该物体可以在需要时被正确渲染。
		//这通常发生在我们需要得到摄像机的深度和法线纹理时
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
		//关键词GrabPass定义了一个抓取屏幕图像的Pass
		//Pass中我们定义了一个字符串，该字符串内部的名称决定了抓取得到的屏幕图像将会被存入哪个纹理中
		GrabPass { "_RefractionTex" }
		
		Pass {		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			samplerCUBE _Cubemap;
			float _Distortion;
			fixed _RefractAmount;
			//在使用GrabPass时指定的纹理名称
			sampler2D _RefractionTex;
			//得到该纹理的纹素大小，
			//例如一个大小为256×512的纹理，它的纹素大小为(1/256, 1/512)。
			//我们需要在对屏幕图像的采样坐标进行偏移时使用该变量
			float4 _RefractionTex_TexelSize;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float2 texcoord: TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
			    float4 TtoW1 : TEXCOORD3;  
			    float4 TtoW2 : TEXCOORD4; 
			};
			
			v2f vert (a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				//得到对应被抓取的屏幕图像的采样坐标
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				//_MainTex和_BumpMap的采样坐标，并把它们分别存储在一个float4类型变量的xy和zw分量中
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
				
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				//世界坐标下副法线
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				//由于我们需要在片元着色器中把法线方向从切线空间（由法线纹理采样得到）变换到世界空间下，以便对Cubemap进行采样，
				//因此，我们需要在这里计算该顶点对应的从切线空间到世界空间的变换矩阵，
				//并把该矩阵的每一行分别存储在TtoW0、TtoW1和TtoW2的xyz分量中
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target {		
				//TtoW0等变量的w分量得到世界坐标
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				//该片元对应的视角方向
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				// Get the normal in tangent space
				//切线空间下的法线方向
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));	
				
				// Compute the offset in tangent space
				//bump值和_Distortion属性以及_RefractionTex_TexelSize来对屏幕图像的采样坐标进行偏移，模拟折射效果。
				//_Distortion值越大，偏移量越大，玻璃背后的物体看起来变形程度越大
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
				
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
				//透视除法得到真正的屏幕坐标
				//再使用该坐标对抓取的屏幕图像_RefractionTex进行采样，得到模拟的折射颜色
				fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy/i.scrPos.w).rgb;
				
				// Convert the normal to world space
				//法线方向从切线空间变换到了世界空间下
				//（使用变换矩阵的每一行，即TtoW0、TtoW1和TtoW2，分别和法线方向点乘，构成新的法线方向）
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				//反射方向
				fixed3 reflDir = reflect(-worldViewDir, bump);
				fixed4 texColor = tex2D(_MainTex, i.uv.xy);
				//反射颜色。使用反射方向对Cubemap进行采样，并把结果和主纹理颜色相乘后得到反射颜色
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb;
				//反射，折射颜色混合
				fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
	}
	
	FallBack "Diffuse"
}
