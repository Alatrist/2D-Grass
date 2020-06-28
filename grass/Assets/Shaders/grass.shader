Shader "Unlit/grass"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        wind_dir("wind_dir", Vector) = (1,0,0,0)
        wind_strength("wind_strength", float) = 1
        whirling_strength("whirling_strength", float) = 0.5
        _res("Resolution", float) = 1000
        u_time("Time", float) = 0.5
        time_scale("time_scale", float) = 0.5
        grass_detail("grass_detail", int) = 4
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" }
            LOD 100

            Pass
            {
                CGPROGRAM

                #pragma target 4.0
                // Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
                #pragma exclude_renderers gles
                #pragma enable_d3d11_debug_symbols
                #pragma exclude_renderers d3d11_9x
                #pragma exclude_renderers d3d9
                #pragma vertex vert
                #pragma geometry geom
                #pragma fragment frag

                // make fog work
                #pragma multi_compile_fog
                #pragma multi_compile_instancing
                #include "UnityCG.cginc"

                //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    UNITY_FOG_COORDS(1)
                    float4 vertex : SV_POSITION;
                    float4 control0 :TEXCOORD1;
                    float4 control1 :TEXCOORD2;
                    float4 control2 :TEXCOORD3;
                    float4 control3 :TEXCOORD4;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };
                struct out_vert
                {
                    float2 uv : TEXCOORD0;
                    UNITY_FOG_COORDS(1)
                    float4 vertex : SV_POSITION;
                };

                sampler2D _MainTex;
                float4 _MainTex_ST;
                static const float PI = 3.14159265f;
                float4 wind_dir;
                //float wind_angle;
                float wind_strength;

                int collision_count;
                float4 collision_distances[100];

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
                    float2 shift = float2(100.0, 0);
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
                float whirling_strength;
                float time_scale;
                int grass_detail;

                float local_dis(float2 pos)
                {
                    float2 st = pos / _res * 7003.608 - wind_dir.xy * wind_strength * u_time * time_scale;

                    float2 q = float2(0., 0);
                    q.x = fbm(st);
                    q.y = fbm(st + float2(1.0, 0));

                    float2 r = float2(0., 0);
                    r.x = fbm(st + q + float2(1.7, 9.2) + u_time * time_scale);
                    r.y = fbm(st + q + float2(8.3, 2.8) + u_time * time_scale);

                    float f = fbm(st + r);

                    float c = lerp(0.619608, 0.666667,
                        clamp((f * f) * 4.0, 0.0, 1.0));

                    c = lerp(c, 0, clamp(length(q), 0.0, 1.0));

                    c = lerp(c, 1, clamp(length(r.x), 0.0, 1.0));

                    return 1 - (f * f * f + .9 * f * f + .6 * f) * c;
                }

                float2 local_wind(float3 v)
                {
                    float x = local_dis(v.xy) * 2 - 1;
                    float y = local_dis(v.yx) * 2 - 1;
                    return float2(normalize(-wind_dir) * wind_strength + float2(x, y) * whirling_strength);
                }

                bool is_zero(float val)
                {
                    return abs(val) < 0.0000001;
                }

                float4 compute_control_point(float3 vert, float3 origin)
                {
                    float4 vert_4d = float4(vert.x, vert.y, vert.z, 1);
                    float3 detect_pos = mul(unity_ObjectToWorld, vert_4d).xyz + origin;

                    float2 wind_info = local_wind(detect_pos);
                    float angle = dot(normalize(wind_info), float2(-1, 0)); //wind_angle * PI/180; 

                    float windVel = length(wind_info);
                    float stif = 1.0 / (pow(2, (vert.y * vert.y * vert.y)) - 1);
                    float iy = (1 - angle * angle) * windVel * windVel / stif;
                    float ix = angle * windVel * windVel / stif;

                    float3 res = vert.xyz + float3(ix, iy, 0);
                    return float4(res.x, res.y, res.z, 0);
                }

                void swap_rows(inout float4 a, inout float4 b)
                {
                    float4 tmp = a;
                    a = b;
                    b = tmp;
                }



                float3 gaussian_elim(float4 first_row, float4 second_row, float4 third_row)
                {
                    if (is_zero(first_row.x))
                    {
                        if (!is_zero(second_row.x))
                            swap_rows(first_row, second_row);
                        else
                            swap_rows(first_row, third_row);
                    }

                    if (!is_zero(first_row.x))
                    {
                        second_row = second_row - second_row.x / first_row.x * first_row;
                        third_row = third_row - third_row.x / first_row.x * first_row;

                        if (is_zero(second_row.y))
                            swap_rows(second_row, third_row);

                        if (!is_zero(second_row.y))
                        {
                            third_row = third_row - third_row.y / second_row.y * second_row;
                        }
                    }

                    float z;
                    if (is_zero(third_row.z))
                        z = 1;
                    else
                        z = third_row.w / third_row.z;

                    float y;
                    if (is_zero(second_row.y))
                        y = 2.0 / 3.0;
                    else
                        y = (second_row.w - z * second_row.z) / second_row.y;

                    float x;
                    if (is_zero(first_row.x))
                        x = 1.0 / 3.0;
                    else
                        x = (first_row.w - y * first_row.y - z * first_row.z) / first_row.x;
                    return float3(x, y, z);
                }

                float3 mult_el(float3 a, float3 b)
                {
                    return float3(a.x * b.x, a.y * b.y, a.z * b.z);
                }

                float3x4 inverse_bezier(float3 t1, float3 target, float P0)
                {
                    float3 t2 = mult_el(t1, t1);
                    float3 t3 = mult_el(t1, t2);
                    float3 one_minus_t = float3(1.0 - t1.x, 1 - t1.y, 1 - t1.z);
                    float3 one_minus_t2 = mult_el(one_minus_t, one_minus_t);
                    return transpose(float4x3(3 * mult_el(t1, one_minus_t2), 3 * mult_el(t2, one_minus_t), t3, target - mult_el(one_minus_t2, one_minus_t) * P0));
                }
                void transform_bezier(float2x3 target_position, float3 t, float2 P0, inout float2 P1, inout float2 P2, inout float2 P3)
                {
                    float3x4 x_equations = inverse_bezier(t, target_position[0], P0.x);
                    float3x4 y_equations = inverse_bezier(t, target_position[1], P0.y);

                    float3 x_res = gaussian_elim(x_equations[0], x_equations[1], x_equations[2]);
                    float3 y_res = gaussian_elim(y_equations[0], y_equations[1], y_equations[2]);

                    P1 = float2(x_res[0], y_res[0]);
                    P2 = float2(x_res[1], y_res[1]);
                    P3 = float2(x_res[2], y_res[2]);
                }

                float compute_shrink(v2f v)
                {
                    float S0 = 1;

                    float S = distance(v.control0, v.control1) + distance(v.control1, v.control2) + distance(v.control2, v.control3);
                    return S0 / S;
                }


                float4 tToBezier(float t, float4 P0, float4 P1, float4 P2, float4 P3)
                {
                    float t2 = t * t;
                    float one_minus_t = 1.0 - t;
                    float one_minus_t2 = one_minus_t * one_minus_t;
                    float4 res = (P0 * one_minus_t2 * one_minus_t + P1 * 3.0 * t * one_minus_t2 + P2 * 3.0 * t2 * one_minus_t + P3 * t2 * t);
                    return res;
                }
                float2 tToBezier(float t, float2 P0, float2 P1, float2 P2, float2 P3)
                {
                    float t2 = t * t;
                    float one_minus_t = 1.0 - t;
                    float one_minus_t2 = one_minus_t * one_minus_t;
                    float2 res = (P0 * one_minus_t2 * one_minus_t + P1 * 3.0 * t * one_minus_t2 + P2 * 3.0 * t2 * one_minus_t + P3 * t2 * t);
                    return res;
                }


                void collide(float3 P0, inout float3 P1, inout float3 P2, inout float3 P3)
                {
                    float2 res_P1 = P1.xy;
                    float2 res_P2 = P2.xy;
                    float2 res_P3 = P3.xy;

                    float3 t = float3(1.0 / 3, 2.0 / 3, 1);

                    for (int o = 0; o < collision_count; ++o)
                    {
                        float2 pos = collision_distances[o].xy;

                        float2 m00_m10;
                        float2 m01_m11;
                        float2 m02_m12;
                        //if root is not in collision skip
                        // if (distance(P0.xy, pos) > collision_distances[o].w && distance())
                        //    continue;

                        //foreach moveable controll point
                        for (int k = 0; k < 3; ++k)
                        {
                            float2 test_point = tToBezier(t[k], P0.xy, P1.xy, P2.xy, P3.xy);
                            float dist = distance(pos.xy, test_point);

                            float dist_to_orig = distance(test_point, P0.xy);

                            if (dist < collision_distances[o].w && abs(P0.y - pos.y)< collision_distances[o].w)//(abs(test_point.x - pos.x) < collision_distances[o].w))
                            {
                                test_point = test_point + normalize(test_point - pos.xy) * (collision_distances[o].w - dist);   //move out of the collision
                                //prevent stretching
                                if (test_point.y > pos.y)
                                {
                                    if (abs(test_point.x - pos.x) < collision_distances[o].w / 1.5)
                                    {
                                        test_point.y = 2 * pos.y - test_point.y;
                                    }
                                }
                            }
                            if (k == 0)
                            {
                                m00_m10 = test_point;
                            }
                            else if (k == 1)
                            {
                                m01_m11 = test_point;
                            }
                            else
                            {
                                m02_m12 = test_point;
                            }
                        }

                        float2x3 m = transpose(float3x2(m00_m10, m01_m11, m02_m12));
                        transform_bezier(m, t, P0.xy, res_P1, res_P2, res_P3);
                    }
                    P1.xy = res_P1.xy;
                    P2.xy = res_P2.xy;
                    P3.xy = res_P3.xy;
                }


                v2f vert(appdata v)
                {
                    v2f o;
                    UNITY_SETUP_INSTANCE_ID(v);
                    UNITY_TRANSFER_INSTANCE_ID(v, o);

                    float3 l0 = float3(0, 0, 0);
                    float3 l1 = float3(0, 1.0 / 3, 0);
                    float3 l2 = float3(0, 2.0 / 3, 0);
                    float3 l3 = float3(0, 1, 0);

                    //o.vertex = v.vertex;
                    o.vertex = v.vertex;
                    o.control0 = compute_control_point(l0, v.vertex);

                    o.control1 = compute_control_point(l1, v.vertex);
                    float4 dir = normalize(o.control1 - o.control0) * 1.0 / 3;
                    o.control1 = o.control0 + dir;


                    o.control2 = compute_control_point(l2, v.vertex);
                    dir = normalize(o.control2 - o.control1) * 1.0 / 3;
                    o.control2 = o.control1 + dir;

                    o.control3 = compute_control_point(l3, v.vertex);
                    dir = normalize(o.control3 - o.control2) * 1.0 / 3;
                    o.control3 = o.control2 + dir;

                    o.control0 = mul(unity_ObjectToWorld, float4(o.control0.x, o.control0.y, o.control0.z, 1)) + v.vertex;
                    o.control1 = mul(unity_ObjectToWorld, float4(o.control1.x, o.control1.y, o.control1.z, 1)) + v.vertex;
                    o.control2 = mul(unity_ObjectToWorld, float4(o.control2.x, o.control2.y, o.control2.z, 1)) + v.vertex;
                    o.control3 = mul(unity_ObjectToWorld, float4(o.control3.x, o.control3.y, o.control3.z, 1)) + v.vertex;

                    collide(o.control0.xyz, o.control1.xyz, o.control2.xyz, o.control3.xyz);
                    o.control0 = o.control0 - v.vertex;
                    o.control1 = o.control1 - v.vertex;
                    o.control2 = o.control2 - v.vertex;
                    o.control3 = o.control3 - v.vertex;

                    o.control0 = mul(unity_WorldToObject, float4(o.control0.x, o.control0.y, o.control0.z, 1));
                    o.control1 = mul(unity_WorldToObject, float4(o.control1.x, o.control1.y, o.control1.z, 1));
                    o.control2 = mul(unity_WorldToObject, float4(o.control2.x, o.control2.y, o.control2.z, 1));
                    o.control3 = mul(unity_WorldToObject, float4(o.control3.x, o.control3.y, o.control3.z, 1));

                    o.control1.y = o.control1.y < 0 ? 0 : o.control1.y;
                    o.control2.y = o.control2.y < 0 ? 0 : o.control2.y;
                    o.control3.y = o.control3.y < 0 ? 0 : o.control3.y;

                    o.uv = v.uv;
                    UNITY_TRANSFER_FOG(o,o.vertex);


                    return o;
                }

                void outputVertex(out_vert input, inout TriangleStream<out_vert> outStream, float3 translation)
                {
                    out_vert output;

                    float4 test_point = mul(unity_ObjectToWorld, float4(input.vertex.x, input.vertex.y, 0, 1));
                    test_point.xyz = test_point.xyz + translation;

                    output.vertex = mul(UNITY_MATRIX_VP, test_point);
                    output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                    outStream.Append(output);
                }

                float4 toBezier(float delta, int i, float4 P0, float4 P1, float4 P2, float4 P3)
                {
                    float t = delta * float(i);
                    float t2 = t * t;
                    float one_minus_t = 1.0 - t;
                    float one_minus_t2 = one_minus_t * one_minus_t;
                    float4 res = (P0 * one_minus_t2 * one_minus_t + P1 * 3.0 * t * one_minus_t2 + P2 * 3.0 * t2 * one_minus_t + P3 * t2 * t);
                    return res;
                }



                [maxvertexcount(32)]
                void geom(point v2f input[1], inout TriangleStream<out_vert> outStream)
                {
                    UNITY_SETUP_INSTANCE_ID(input[0]);
                    v2f data = input[0];

                    float4 c[4];
                    c[0] = data.control0;
                    c[1] = data.control1;
                    c[2] = data.control2;
                    c[3] = data.control3;

                    float ts[4];
                    ts[0] = 0;
                    ts[1] = 1 / 3.0;
                    ts[2] = 2 / 3.0;
                    ts[3] = 1;


                    float t = 0;
                    float shrink = compute_shrink(data);
                    float sign = 1;
                    float2 wind_info = local_wind(mul(unity_ObjectToWorld, float4(0, 0, 0, 1)) + data.vertex.xyz);
                    float cos_wind = dot(normalize(wind_info), float2(-1, 0));
                    if (cos_wind < 0)
                        sign = -1;

                    out_vert vert;

                    float width = 0.02f;


                    vert.vertex = c[0] + float4(1, 0, 0, 0) * width;
                    vert.uv = float2(1, 1);
                    outputVertex(vert, outStream, data.vertex);
                    vert.vertex = c[0] - float4(1, 0, 0, 0) * width;
                    vert.uv = float2(0, 1);
                    outputVertex(vert, outStream, data.vertex);

                    float3 last_pos = float3(0, 0, 0);

                    int index = 1;
                    for (uint i = 2; i < 2 * grass_detail; i++)
                    {
                        float4 lead = toBezier(1.0 / grass_detail, i >> 1, c[0], c[1], c[2], c[3]);
                        float expected_len = 1.0 / grass_detail;
                        lead.xyz = last_pos + normalize(lead.xyz - last_pos) * min(length(lead.xyz - last_pos), expected_len);

                        if (i % 2 == 1)
                            last_pos = lead.xyz;

                        float4 dir = normalize(lead - c[0]);
                        float4 norm = float4(dir.y, -dir.x, 0, 0);
                        if (cos_wind < 0)
                        {
                            vert.vertex = lead - sign * (norm)*width;
                        }
                        else
                            vert.vertex = lead + sign * (norm)*width;

                        vert.uv = float2(1 - (i % 2), 1 - i / 2.0 / grass_detail);
                        outputVertex(vert, outStream, data.vertex);
                        sign = -sign;
                        if (i % 2 == 1)
                        {
                            index += 1;
                        }
                    }
                    float4 pos = toBezier(1, 1, c[0], c[1], c[2], c[3]);
                    float expected_len = 1.0 / grass_detail;
                    pos.xyz = last_pos + normalize(pos.xyz - last_pos) * min(length(pos.xyz - last_pos), expected_len);
                    float4 n = pos - c[2];

                    vert.vertex = pos + normalize(float4(n.y, -n.x, 0, 0)) * width * 0.5;
                    vert.uv = float2(0.75f, 0);
                    outputVertex(vert, outStream, data.vertex);
                    vert.vertex = pos - normalize(float4(n.y, -n.x, 0, 0)) * width * 0.5;
                    vert.uv = float2(0.25f, 0);
                    outputVertex(vert, outStream, data.vertex);


                    outStream.RestartStrip();
                }


                fixed4 frag(out_vert i) : SV_Target
                {
                    // sample the texture
                    float4 base_col = tex2D(_MainTex, i.uv);
                    fixed4 col = fixed4(1.1 * base_col.x, 1.15 * base_col.y, 0.9 * base_col.z, base_col.w);

                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    return col;
                }
                ENDCG
            }
        }
}
