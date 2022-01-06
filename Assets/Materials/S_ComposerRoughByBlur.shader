Shader "Unlit/S_ComposerRoughByGrey"
{
    Properties
    {
		_brdfLUT("Texture", 2D) = "white" {}
        _MainTex ("Texture", 2D) = "white" {}
		_NormTex("Norm", 2D) = "white" {}
		_envDiffTex("_envDiffTex", 2D) = "white" {}
		_envRefTex("_envRefTex", 2D) = "white" {}
		_envSpecTex2DArr("_envSpecTex2DArr", 2DArray) = "white" {}
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
				//float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _NormTex;
			float4 _NormTex_ST;
			sampler2D _envDiffTex;
			float4 _envDiffTex_ST;
			sampler2D _envRefTex;
			float4 _envRefTex_ST;
			sampler2D _brdfLUT;
			float4 _brdfLUT_ST;

			Texture2DArray _envSpecTex2DArr;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				//float3 N = v.normal;
				//o.normal = N;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
#define PI 3.14159f
#include "../HLSL/TransferMath/TransferMath.hlsl"
			bool NearZero(float x)
			{
				return abs(x) < 0.000001f;
			}


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

			float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
			{
				float3 tt = 1.0 - roughness;
				return F0 + (max(tt, F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}

			SamplerState my_point_repeat_sampler;
			float3 IBLBakeSpecMip(Texture2DArray envSpecTex2DArr, float3 dir, float texInx, bool unityDir)
			{
				dir = normalize(dir);
				float2 uv = EquirectangularToUV(dir, unityDir);
				return envSpecTex2DArr.SampleLevel(my_point_repeat_sampler, float3(uv, texInx), 0).rgb;
			}

			float3 IBLBakeSpecMipByRoughness(Texture2DArray _envSpecTex2DArr, float3 dir, float roughness, float maxInx, bool unityDir)
			{
				float inx = roughness * maxInx;
				float fpart = frac(inx);
				if (NearZero(fpart))
				{
					return IBLBakeSpecMip(_envSpecTex2DArr, dir, inx, unityDir);
				}
				else
				{
					int inx1 = floor(inx);
					int inx2 = ceil(inx);
					float3 re1 = IBLBakeSpecMip(_envSpecTex2DArr, dir, inx1, unityDir);
					float3 re2 = IBLBakeSpecMip(_envSpecTex2DArr, dir, inx2, unityDir);
					return lerp(re1, re2, inx);
				}
			}

			float sigmoid(float x)
			{
				return 1 / (1 + exp(-x));
			}


			fixed4 frag(v2f i) : SV_Target
			{
				//// sample the texture
				//fixed4 col = tex2D(_MainTex, i.uv);
				//// apply fog
				//UNITY_APPLY_FOG(i.fogCoord, col);

				//###
				//???
				float3 albedo = tex2D(_MainTex, i.uv).rgb;
				float a = tex2D(_NormTex, i.uv).a;

				float3 L = normalize(float3(1,1,1));
				float3 N = normalize(tex2D(_NormTex, i.uv).rgb);

				//N anim
				float4 tt = float4(N, 0);
				float T = 3;//3s ×ªÒ»ÖÜ
				//tt = RotateAroundYInDegrees(tt, fmod(_Time.y,T) *(360/T));
				N = tt.rgb;

				float NdotL = max(dot(N, L), 0);

				//get env light from N
				//float3 envDiff = GetEnvIrradiance_equirectangular(_envDiffTex, N, true);
				float3 envRef = GetEnvIrradiance_equirectangular(_envRefTex, N, true);

				float smooth = lerp(0, 1, pow(Gray(envRef),1));
				smooth = saturate(smooth);
				//smooth *= 0.4;
				//smooth = sigmoid(smooth +0.0);
				//r = pow(r, 0.5);

				float3 c = 0;
				float3 V = float3(0, 0, 1);

				//###PBR_IBL
				//???
				float ao = 1;
				float metallic = 0;
				float roughness = 1-smooth;
				//
				//float3 F0 = 0.04;
				//F0 = lerp(F0, albedo, metallic);
				////diffuse
				//float3 kS = 0;//fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
				//float3 kD = 1.0 - kS;
				//float3 irradiance = GetEnvIrradiance_equirectangular(_envDiffTex, N, true);
				//float3 indirect_diffuse = (kD * irradiance * albedo) * ao;

				//spec
				//float3 R = reflect(-V, N);

				float3 prefilteredColor;
				{
					float Width;
					float Height;
					float Elements;
					_envSpecTex2DArr.GetDimensions(Width, Height, Elements);
					//prefilteredColor = IBLBakeSpecMipByRoughness(_envSpecTex2DArr, R, roughness, Elements, true);
					prefilteredColor = IBLBakeSpecMipByRoughness(_envSpecTex2DArr, N, roughness, Elements, true);
				}
				//float2 envBRDF_UV = 0;
				//envBRDF_UV.x = max(dot(N, V), 0);
				//envBRDF_UV.y = roughness;

				//float2 envBRDF = tex2D(_brdfLUT, envBRDF_UV).rg;//brdfLUT.SampleLevel(my_point_clamp_sampler, envBRDF_UV, 0).rg;
				//float3 indirect_specular = prefilteredColor *(kS * envBRDF.x + envBRDF.y) * ao;

				//###PBR_IBL
				c = prefilteredColor * albedo; //indirect_diffuse +indirect_specular;
				float3 re = c * a;
				//###
				fixed4 col = fixed4(re,1);
				return col;
			}
            ENDCG
        }
    }
}
