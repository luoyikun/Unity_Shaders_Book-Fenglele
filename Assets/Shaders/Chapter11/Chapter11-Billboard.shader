// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//广告牌
Shader "Unity Shaders Book/Chapter 11/Billboard" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {}
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		//调整是固定法线还是固定指向上的方向，即约束垂直方向的程度
		_VerticalBillboarding ("Vertical Restraints", Range(0, 1)) = 1 
	}
	SubShader {
		// Need to disable batching because of the vertex animation
		//批处理会合并所有相关的模型，而这些模型各自的模型空间就会被丢失。
		//而在广告牌技术中，我们需要使用物体的模型空间下的位置来作为锚点进行计算
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}
		
		Pass { 
			Tags { "LightMode"="ForwardBase" }
			
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			//关闭遮挡剔除，广告牌的每个面都能显示
			Cull Off
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed _VerticalBillboarding;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert (a2v v) {
				v2f o;
				
				// Suppose the center in object space is fixed
				//模型空间的原点作为广告牌的锚点
				float3 center = float3(0, 0, 0);
				//模型空间下的视角方向
				float3 viewer = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos, 1));
				
				float3 normalDir = viewer - center;
				// If _VerticalBillboarding equals 1, we use the desired view dir as the normal dir
				// Which means the normal dir is fixed
				// Or if _VerticalBillboarding equals 0, the y of normal is 0
				// Which means the up dir is fixed
				//当_VerticalBillboarding为1时，意味着法线方向固定为视角方向；
				//当_VerticalBillboarding为0时，意味着向上方向固定为(0, 1, 0)
				normalDir.y =normalDir.y * _VerticalBillboarding;
				//需要对计算得到的法线方向进行归一化操作来得到单位矢量
				normalDir = normalize(normalDir);
				// Get the approximate up dir
				// If normal dir is already towards up, then the up dir is towards front
				//为了防止法线方向和向上方向平行（如果平行，那么叉积得到的结果将是错误的），
				//我们对法线方向的y 分量进行判断，以得到合适的向上方向。
				float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
				//根据法线方向和粗略的向上方向得到向右方向，并对结果进行归一化
				float3 rightDir = normalize(cross(upDir, normalDir));
				//由于此时向上的方向还是不准确的，我们又根据准确的法线方向和向右方向得到最后的向上方向
				upDir = normalize(cross(normalDir, rightDir));
				
				// Use the three vectors to rotate the quad
				float3 centerOffs = v.vertex.xyz - center;
				//新的顶点位置，模型空间顶点方向
				float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;

				//通过计算到的变换后的三个基向量，组装为模型空间顶点到变换后的模型空间顶点的变换矩阵
                // float3x3 obj2TransObj = {
                //     rightDir.x, upDir.x, normalDir.x,
                //     rightDir.y, upDir.y, normalDir.y,
                //     rightDir.z, upDir.z, normalDir.z,
                // };
                // //计算变换后的模型空间顶点
                // float3 localPos = mul(obj2TransObj, v.vertex);

                //模型空间下顶点转裁剪空间
				o.pos = UnityObjectToClipPos(float4(localPos, 1));
				o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = tex2D (_MainTex, i.uv);
				c.rgb *= _Color.rgb;
				
				return c;
			}
			
			ENDCG
		}
	} 
	FallBack "Transparent/VertexLit"
}
