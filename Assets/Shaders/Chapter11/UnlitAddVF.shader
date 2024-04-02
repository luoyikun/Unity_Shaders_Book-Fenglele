// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "PengLu/Billboard/UnlitAddVF" {
 
Properties {
	_MainTex ("Base texture", 2D) = "white" {}
	_VerticalBillboarding("Vertical Restraints", Range(0,1)) = 1
}
 
	
SubShader {
	
	
	Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
	Pass {
	Blend SrcAlpha OneMinusSrcAlpha
	Cull Off 
    ZWrite Off 
	
	
	CGPROGRAM	

    #pragma vertex vert
    #pragma fragment frag

	#include "UnityCG.cginc"
    #include "Lighting.cginc"

	sampler2D _MainTex;
    float4 _MainTex_ST;
	float _VerticalBillboarding;
 
    struct a2v {
        float4 vertex : POSITION;
        float4 texcoord : TEXCOORD0;
        fixed4 color : COLOR;
        float3 normal : NORMAL;

    };

	struct v2f {
		float4	pos	: SV_POSITION;
		float2	uv	: TEXCOORD0;
	};
 
	void CalcOrthonormalBasis(float3 dir,out float3 right,out float3 up)
	{
		up    = abs(dir.y) > 0.999f ? float3(0,0,1) : float3(0,1,0);		
		right = normalize(cross(up,dir));		
		up    = cross(dir,right);	
	}

	v2f vert (a2v v)
	{
		v2f o;
			
		float3	centerOffs  = float3(float(0.5).xx - v.color.rg,0) * v.texcoord.xyy;
		//float3	centerOffs  = float3(float(0.5).xx - v.color.rg,0) * v.color.bbb*256;
		float3	centerLocal = v.vertex.xyz + centerOffs.xyz;
		float3	viewerLocal = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));			
		float3	localDir    = viewerLocal - centerLocal;
				
		localDir.y =localDir.y * _VerticalBillboarding;
		
		float3	rightLocal;
		float3	upLocal;
		UNITY_FOG_COORDS
		CalcOrthonormalBasis(normalize(localDir) ,rightLocal,upLocal);
 
		float3	BBNormal   = rightLocal * v.normal.x + upLocal * v.normal.y;
		float3	BBLocalPos = centerLocal - (rightLocal * centerOffs.x + upLocal * centerOffs.y);	
		o.uv    = v.texcoord.xy;
		o.pos   = UnityObjectToClipPos(float4(BBLocalPos,1));
						
		return o;
	}

    fixed4 frag (v2f i) : SV_Target 
    {
        fixed4 c = tex2D (_MainTex, i.uv);
        
        return c;
	}

	ENDCG
}
}
    FallBack "Transparent/VertexLit"
}
