Shader "Unlit/S_Rough"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_NormTex("Norm", 2D) = "white" {}
		_envDiffTex("_envDiffTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _NormTex;
			float4 _NormTex_ST;
			sampler2D _envDiffTex;
			float4 _envDiffTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
#define PI 3.14159f
#include "../HLSL/TransferMath/TransferMath.hlsl"
			float3 GetEnvIrradiance_equirectangular(sampler2D tex, float3 N, bool unityDir)
			{
				N = normalize(N);
				float2 uv = EquirectangularToUV(N, unityDir);
				return tex2D(tex, uv).rgb;
			}

			float4 RotateAroundYInDegrees(float4 vertex, float degrees)
			{
				float alpha = degrees * UNITY_PI / 180.0;
				float sina, cosa;
				sincos(alpha, sina, cosa);
				float2x2 m = float2x2(cosa, -sina, sina, cosa);
				return float4(mul(m, vertex.xz), vertex.yw).xzyw;
			}

			float Gray(float3 c)
			{
				return c.r*0.3 + c.g*0.6 + c.b*0.1;
			}

            fixed4 frag (v2f i) : SV_Target
            {
                //// sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                //// apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);

				//###
				//???
				float3 aldobe = tex2D(_MainTex, i.uv).rgb;
				float a = tex2D(_NormTex, i.uv).a;

				float3 L = normalize(float3(0,0,1));
				float3 N = normalize(tex2D(_NormTex, i.uv).rgb);

				//N anim
				float4 tt = float4(N, 0);
				float T = 3;//3s ×ªÒ»ÖÜ
				tt = RotateAroundYInDegrees(tt, fmod(_Time.y,T) *(360/T));
				N = tt.rgb;

				float NdotL = max(dot(N, L), 0);

				float3 c = 0;
				{
					float3 envDiff = GetEnvIrradiance_equirectangular(_envDiffTex, N, true);
					c = envDiff * aldobe;
					c = Gray(c);
				}
				{
					//c = pow(NdotL,5)*0.5;
				}


				float3 re = c*a;
				//###
				fixed4 col = fixed4(re,1);
                return col;
            }
            ENDCG
        }
    }
}
