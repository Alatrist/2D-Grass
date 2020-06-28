Shader "Standard/wind"
{
	//based on the book of shaders https://thebookofshaders.com/13/
	Properties
	{
		_res("Resolution", float) = 1000
		u_time("Time", float) = 1
		alpha_cul("alpha_cul", float) = 1
		wind_dir("wind_dir", Vector) = (1,0,0,0)
		wind_strength("wind_strength", float) = 0.5
		whirling_speed("whirling_speed", float) = 0.5
	}
		SubShader
	{
		Tags {"Queue" = "Transparent" "RenderType" = "Transparent" }
		LOD 100
		ZWrite Off
	 Blend SrcAlpha OneMinusSrcAlpha
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

			float random(in float2 _st) {
				return frac(sin(dot(_st.xy,
					float2(12.9898, 78.233))) *
					43758.5453123);
			}

			float noise(in float2 _st) {
				float2 i = floor(_st);
				float2 f = frac(_st);

				// Four corners in 2D of a tile
				float a = random(i);
				float b = random(i + float2(1.0, 0.0));
				float c = random(i + float2(0.0, 1.0));
				float d = random(i + float2(1.0, 1.0));

				float2 u = f * f * (3.0 - 2.0 * f);

				return lerp(a, b, u.x) +
					(c - a) * u.y * (1.0 - u.x) +
					(d - b) * u.x * u.y;
			}

#define NUM_OCTAVES 5

			float fbm(in float2 _st) {
				float v = 0.0;
				float a = 0.5;
				float2 shift = float2(100.0,0);
				// Rotate to reduce axial bias
				float2x2 rot = float2x2(cos(0.5), sin(0.5),
					-sin(0.5), cos(0.50));
				for (int i = 0; i < NUM_OCTAVES; ++i) {
					v += a * noise(_st);
					_st = mul(_st, rot) * 2.0 + shift;
					a *= 0.5;
				}
				return v;
			}

			float _res;
			float u_time;
			float alpha_cul;
			float2 wind_dir;
			float wind_strength;
			float whirling_speed;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);

				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float2 st = i.uv / _res * 7003.608 - wind_dir * wind_strength *u_time;

				float3 color = float3(0.0,0,0);

			float2 q = float2(0.,0);
			q.x = fbm(st + 0.00 * u_time);
			q.y = fbm(st + float2(1.0,0));

			float2 r = float2(0.,0);
			r.x = fbm(st + 1.0 * q + float2(1.7,9.2) + whirling_speed *u_time);  //0.15
			r.y = fbm(st + 1.0 * q + float2(8.3,2.8) + whirling_speed *u_time);  //0.126

			float f = fbm(st + r);

			float c = lerp(0.619608, 0.666667,
						clamp((f * f) * 4.0,0.0,1.0));

			c = lerp(c, 0, clamp(length(q),0.0,1.0));

			c = lerp(c, 1, clamp(length(r.x),0.0,1.0));

				float alpha;
				if (alpha_cul < 0)
					alpha = 1;
				else
				{
					alpha = 0.5 - abs(0.5 - i.uv.x);
					alpha = min(alpha, 0.5 - abs(0.5 - i.uv.y));
					alpha = sin(2 * alpha);
					alpha = min(2 * alpha, c);

				}

				fixed4 col = float4((f * f * f + .9 * f * f + .6 * f) * float3(c,c,c), alpha);
				// apply fog

				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
