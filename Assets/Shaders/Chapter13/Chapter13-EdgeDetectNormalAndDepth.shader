// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//边缘检测使用深度与法线
Shader "Unity Shaders Book/Chapter 13/Edge Detection Normals And Depth"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" { }
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
        _SampleDistance ("Sample Distance", Float) = 1.0
        //xy分量分别对应了法线和深度的检测灵敏度，zw分量则没有实际用途
        _Sensitivity ("Sensitivity", Vector) = (1, 1, 1, 1)
    }
    SubShader
    {
        CGINCLUDE
        
        #include "UnityCG.cginc"
        //声明纹理采样器
        sampler2D _MainTex;
        //内置变量格式_TexelSize 需要对邻域像素进行纹理采样，所以还声明了存储纹素大小的变量
        half4 _MainTex_TexelSize;
        fixed _EdgeOnly;
        fixed4 _EdgeColor;
        fixed4 _BackgroundColor;
        float _SampleDistance;
        half4 _Sensitivity;
        //内置变量，深度+法线纹理
        sampler2D _CameraDepthNormalsTexture;
        
        struct v2f
        {
            float4 pos : SV_POSITION;
            //维数为5的纹理坐标数组
            //第一个坐标存储了屏幕颜色图像的采样纹理
            //数组中剩余的4个坐标则存储了使用Roberts算子时需要采样的纹理坐标
            half2 uv[5] : TEXCOORD0;
        };
        
        v2f vert(appdata_img v)
        {
            v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            
            half2 uv = v.texcoord;
            o.uv[0] = uv;
            
            #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0)
                    uv.y = 1 - uv.y;
            #endif
            
            //通过把计算采样纹理坐标的代码从片元着色器中转移到顶点着色器中，可以减少运算，提高性能。
            //由于从顶点着色器到片元着色器的插值是线性的，因此这样的转移并不会影响纹理坐标的计算结果。
            o.uv[1] = uv + _MainTex_TexelSize.xy * half2(1, 1) * _SampleDistance;
            o.uv[2] = uv + _MainTex_TexelSize.xy * half2(-1, -1) * _SampleDistance;
            o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 1) * _SampleDistance;
            o.uv[4] = uv + _MainTex_TexelSize.xy * half2(1, -1) * _SampleDistance;
            
            return o;
        }
        
        //CheckSame函数的返回值要么是0，要么是1，返回0时表明这两点之间存在一条边界，反之则返回1
        half CheckSame(half4 center, half4 sample)
        {
            //得到两个采样点的法线和深度值

            //并没有解码得到真正的法线值，而是直接使用了xy 分量。
            //这是因为我们只需要比较两个采样值之间的差异度，而并不需要知道它们真正的法线值
			//sample1.xy 不是直接代表法线分量，而是包含了编码后的法线信息
            half2 centerNormal = center.xy;
			//两个通道解码成一个浮点数
            float centerDepth = DecodeFloatRG(center.zw);
            half2 sampleNormal = sample.xy;
            float sampleDepth = DecodeFloatRG(sample.zw);
            
            // difference in normals
            // do not bother decoding normals - there's no need here
            //把两个采样点的对应值相减并取绝对值，再乘以灵敏度参数，把差异值的每个分量相加再和一个阈值比较，
            //如果它们的和小于阈值，则返回1，说明差异不明显，不存在一条边界；否则返回0。
            half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x;
            int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1; //判断法相x，y差异
            // difference in depth
            float diffDepth = abs(centerDepth - sampleDepth) * _Sensitivity.y;
            // scale the required threshold by the distance
            int isSameDepth = diffDepth < 0.1 * centerDepth; //判断深度差异
            
            // return:
            // 1 - if normals and depth are similar enough 
            // 0 - otherwise
            return isSameNormal * isSameDepth ? 1.0 : 0.0;
        }
        
        fixed4 fragRobertsCrossDepthAndNormal(v2f i) : SV_Target
        {
            //4个纹理坐标对深度+法线纹理进行采样
            half4 sample1 = tex2D(_CameraDepthNormalsTexture, i.uv[1]);
            half4 sample2 = tex2D(_CameraDepthNormalsTexture, i.uv[2]);
            half4 sample3 = tex2D(_CameraDepthNormalsTexture, i.uv[3]);
            half4 sample4 = tex2D(_CameraDepthNormalsTexture, i.uv[4]);
            
            half edge = 1.0;
            //再调用CheckSame函数来分别计算对角线上两个纹理值的差值
            edge *= CheckSame(sample1, sample2);
            edge *= CheckSame(sample3, sample4);
            
            fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[0]), edge);
            fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
            
            return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
        }
        
        ENDCG
        
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment fragRobertsCrossDepthAndNormal
            
            ENDCG
        }
    }
    FallBack Off
}
