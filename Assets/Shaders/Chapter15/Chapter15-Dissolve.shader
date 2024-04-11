// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//消融
Shader "Unity Shaders Book/Chapter 15/Dissolve" {
	Properties {
		//_BurnAmount属性用于控制消融程度，当值为0时，物体为正常效果，当值为1时，物体会完全消融
		_BurnAmount ("Burn Amount", Range(0.0, 1.0)) = 0.0
		//_LineWidth属性用于控制模拟烧焦效果时的线宽，它的值越大，火焰边缘的蔓延范围越广。
		_LineWidth("Burn Line Width", Range(0.0, 0.2)) = 0.1
		//漫反射纹理
		_MainTex ("Base (RGB)", 2D) = "white" {}
		//法线纹理
		_BumpMap ("Normal Map", 2D) = "bump" {}
		//火焰边缘的两种颜色值
		_BurnFirstColor("Burn First Color", Color) = (1, 0, 0, 1)
		_BurnSecondColor("Burn Second Color", Color) = (1, 0, 0, 1)
		//噪声纹理
		_BurnMap("Burn Map", 2D) = "white"{}
	}
	SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			//模型的正面和背面都会被渲染。这是因为，消融会导致裸露模型内部的构造，如果只渲染正面会出现错误的结果
			Cull Off
			
			CGPROGRAM
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed _BurnAmount;
			fixed _LineWidth;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			fixed4 _BurnFirstColor;
			fixed4 _BurnSecondColor;
			sampler2D _BurnMap;
			
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			float4 _BurnMap_ST;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uvMainTex : TEXCOORD0;
				float2 uvBumpMap : TEXCOORD1;
				float2 uvBurnMap : TEXCOORD2;
				float3 lightDir : TEXCOORD3;
				float3 worldPos : TEXCOORD4;
				SHADOW_COORDS(5)
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				//使用宏TRANSFORM_TEX计算了三张纹理对应的纹理坐标
				o.uvMainTex = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uvBumpMap = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				//法线贴图中的法线是相对于切线空间进行旋转和变换的
				TANGENT_SPACE_ROTATION;
				//再把光源方向从模型空间变换到了切线空间
  				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
  				//顶点的世界坐标
  				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
  				//阴影纹理的采样坐标
  				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				//对噪声纹理进行采样
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				//采样结果和用于控制消融程度的属性_BurnAmount相减，传递给clip函数。当结果小于0时，该像素将会被剔除，从而不会显示到屏幕上
				clip(burn.r - _BurnAmount);
				
				float3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uvBumpMap));
				//根据漫反射纹理得到材质的反射率albedo
				fixed3 albedo = tex2D(_MainTex, i.uvMainTex).rgb;
				//环境光照
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				//漫反射光照
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

				//宽度为_LineWidth的范围内模拟一个烧焦的颜色变化，第一步就使用了smoothstep函数来计算混合系数t 。
				//当t 值为1时，表明该像素位于消融的边界处，当t 值为0时，表明该像素为正常的模型颜色，而中间的插值则表示需要模拟一个烧焦效果。
				fixed t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);
				//t 来混合两种火焰颜色_BurnFirstColor和_BurnSecondColor
				fixed3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
				//为了让效果更接近烧焦的痕迹，我们还使用pow函数对结果进行处理
				burnColor = pow(burnColor, 5);
				//光源的衰减效果,最终返回atten
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				//再次使用t 来混合正常的光照颜色（环境光+漫反射）和烧焦颜色,又使用了step函数来保证当_BurnAmount为0时，不显示任何消融效果
				fixed3 finalColor = lerp(ambient + diffuse * atten, burnColor, t * step(0.0001, _BurnAmount));
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
		//使用透明度测试的物体的阴影需要特别处理，如果仍然使用普通的阴影Pass，那么被剔除的区域仍然会向其他物体投射阴影，造成“穿帮”。
		//Pass to render object as a shadow caster
		Pass {
			//投射阴影的Pass的LightMode需要被设置为ShadowCaster
			Tags { "LightMode" = "ShadowCaster" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			//需要使用#pragma multi_compile_shadowcaster指明它需要的编译指令。
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"
			
			fixed _BurnAmount;
			sampler2D _BurnMap;
			float4 _BurnMap_ST;
			
			struct v2f {
				//利用V2F_SHADOW_CASTER来定义阴影投射需要定义的变量
				V2F_SHADOW_CASTER;
				float2 uvBurnMap : TEXCOORD1;
			};
			
			v2f vert(appdata_base v) {
				v2f o;
				//TRANSFER_SHADOW_CASTER_NORMALOFFSET来填充V2F_SHADOW_ CASTER在背后声明的一些变量
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				//使用噪声纹理的采样结果来剔除片元
				clip(burn.r - _BurnAmount);
				//SHADOW_CASTER_FRAGMENT来让Unity为我们完成阴影投射的部分，把结果输出到深度图和阴影映射纹理中
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
