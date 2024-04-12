// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//水波效果
Shader "Unity Shaders Book/Chapter 15/Water Wave" {
	Properties {
		//_Color用于控制水面颜色
		_Color ("Main Color", Color) = (0, 0.15, 0.115, 1)
		//_MainTex是水面波纹材质纹理，默认为白色纹理
		_MainTex ("Base (RGB)", 2D) = "white" {}
		//_WaveMap是一个由噪声纹理生成的法线纹理
		_WaveMap ("Wave Map", 2D) = "bump" {}
		//_Cubemap是用于模拟反射的立方体纹理
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}
		//_WaveXSpeed和_WaveYSpeed分别用于控制法线纹理在X和Y方向上的平移速度
		_WaveXSpeed ("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01
		_WaveYSpeed ("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01
		//_Distortion则用于控制模拟折射时图像的扭曲程度
		_Distortion ("Distortion", Range(0, 100)) = 10
	}
	SubShader {
		// We must be transparent, so other objects are drawn before this one.
		//Queue设置成Transparent可以确保该物体渲染时，其他所有不透明物体都已经被渲染到屏幕上了，否则就可能无法正确得到“透过水面看到的图像”
		//水是透明所有Queue = 透明
		//因为要使用GrabPass，所以RenderType = 不透明
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
		GrabPass { "_RefractionTex" }
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _WaveMap;
			float4 _WaveMap_ST;
			samplerCUBE _Cubemap;
			fixed _WaveXSpeed;
			fixed _WaveYSpeed;
			float _Distortion;	
			//内置变量
			//使用GrabPass时，指定的纹理名称。
			//_RefractionTex_TexelSize可以让我们得到该纹理的纹素大小，例如一个大小为256×512的纹理，它的纹素大小为(1/256, 1/512)。
			//我们需要在对屏幕图像的采样坐标进行偏移时使用该变量。
			sampler2D _RefractionTex;
			float4 _RefractionTex_TexelSize;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
				float4 TtoW1 : TEXCOORD3;  
				float4 TtoW2 : TEXCOORD4; 
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				//调用ComputeGrabScreenPos来得到对应被抓取屏幕图像的采样坐标
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				//计算了_MainTex和_BumpMap的采样坐标，并把它们分别存储在一个float4类型变量的xy 和zw 分量中
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);
				
				//世界顶点坐标
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				//世界空间下副法线
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				//顶点对应的从切线空间到世界空间的变换矩阵，并把该矩阵的每一行 分别存储在TtoW0、TtoW1和TtoW2的xyz 分量中
				//得到切线空间下的3个坐标轴（x、y、z轴分别对应了切线、副切线和法线的方向）在世界空间下的表示，再把它们依次按列 组成一个变换矩阵即可。TtoW0等值的w 分量同样被利用起来，用于存储世界空间下的顶点坐标
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				//TtoW0等变量的w 分量得到世界坐标
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				//顶点世界坐标得到视角方向
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);
				
				// Get the normal in tangent space
				//并利用该值对法线纹理进行两次采样（这是为了模拟两层交叉的水面波动的效果）
				fixed3 bump1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + speed)).rgb;
				fixed3 bump2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - speed)).rgb;
				//对两次结果相加并归一化后得到切线空间下的法线方向
				fixed3 bump = normalize(bump1 + bump2);
				
				// Compute the offset in tangent space
				//_Distortion属性以及_RefractionTex_TexelSize来对屏幕图像的采样坐标进行偏移，模拟折射效果。
				//_Distortion值越大，偏移量越大，水面背后的物体看起来变形程度越大。
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
				//我们把偏移量和屏幕坐标的z 分量相乘，这是为了模拟深度越大、折射程度越大的效果。
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
				//scrPos进行了透视除法，再使用该坐标对抓取的屏幕图像_RefractionTex进行采样，得到模拟的折射颜色
				fixed3 refrCol = tex2D( _RefractionTex, i.scrPos.xy/i.scrPos.w).rgb;
				
				// Convert the normal to world space
				//法线方向从切线空间变换到了世界空间下
				//（使用变换矩阵的每一行，即TtoW0、TtoW1和TtoW2，分别和法线方向点乘，构成新的法线方向），并据此得到视角方向相对于法线方向的反射方向
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				//们也对主纹理进行了纹理动画，以模拟水波的效果
				fixed4 texColor = tex2D(_MainTex, i.uv.xy + speed);
				fixed3 reflDir = reflect(-viewDir, bump);
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb * _Color.rgb;
				//混合折射和反射颜色，我们随后计算了菲涅耳系数
				fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 4);
				fixed3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
	}
	// Do not cast shadow
	FallBack Off
}
