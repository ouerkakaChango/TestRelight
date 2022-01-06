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
		_BlurSmoothTex("_BlurSmoothTex", 2D) = "white" {}
		_LightIntensity("_LightIntensity", Range(1.0,10.0)) = 1
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
			sampler2D _BlurSmoothTex;
			float4 _BlurSmoothTex_ST;

			Texture2DArray _envSpecTex2DArr;

			float _LightIntensity;

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

			void RGB2HSL(float3 AColor, out float H, out float S, out float L)
			{
				float R, G, B, Max, Min, del_R, del_G, del_B, del_Max;
				R = AColor.r;
				G = AColor.g;
				B = AColor.b;

				Min = min(R, min(G, B));
				Max = max(R, max(G, B));
				del_Max = Max - Min;

				L = (Max + Min) / 2.0;

				if (del_Max == 0)           //This is a gray, no chroma...
				{
					//H = 2.0/3.0;          
					H = 0;
					S = 0;
				}
				else
				{
					if (L < 0.5) S = del_Max / (Max + Min);
					else         S = del_Max / (2 - Max - Min);

					del_R = (((Max - R) / 6.0) + (del_Max / 2.0)) / del_Max;
					del_G = (((Max - G) / 6.0) + (del_Max / 2.0)) / del_Max;
					del_B = (((Max - B) / 6.0) + (del_Max / 2.0)) / del_Max;

					if (R == Max) H = del_B - del_G;
					else if (G == Max) H = (1.0 / 3.0) + del_R - del_B;
					else if (B == Max) H = (2.0 / 3.0) + del_G - del_R;

					if (H < 0)  H += 1;
					if (H > 1)  H -= 1;
				}
			}

			float Hue2RGB(float v1, float v2, float vH)
			{
				if (vH < 0) vH += 1;
				if (vH > 1) vH -= 1;
				if (6.0 * vH < 1) return v1 + (v2 - v1) * 6.0 * vH;
				if (2.0 * vH < 1) return v2;
				if (3.0 * vH < 2) return v1 + (v2 - v1) * ((2.0 / 3.0) - vH) * 6.0;
				return (v1);
			}

			float3 HSL2RGB(float H, float S, float L)
			{
				float R, G, B;
				float var_1, var_2;
				if (S == 0)
				{
					R = L;
					G = L;
					B = L;
				}
				else
				{
					if (L < 0.5)
					{
						var_2 = L * (1 + S);
					}
					else 
					{ 
						var_2 = (L + S) - (S * L); 
					}

					var_1 = 2.0 * L - var_2;

					R = Hue2RGB(var_1, var_2, H + (1.0 / 3.0));
					G = Hue2RGB(var_1, var_2, H);
					B = Hue2RGB(var_1, var_2, H - (1.0 / 3.0));
				}
				return float3(R, G, B);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				//###
				float a = tex2D(_NormTex, i.uv).a;
				//!!! albedo不应该是原图
				float3 albedo = tex2D(_MainTex, i.uv).rgb;
				//float h, s, l;
				//RGB2HSL(albedo, h, s, l);
				//albedo = HSL2RGB(h, s+0.3, l);
				//return fixed4(albedo*a, 1);

				float3 L = normalize(float3(1,1,1));
				float3 N = normalize(tex2D(_NormTex, i.uv).rgb);

				//N anim
				float4 tt = float4(N, 0);
				float T = 3;//3s 转一周
				tt = RotateAroundYInDegrees(tt, fmod(_Time.y,T) *(360/T));
				N = tt.rgb;

				float NdotL = max(dot(N, L), 0);

				float smooth=0;
				{
					//get env light from N
					//float3 envDiff = GetEnvIrradiance_equirectangular(_envDiffTex, N, true);
					//float3 envRef = GetEnvIrradiance_equirectangular(_envRefTex, N, true);

					//smooth = lerp(0, 1, pow(Gray(envRef),1));
					//smooth = saturate(smooth);
					//smooth *= 0.4;
					//smooth = sigmoid(smooth +0.0);
					//r = pow(r, 0.5);
				}
				{
					smooth = tex2D(_BlurSmoothTex, i.uv).r;
					//???
					//smooth = pow(smooth, 0.45);
					//return smooth;
				}

				float3 c = 0;
				float3 V = float3(0, 0, 1);

				//###PBR_IBL
				//???
				float ao = 1;
				float metallic = 0;
				float roughness =  1 - smooth;
				//
				float3 F0 = 0.04;
				F0 = lerp(F0, albedo, metallic);
				//diffuse
				float3 kS = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
				float3 kD = 1.0 - kS;
				float3 irradiance = _LightIntensity * (GetEnvIrradiance_equirectangular(_envDiffTex, N, true));
				float3 indirect_diffuse = (kD * irradiance * albedo) * ao;
				//float3 indirect_diffuse = (kD * irradiance * albedo) * ao;

				//spec
				float3 R = reflect(-V, N);

				float3 prefilteredColor;
				{
					float Width;
					float Height;
					float Elements;
					_envSpecTex2DArr.GetDimensions(Width, Height, Elements);
					//prefilteredColor = IBLBakeSpecMipByRoughness(_envSpecTex2DArr, N, roughness, Elements, true);
					prefilteredColor = _LightIntensity * IBLBakeSpecMipByRoughness(_envSpecTex2DArr, R, roughness, Elements, true);
				}
				float2 envBRDF_UV = 0;
				envBRDF_UV.x = max(dot(N, V), 0);
				envBRDF_UV.y = roughness;

				float2 envBRDF = tex2D(_brdfLUT, envBRDF_UV).rg;
				//float3 indirect_specular = prefilteredColor * kS * ao;
				float3 indirect_specular = prefilteredColor * (kS * envBRDF.x + envBRDF.y) * ao;

				//###PBR_IBL
				//c = prefilteredColor * albedo; 
				//c = indirect_diffuse;
				c = indirect_diffuse + indirect_specular;
				float3 re = c * a;
				//###
				fixed4 col = fixed4(re,1);
				return col;
			}
            ENDCG
        }
    }
}
