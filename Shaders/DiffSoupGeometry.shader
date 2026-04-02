Shader "DiffSoup/Geometry"
{
    Properties
    {
        _TriTexSize ("TriTexSize", Vector) = (0,0,0,0)
        _TriTex0 ("TriTex0", 2D) = "white" {}
        _TriTex1 ("TriTex1", 2D) = "white" {}
        _Level ("Level", Int) = 0
    }
    SubShader
    {
        ZTest On
        ZWrite On
        Cull Off

        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                uint triID : SV_VertexID;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 bary : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
                uint triID : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
            };

            Texture2D<float4> _TriTex0;
            Texture2D<float4> _TriTex1;
            int2 _TriTexSize;
            int _Level;

            float4x4 _W1[16]; float4 _B1[4];
            float4x4 _W2[16]; float4 _B2[4];
            float4x4 _W3[4];  float4 _B3;

            static const float SH_C0   =  0.28209479177387814;
            static const float SH_C1   =  0.4886025119029199;
            static const float SH_C2_0 =  1.0925484305920792;
            static const float SH_C2_1 = -1.0925484305920792;
            static const float SH_C2_2 =  0.31539156525252005;
            static const float SH_C2_3 = -1.0925484305920792;
            static const float SH_C2_4 =  0.5462742152960396;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.triID = v.triID / 3;
                int corner = v.triID % 3;
                o.bary = (corner==0) ? float3(1,0,0) : (corner==1) ? float3(0,1,0) : float3(0,0,1);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);

                return o;
            }

            int2 idx_to_coord(int idx) 
            { 
                return int2(idx % _TriTexSize.x, _TriTexSize.y - 1 - idx / _TriTexSize.x); 
            }

            int level_size(int L) 
            {
                if (L==0) return 3;
                int a = (1 << (L-1)) + 1;
                int b = (1 << L) + 1;
                return a * b;
            }

            float4 LinearToSRGB(float4 linearRGB)
            {
                float4 a = 12.92 * linearRGB;
                float4 b = 1.055 * pow(linearRGB, 1.0 / 2.4) - 0.055;

                float4 result = lerp(a, b, step(0.0031308, linearRGB));
                return result;
            }

            float4 SRGBToLinear(float4 srgb)
            {
                float4 a = srgb / 12.92;
                float4 b = pow((srgb + 0.055) / 1.055, 2.4);

                float4 result = lerp(a, b, step(0.04045, srgb));
                return result;
            }
     
            void geometry(int triID, float3 bary, out float4 A, out float4 B)
            {
                int S = level_size(_Level);
                int base = triID * S;
                float b0 = bary.x, b1 = bary.y;
                int res = 1 << _Level;
                float res_f = float(res);

                float b0l = b0 * res_f, b1l = b1 * res_f;
                int x = clamp(int(floor(b0l)), 0, res-1);
                int y = clamp(int(floor(b1l)), 0, (res-1)-x);
                b0l -= float(x); 
                b1l -= float(y);

                bool flip = (b0l + b1l) > 1.0;
                int flip_u = flip ? 1 : 0;
                float flip_f = flip ? 1.0 : 0.0;

                int x0=x+1, y0=y;
                int x1=x,   y1=y+1;
                int x2=x+flip_u, y2=min(y+flip_u, res-x2);

                int idx0 = (x0+y0)*(x0+y0+1)/2 + y0;
                int idx1 = (x1+y1)*(x1+y1+1)/2 + y1;
                int idx2 = (x2+y2)*(x2+y2+1)/2 + y2;

                float w0 = lerp(b0l, 1.0-b1l, flip_f);
                float _W1 = lerp(b1l, 1.0-b0l, flip_f);
                float _W2 = 1.0 - w0 - _W1;

                int2 c0 = idx_to_coord(base+idx0);
                int2 c1 = idx_to_coord(base+idx1);
                int2 c2 = idx_to_coord(base+idx2);

                A = _TriTex0[c0]*w0 + _TriTex0[c1]*_W1 + _TriTex0[c2]*_W2;
                B = _TriTex1[c0]*w0 + _TriTex1[c1]*_W1 + _TriTex1[c2]*_W2;
            }

            float4 relu4(float4 x)
            { 
                return max(x,0.0); 
            }

            float sigmoid(float x)
            { 
                return 1.0/(1.0+exp(-x)); 
            }

            void eval_sh2(float3 d, out float sh[9])
            {
                sh[0] = SH_C0;
                sh[1] = -SH_C1*d.y; sh[2] = SH_C1*d.z; sh[3] = -SH_C1*d.x;
                float xx=d.x*d.x, yy=d.y*d.y, zz=d.z*d.z;
                sh[4] = SH_C2_0*d.x*d.y; sh[5] = SH_C2_1*d.y*d.z;
                sh[6] = SH_C2_2*(2.0*zz-xx-yy);
                sh[7] = SH_C2_3*d.x*d.z; sh[8] = SH_C2_4*(xx-yy);
            }

            float3 post(float3 v, float4 A, float4 B)
            {
                float sh[9]; 
                eval_sh2(v, sh);

                float4 x0 = float4(A.r,A.g,A.b,A.a);
                float4 x1 = float4(B.r,B.g,B.b,sh[0]);
                float4 x2 = float4(sh[1],sh[2],sh[3],sh[4]);
                float4 x3 = float4(sh[5],sh[6],sh[7],sh[8]);

                float4 y0 = relu4(mul(_W1[ 0], x0) + mul(_W1[ 1], x1) + mul(_W1[ 2], x2) + mul(_W1[ 3], x3) + _B1[0]);
                float4 y1 = relu4(mul(_W1[ 4], x0) + mul(_W1[ 5], x1) + mul(_W1[ 6], x2) + mul(_W1[ 7], x3) + _B1[1]);
                float4 y2 = relu4(mul(_W1[ 8], x0) + mul(_W1[ 9], x1) + mul(_W1[10], x2) + mul(_W1[11], x3) + _B1[2]);
                float4 y3 = relu4(mul(_W1[12], x0) + mul(_W1[13], x1) + mul(_W1[14], x2) + mul(_W1[15], x3) + _B1[3]);
                float4 z0 = relu4(mul(_W2[ 0], y0) + mul(_W2[ 1], y1) + mul(_W2[ 2], y2) + mul(_W2[ 3], y3) + _B2[0]);
                float4 z1 = relu4(mul(_W2[ 4], y0) + mul(_W2[ 5], y1) + mul(_W2[ 6], y2) + mul(_W2[ 7], y3) + _B2[1]);
                float4 z2 = relu4(mul(_W2[ 8], y0) + mul(_W2[ 9], y1) + mul(_W2[10], y2) + mul(_W2[11], y3) + _B2[2]);
                float4 z3 = relu4(mul(_W2[12], y0) + mul(_W2[13], y1) + mul(_W2[14], y2) + mul(_W2[15], y3) + _B2[3]);

                float4 acc = mul(_W3[0], z0) + mul(_W3[1], z1) + mul(_W3[2], z2) + mul(_W3[3], z3) + _B3;
                float3 mlp = float3(sigmoid(acc.x), sigmoid(acc.y), sigmoid(acc.z));

                return mlp;
            }

            float3 ndcToWorld(float4 ndc, float4x4 inv){
                float4 c = mul(inv, ndc);
                float w = c.w; if(abs(w)<1e-20) w=1e-20;
                return c.xyz / w;
            }

            float4x4 inverse(float4x4 input)
            {
                #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
                //determinant(float3x3(input._22_23_23, input._32_33_34, input._42_43_44))

                float4x4 cofactors = float4x4(
                    minor(_22_23_24, _32_33_34, _42_43_44),
                    -minor(_21_23_24, _31_33_34, _41_43_44),
                    minor(_21_22_24, _31_32_34, _41_42_44),
                    -minor(_21_22_23, _31_32_33, _41_42_43),

                    -minor(_12_13_14, _32_33_34, _42_43_44),
                    minor(_11_13_14, _31_33_34, _41_43_44),
                    -minor(_11_12_14, _31_32_34, _41_42_44),
                    minor(_11_12_13, _31_32_33, _41_42_43),

                    minor(_12_13_14, _22_23_24, _42_43_44),
                    -minor(_11_13_14, _21_23_24, _41_43_44),
                    minor(_11_12_14, _21_22_24, _41_42_44),
                    -minor(_11_12_13, _21_22_23, _41_42_43),

                    -minor(_12_13_14, _22_23_24, _32_33_34),
                    minor(_11_13_14, _21_23_24, _31_33_34),
                    -minor(_11_12_14, _21_22_24, _31_32_34),
                    minor(_11_12_13, _21_22_23, _31_32_33)
                );
                #undef minor
                return transpose(cofactors) / determinant(input);
            }

            float4x4 clipToWorld()
            {
                return inverse(UNITY_MATRIX_VP);
            }

            float4 frag (v2f i) : SV_Target
            {
                // Geometry //
                float4 A, B;
                geometry(i.triID, i.bary, A, B);

                if ((B.a).r < 0.5) 
                    discard;

                float3 v = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
                v = v.xzy;
                v.z = -v.z;

                /*float4x4 uInvPV = clipToWorld();

                float2 vUV = i.screenPos.xy / i.screenPos.w;
                float ndc_x = vUV.x*2.0-1.0;
                float ndc_y = 1.0-vUV.y*2.0;
                float3 w_near = ndcToWorld(float4(ndc_x,ndc_y,-1.0,1.0), uInvPV);
                float3 w_far  = ndcToWorld(float4(ndc_x,ndc_y, 1.0,1.0), uInvPV);
                float3 v = normalize(w_near - w_far);*/

                // TODO: v is wrong
                float3 mlp = post(v, (A), (B));
                
                return float4(SRGBToLinear(float4(lerp(A.rgb, mlp, (A.a)), 1.0)).rgb, 1.0);
            }
            ENDCG
        }
    }
}
