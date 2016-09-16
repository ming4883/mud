Shader "MGFX/NPR/CelShadingDS"
{
    Properties
    {
[NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}

_FadeOut ("_FadeOut", Range(0,1)) = 0.0
[Toggle(_TEXTURE_FADE_OUT_ON)] _TextureFadeOutOn("Enable Texture FadeOut", Int) = 0

[Toggle(_IRRADIANCE_ON)] _IrradianceOn("Enable Darken Backfaces", Int) = 1
_IrradianceBoost ("IrradianceBoost", Range(-1,8)) = 0.0
[Toggle(_DARKEN_BACKFACES_ON)] _DarkenBackfacesOn("Enable Darken Backfaces", Int) = 0

[Toggle(_NORMAL_MAP_ON)] _NormalMapOn("Enable NormalMap", Int) = 0
[NoScaleOffset] _NormalMapTex ("Normal Map", 2D) = "black" {}

[Toggle(_DIM_ON)] _DimOn("Enable Dim", Int) = 0
[NoScaleOffset] _DimTex ("Dim (RGB)", 2D) = "white" {}

[Toggle(_OVERLAY_ON)] _OverlayOn("Enable Overlay", Int) = 0
[NoScaleOffset] _OverlayTex ("Overlay (RGBA)", 2D) = "white" {}

[Toggle(_DIFFUSE_LUT_ON)] _DiffuseLUTOn("Enable Diffuse LUT", Int) = 0
[NoScaleOffset] _DiffuseLUTTex ("Diffuse LUT (R)", 2D) = "white" {}

[NoScaleOffset] _BayerTex ("Bayer Matrix", 2D) = "white" {}

[Toggle(_RIM_ON)] _RimOn("Enable Rim", Int) = 0
[NoScaleOffset] _RimLUTTex ("Rim LUT (R)", 2D) = "white" {}
_RimIntensity ("RimIntensity", Range(0,2)) = 1.0

[Toggle(_MATCAP_ON)] _MatCapOn("Enable MatCap", Int) = 0
[Toggle(_MATCAP_PLANAR_ON)] _MatCapPlanarOn("MatCap Planar Mode", Int) = 0
[Toggle(_MATCAP_ALBEDO_ON)] _MatCapAlbedoOn("MatCap Albedo Mode", Int) = 0
[NoScaleOffset] _MatCapTex ("MatCap", 2D) = "black" {}
_MatCapIntensity ("MatCapIntensity", Range(0,4)) = 1.0

    }

    SubShader
    {
		Tags
		{ 
			"RenderType"="Opaque"
		}

		Pass
		{
			Tags
			{
				"LightMode"="ForwardBase"
			}
			Cull Back

			CGPROGRAM
			#include "UnityCG.cginc"

#if UNITY_VERSION < 540
#define UNITY_SHADER_NO_UPGRADE
#define unity_ObjectToWorld _Object2World 
#define unity_WorldToObject _World2Object
#define unity_WorldToLight _LightMatrix0
#define unity_WorldToCamera _WorldToCamera
#define unity_CameraToWorld _CameraToWorld
#define unity_Projector _Projector
#define unity_ProjectorDistance _ProjectorDistance
#define unity_ProjectorClip _ProjectorClip
#define unity_GUIClipTextureMatrix _GUIClipTextureMatrix 
#endif

			#include "Lighting.cginc"
#include "AutoLight.cginc"

#ifdef POINT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = (tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL);
#endif

#ifdef SPOT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); \
	fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz);
#endif

#ifdef DIRECTIONAL
	#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos)	fixed destName = 1;
#endif


#ifdef POINT_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL * texCUBE(_LightTexture0, lightCoord).w;
#endif

#ifdef DIRECTIONAL_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; \
	fixed destName = tex2D(_LightTexture0, lightCoord).w;
#endif


half3 autoLightDir()
{
    half3 camRight = UNITY_MATRIX_V[0].xyz;
    half3 camFwd = UNITY_MATRIX_V[2].xyz;
    half3 worldUp = half3(0, 1, 0);

    return normalize(camFwd);
    //return normalize(camFwd + camRight * -0.125f + worldUp * 0.5);
}

			uniform sampler2D _BayerTex;
uniform float4 _BayerTex_TexelSize;

#define F1 float
#define F2 float2
#define F3 float3
#define F4 float4
#define fract frac
#define iGlobalTime _Time.y * 16.0

F1 Noise(F2 n,F1 x){n+=x;return fract(sin(dot(n.xy,F2(12.9898, 78.233)))*43758.5453)*2.0-1.0;}

// Step 1 in generation of the dither source texture.
F1 Step1(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-12.0,t=1.0;   
    return (1.0/(a*4.0+b*4.0-c))*(
        Noise(uv+F2(-1.0,-1.0)*t,n)*a+
        Noise(uv+F2( 0.0,-1.0)*t,n)*b+
        Noise(uv+F2( 1.0,-1.0)*t,n)*a+
        Noise(uv+F2(-1.0, 0.0)*t,n)*b+
        Noise(uv+F2( 0.0, 0.0)*t,n)*c+
        Noise(uv+F2( 1.0, 0.0)*t,n)*b+
        Noise(uv+F2(-1.0, 1.0)*t,n)*a+
        Noise(uv+F2( 0.0, 1.0)*t,n)*b+
        Noise(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Step 2 in generation of the dither source texture.
F1 Step2(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-2.0,t=1.0;
    return (4.0/(a*4.0+b*4.0-c))*(
        Step1(uv+F2(-1.0,-1.0)*t,n)*a+
        Step1(uv+F2( 0.0,-1.0)*t,n)*b+
        Step1(uv+F2( 1.0,-1.0)*t,n)*a+
        Step1(uv+F2(-1.0, 0.0)*t,n)*b+
        Step1(uv+F2( 0.0, 0.0)*t,n)*c+
        Step1(uv+F2( 1.0, 0.0)*t,n)*b+
        Step1(uv+F2(-1.0, 1.0)*t,n)*a+
        Step1(uv+F2( 0.0, 1.0)*t,n)*b+
        Step1(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Used for stills.
F3 Step3(F2 uv){
    F1 a=Step2(uv,0.07);    
    #ifdef CHROMATIC
    F1 b=Step2(uv,0.11);    
    F1 c=Step2(uv,0.13);
    return F3(a,b,c);
    #else
    // Monochrome can look better on stills.
    return F3(a, a, a);
    #endif
}

// Used for temporal dither.
F3 Step3T(F2 uv){
    F1 a=Step2(uv,0.07*(fract(iGlobalTime)+1.0));
    F1 b=Step2(uv,0.11*(fract(iGlobalTime)+1.0));
    F1 c=Step2(uv,0.13*(fract(iGlobalTime)+1.0));
    return F3(a,b,c);}

F1 InterleavedGradientNoise( F2 uv )
{
	const F3 magic = F3( 0.06711056, 0.00583715, 52.9829189 );
	F1 n = fract( magic.z * fract( dot( uv, magic.xy ) ) );
	return n * 2.0 - 1.0;
}

F1 Bayer( F2 uv )
{
	F2 val = dot(tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).rg, F2(256.0 * 255.0, 255.0));
	val = val * _BayerTex_TexelSize.x * _BayerTex_TexelSize.y;
	return val * 2.0 - 1.0;
	//return (tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).r) * 2.0 - 1.0;
}
// ====

			#pragma vertex vert
#pragma fragment frag_base
#pragma multi_compile_fwdbase novertexlight LIGHTMAP_OFF LIGHTMAP_ON DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED
#pragma target 3.0

#pragma shader_feature _TEXTURE_FADE_OUT_ON
#pragma shader_feature _IRRADIANCE_ON
#pragma shader_feature _NORMAL_MAP_ON
#pragma shader_feature _DARKEN_BACKFACES_ON
#pragma shader_feature _DIM_ON
#pragma shader_feature _OVERLAY_ON
#pragma shader_feature _DIFFUSE_LUT_ON
#pragma shader_feature _RIM_ON
#pragma shader_feature _MATCAP_ON
#pragma shader_feature _MATCAP_PLANAR_ON
#pragma shader_feature _MATCAP_ALBEDO_ON
//#pragma enable_d3d11_debug_symbols
			/// Vertex
///
struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 vcolor : COLOR;
    float2 texcoord : TEXCOORD0;
#if _OVERLAY_ON
    float2 texcoord1 : TEXCOORD1;

	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD2;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD3;
	#endif

#else
	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD1;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD2;
	#endif

#endif

#if _NORMAL_MAP_ON
	float4 tangent : TANGENT;
#endif
};

struct v2f
{
	float4 vcolor : COLOR;
    float4 uv : TEXCOORD0;
    SHADOW_COORDS(1) // put shadows data into TEXCOORD1
    float4 worldPosAndZ : TEXCOORD2;

#if _NORMAL_MAP_ON
	float4 tanSpace0 : TEXCOORD3;
	float4 tanSpace1 : TEXCOORD4;
	float4 tanSpace2 : TEXCOORD5;
#else
	float3 worldNormal : TEXCOORD3;
#endif

#if !defined(LIGHTMAP_OFF) || !defined(DYNAMICLIGHTMAP_OFF)
	float4 lmap : TEXCOORD6;
#endif

    float4 pos : SV_POSITION;
};

v2f vert (appdata v)
{
    v2f o;
    o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
    o.vcolor = v.vcolor;
    o.uv = v.texcoord.xyxy;
#if _OVERLAY_ON
    o.uv.zw = v.texcoord1;
#endif
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);

#if _NORMAL_MAP_ON
	float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
	float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
	float3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
	o.tanSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, 0);
	o.tanSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, 0);
	o.tanSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, 0);
#else
	o.worldNormal = worldNormal;
#endif

    o.worldPosAndZ.xyz = mul(unity_ObjectToWorld, v.vertex).xyz;

#ifndef LIGHTMAP_OFF
	o.lmap = v.lmapcoord.xyxy * unity_LightmapST.xyxy + unity_LightmapST.zwzw;
#endif

#ifndef DYNAMICLIGHTMAP_OFF
	o.lmap.zw = v.dlmapcoord.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

    COMPUTE_EYEDEPTH(o.worldPosAndZ.w);
    // compute shadows data
    TRANSFER_SHADOW(o)
    return o;
}

///
/// Fragment
///
uniform sampler2D _MainTex;

uniform float _FadeOut;

#if _IRRADIANCE_ON
uniform float _IrradianceBoost;
#endif

#if _NORMAL_MAP_ON
uniform sampler2D _NormalMapTex;
#endif

#if _DIM_ON
uniform sampler2D _DimTex;
#endif

#if _OVERLAY_ON
uniform sampler2D _OverlayTex;
#endif

#if _DIFFUSE_LUT_ON
uniform sampler2D _DiffuseLUTTex;
uniform sampler2D _MudSSAOTex; // global property
#endif

#if _RIM_ON
uniform sampler2D _RimLUTTex;
uniform float _RimIntensity;
#endif

#if _MATCAP_ON
uniform sampler2D _MatCapTex;
uniform float _MatCapIntensity;
#endif

struct ShadingContext
{
	half4 albedo;
	half4 dimmed;
	half3 worldNormal;
	half3 worldViewDir;
	half3 worldPos;
	fixed vface;
	fixed shadow;
	half4 result;
};

void fetchWorldNormal(inout ShadingContext ctx, in v2f i)
{
#if _NORMAL_MAP_ON
	half3 tanNormal = UnpackNormal(tex2D(_NormalMapTex, i.uv.xy));
	half3 worldNormal;
	worldNormal.x = dot(i.tanSpace0.xyz, tanNormal);
	worldNormal.y = dot(i.tanSpace1.xyz, tanNormal);
	worldNormal.z = dot(i.tanSpace2.xyz, tanNormal);
	ctx.worldNormal = normalize(worldNormal);
#else
	ctx.worldNormal = normalize(i.worldNormal);
#endif

#ifdef BACKFACE_ON
	ctx.worldNormal *= -1;
#endif

	ctx.worldPos = i.worldPosAndZ.xyz;
	ctx.worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPosAndZ.xyz);

}

void fetchShadowTerm(inout ShadingContext ctx, in v2f i)
{
#if !defined(BACKFACE_ON)
	ctx.shadow = SHADOW_ATTENUATION(i);
#else
	ctx.shadow = 1;
#endif
}

void fetchAlbedoAndDimmed(inout ShadingContext ctx, in v2f i)
{
	ctx.albedo = tex2D(_MainTex, i.uv.xy);

#if _DIM_ON
	ctx.dimmed = tex2D(_DimTex, i.uv.xy);
#else
	half3 dimmed = ctx.albedo.rgb;
	dimmed = dimmed * dimmed * 0.25;
	ctx.dimmed = half4(dimmed, ctx.albedo.a);
#endif

#if _OVERLAY_ON
	half4 overlay = tex2D(_OverlayTex, i.uv.zw);

	half t = overlay.a;
	t = (1-cos(t*3.1415926)) / 2;

	ctx.albedo.rgb = lerp(ctx.albedo.rgb, overlay.rgb, t);
	ctx.dimmed.rgb = lerp(ctx.dimmed.rgb, overlay.rgb, t);
#endif

}

void applyLightingFwdBase(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_OFF
	half ndotl = dot(ctx.worldNormal, _WorldSpaceLightPos0.xyz);
	#if _DIFFUSE_LUT_ON
		half2 screenuv = i.pos.xy * _ScreenParams.zw - i.pos.xy;
		half occl = tex2D(_MudSSAOTex, screenuv).r;
		occl = saturate(occl * occl * 4);
		occl = 1 - occl;
		ndotl = dot(ctx.worldNormal, autoLightDir());

		half lightingControl = i.vcolor.r;
		ndotl = lerp(1.0, tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r * occl, lightingControl);
	#else
		ndotl = saturate(ndotl);
		ndotl = ndotl * ndotl * ctx.shadow;
	#endif

	half3 lighting = lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb;

	#if _IRRADIANCE_ON
		half3 irrad = half3(0, 0, 0);
		#ifdef DYNAMICLIGHTMAP_ON

			irrad = DecodeRealtimeLightmap (UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.lmap.zw));

			#if DIRLIGHTMAP_COMBINED
				fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_DynamicDirectionality, unity_DynamicLightmap, i.lmap.zw);
				irrad = DecodeDirectionalLightmap (irrad, dirmap, ctx.worldNormal);
			#endif

		#elif UNITY_SHOULD_SAMPLE_SH

			#if UNITY_VERSION < 540
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad);
			#else
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad, ctx.worldPos);
			#endif
		#endif

		lighting += irrad * irrad * pow(ctx.albedo, 0.5) * (1.0 + _IrradianceBoost);
	#endif

	ctx.result.rgb += lighting;

#endif
}

void applyLightingFwdAdd(inout ShadingContext ctx, in v2f i)
{
    UNITY_LIGHT_ATTENUATION(lightShadowAndAtten, i, i.worldPosAndZ.xyz);

	half ndotl = dot(ctx.worldNormal, normalize(_WorldSpaceLightPos0.xyz - ctx.worldPos));
	#if _DIFFUSE_LUT_ON
	ndotl = tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r;
	#else
	ndotl = saturate(ndotl) * ctx.shadow;
	#endif
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb * lightShadowAndAtten;
}

void applyLightmap(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_ON

	half3 lmap = DecodeLightmap (UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lmap.xy));

	#if DIRLIGHTMAP_COMBINED
		fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, i.lmap.xy);
		lmap = DecodeDirectionalLightmap (lmap, dirmap, ctx.worldNormal);
	#endif

	half lum = Luminance(lmap) * ctx.shadow;
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, lum) * lmap;

#endif
}

void applyDarkenBackFace(inout ShadingContext ctx, in v2f i)
{
#if _DARKEN_BACKFACES_ON
#ifdef BACKFACE_ON
    	ctx.result.rgb = ctx.dimmed * (1.0 / 64.0);
#endif
#endif
}

void applyRim(inout ShadingContext ctx, in v2f i)
{
#if _RIM_ON
	half vdotl = dot(ctx.worldNormal, ctx.worldViewDir);
	vdotl = tex2D(_RimLUTTex, saturate(vdotl * 0.5 + 0.5)).r;

	ctx.result.rgb += vdotl * ctx.albedo * _RimIntensity;

#endif
}

void applyMatcap(inout ShadingContext ctx, in v2f i)
{
#if _MATCAP_ON
	half3 rx = half3(1, 0, 0);
	half3 ry = half3(0, 1, 0);
	half3 rz = UNITY_MATRIX_V[2].xyz;

	rx = cross(ry, rz);
	ry = cross(rz, rx);

	half3x3 m;
	m[0] = rx;
	m[1] = -ry;
	m[2] = rz;
	#if _MATCAP_PLANAR_ON
		half3 dir = reflect(ctx.worldViewDir, ctx.worldNormal);
		dir = normalize(mul(m, dir));
		half2 mapCapUV = saturate(dir.xy * 0.5 + 0.5);
	#else
		half3 viewNormal = mul(m, ctx.worldNormal);
		half2 mapCapUV = saturate(viewNormal.xy * 0.5 + 0.5);
	#endif

	half4 mapCap = tex2D(_MatCapTex, mapCapUV);
	mapCap = mapCap * ctx.albedo.a * _MatCapIntensity;
	#if _MATCAP_ALBEDO_ON
		mapCap.rgb *= ctx.albedo.rgb;
	#endif
	ctx.result.rgb += mapCap;
	//ctx.result.rgb = half3(mapCapUV.xy, 0);
#endif
}

void shadingContext(inout ShadingContext ctx, in v2f i, in fixed vface)
{
	ctx = (ShadingContext)0;
	ctx.vface = vface;
	fetchAlbedoAndDimmed(ctx, i);
	fetchShadowTerm(ctx, i);
	fetchWorldNormal(ctx, i);

	ctx.result = half4(0, 0, 0, ctx.albedo.a);
}


half dither(in v2f i)
{
	half d1 = Bayer(i.pos.xy + float2(UNITY_MATRIX_MV._14, UNITY_MATRIX_MV._24));
	//half d2 = InterleavedGradientNoise(i.pos.xy);
	//return (d1 + d2) * 0.5;
	return d1;
}

void fade(inout ShadingContext ctx, in v2f i)
{
	half viewZ = i.worldPosAndZ.w;
	half d = dither(i);

	half fading = _FadeOut;
	fading = fading * 2.0 - 1.0;
	clip(d - fading);

#if _TEXTURE_FADE_OUT_ON
	clip(d + ctx.albedo.a);
#endif

	half bZ = _ProjectionParams.y * 2;
	half eZ = _ProjectionParams.y * 6;
	half rZ = eZ - bZ;
	half f = (viewZ - bZ) / rZ; // do not clamp f to [0, 1]

	f = f + d * rZ;
	clip(f);
}


half4 frag_base (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

   	fade(ctx, i);

	applyLightingFwdBase(ctx, i);

	applyLightmap(ctx, i);

	applyRim(ctx, i);

	applyMatcap(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}


half4 frag_add (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

    fade(ctx, i);

    applyLightingFwdAdd(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}
			ENDCG
		}

		Pass
		{
			Tags
			{
				"LightMode"="ForwardBase"
			}
			Cull Front

		    CGPROGRAM
			#define BACKFACE_ON
			#include "UnityCG.cginc"

#if UNITY_VERSION < 540
#define UNITY_SHADER_NO_UPGRADE
#define unity_ObjectToWorld _Object2World 
#define unity_WorldToObject _World2Object
#define unity_WorldToLight _LightMatrix0
#define unity_WorldToCamera _WorldToCamera
#define unity_CameraToWorld _CameraToWorld
#define unity_Projector _Projector
#define unity_ProjectorDistance _ProjectorDistance
#define unity_ProjectorClip _ProjectorClip
#define unity_GUIClipTextureMatrix _GUIClipTextureMatrix 
#endif

			#include "Lighting.cginc"
#include "AutoLight.cginc"

#ifdef POINT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = (tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL);
#endif

#ifdef SPOT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); \
	fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz);
#endif

#ifdef DIRECTIONAL
	#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos)	fixed destName = 1;
#endif


#ifdef POINT_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL * texCUBE(_LightTexture0, lightCoord).w;
#endif

#ifdef DIRECTIONAL_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; \
	fixed destName = tex2D(_LightTexture0, lightCoord).w;
#endif


half3 autoLightDir()
{
    half3 camRight = UNITY_MATRIX_V[0].xyz;
    half3 camFwd = UNITY_MATRIX_V[2].xyz;
    half3 worldUp = half3(0, 1, 0);

    return normalize(camFwd);
    //return normalize(camFwd + camRight * -0.125f + worldUp * 0.5);
}

			uniform sampler2D _BayerTex;
uniform float4 _BayerTex_TexelSize;

#define F1 float
#define F2 float2
#define F3 float3
#define F4 float4
#define fract frac
#define iGlobalTime _Time.y * 16.0

F1 Noise(F2 n,F1 x){n+=x;return fract(sin(dot(n.xy,F2(12.9898, 78.233)))*43758.5453)*2.0-1.0;}

// Step 1 in generation of the dither source texture.
F1 Step1(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-12.0,t=1.0;   
    return (1.0/(a*4.0+b*4.0-c))*(
        Noise(uv+F2(-1.0,-1.0)*t,n)*a+
        Noise(uv+F2( 0.0,-1.0)*t,n)*b+
        Noise(uv+F2( 1.0,-1.0)*t,n)*a+
        Noise(uv+F2(-1.0, 0.0)*t,n)*b+
        Noise(uv+F2( 0.0, 0.0)*t,n)*c+
        Noise(uv+F2( 1.0, 0.0)*t,n)*b+
        Noise(uv+F2(-1.0, 1.0)*t,n)*a+
        Noise(uv+F2( 0.0, 1.0)*t,n)*b+
        Noise(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Step 2 in generation of the dither source texture.
F1 Step2(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-2.0,t=1.0;
    return (4.0/(a*4.0+b*4.0-c))*(
        Step1(uv+F2(-1.0,-1.0)*t,n)*a+
        Step1(uv+F2( 0.0,-1.0)*t,n)*b+
        Step1(uv+F2( 1.0,-1.0)*t,n)*a+
        Step1(uv+F2(-1.0, 0.0)*t,n)*b+
        Step1(uv+F2( 0.0, 0.0)*t,n)*c+
        Step1(uv+F2( 1.0, 0.0)*t,n)*b+
        Step1(uv+F2(-1.0, 1.0)*t,n)*a+
        Step1(uv+F2( 0.0, 1.0)*t,n)*b+
        Step1(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Used for stills.
F3 Step3(F2 uv){
    F1 a=Step2(uv,0.07);    
    #ifdef CHROMATIC
    F1 b=Step2(uv,0.11);    
    F1 c=Step2(uv,0.13);
    return F3(a,b,c);
    #else
    // Monochrome can look better on stills.
    return F3(a, a, a);
    #endif
}

// Used for temporal dither.
F3 Step3T(F2 uv){
    F1 a=Step2(uv,0.07*(fract(iGlobalTime)+1.0));
    F1 b=Step2(uv,0.11*(fract(iGlobalTime)+1.0));
    F1 c=Step2(uv,0.13*(fract(iGlobalTime)+1.0));
    return F3(a,b,c);}

F1 InterleavedGradientNoise( F2 uv )
{
	const F3 magic = F3( 0.06711056, 0.00583715, 52.9829189 );
	F1 n = fract( magic.z * fract( dot( uv, magic.xy ) ) );
	return n * 2.0 - 1.0;
}

F1 Bayer( F2 uv )
{
	F2 val = dot(tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).rg, F2(256.0 * 255.0, 255.0));
	val = val * _BayerTex_TexelSize.x * _BayerTex_TexelSize.y;
	return val * 2.0 - 1.0;
	//return (tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).r) * 2.0 - 1.0;
}
// ====

			#pragma vertex vert
#pragma fragment frag_base
#pragma multi_compile_fwdbase novertexlight LIGHTMAP_OFF LIGHTMAP_ON DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED
#pragma target 3.0

#pragma shader_feature _TEXTURE_FADE_OUT_ON
#pragma shader_feature _IRRADIANCE_ON
#pragma shader_feature _NORMAL_MAP_ON
#pragma shader_feature _DARKEN_BACKFACES_ON
#pragma shader_feature _DIM_ON
#pragma shader_feature _OVERLAY_ON
#pragma shader_feature _DIFFUSE_LUT_ON
#pragma shader_feature _RIM_ON
#pragma shader_feature _MATCAP_ON
#pragma shader_feature _MATCAP_PLANAR_ON
#pragma shader_feature _MATCAP_ALBEDO_ON
//#pragma enable_d3d11_debug_symbols
			/// Vertex
///
struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 vcolor : COLOR;
    float2 texcoord : TEXCOORD0;
#if _OVERLAY_ON
    float2 texcoord1 : TEXCOORD1;

	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD2;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD3;
	#endif

#else
	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD1;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD2;
	#endif

#endif

#if _NORMAL_MAP_ON
	float4 tangent : TANGENT;
#endif
};

struct v2f
{
	float4 vcolor : COLOR;
    float4 uv : TEXCOORD0;
    SHADOW_COORDS(1) // put shadows data into TEXCOORD1
    float4 worldPosAndZ : TEXCOORD2;

#if _NORMAL_MAP_ON
	float4 tanSpace0 : TEXCOORD3;
	float4 tanSpace1 : TEXCOORD4;
	float4 tanSpace2 : TEXCOORD5;
#else
	float3 worldNormal : TEXCOORD3;
#endif

#if !defined(LIGHTMAP_OFF) || !defined(DYNAMICLIGHTMAP_OFF)
	float4 lmap : TEXCOORD6;
#endif

    float4 pos : SV_POSITION;
};

v2f vert (appdata v)
{
    v2f o;
    o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
    o.vcolor = v.vcolor;
    o.uv = v.texcoord.xyxy;
#if _OVERLAY_ON
    o.uv.zw = v.texcoord1;
#endif
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);

#if _NORMAL_MAP_ON
	float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
	float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
	float3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
	o.tanSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, 0);
	o.tanSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, 0);
	o.tanSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, 0);
#else
	o.worldNormal = worldNormal;
#endif

    o.worldPosAndZ.xyz = mul(unity_ObjectToWorld, v.vertex).xyz;

#ifndef LIGHTMAP_OFF
	o.lmap = v.lmapcoord.xyxy * unity_LightmapST.xyxy + unity_LightmapST.zwzw;
#endif

#ifndef DYNAMICLIGHTMAP_OFF
	o.lmap.zw = v.dlmapcoord.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

    COMPUTE_EYEDEPTH(o.worldPosAndZ.w);
    // compute shadows data
    TRANSFER_SHADOW(o)
    return o;
}

///
/// Fragment
///
uniform sampler2D _MainTex;

uniform float _FadeOut;

#if _IRRADIANCE_ON
uniform float _IrradianceBoost;
#endif

#if _NORMAL_MAP_ON
uniform sampler2D _NormalMapTex;
#endif

#if _DIM_ON
uniform sampler2D _DimTex;
#endif

#if _OVERLAY_ON
uniform sampler2D _OverlayTex;
#endif

#if _DIFFUSE_LUT_ON
uniform sampler2D _DiffuseLUTTex;
uniform sampler2D _MudSSAOTex; // global property
#endif

#if _RIM_ON
uniform sampler2D _RimLUTTex;
uniform float _RimIntensity;
#endif

#if _MATCAP_ON
uniform sampler2D _MatCapTex;
uniform float _MatCapIntensity;
#endif

struct ShadingContext
{
	half4 albedo;
	half4 dimmed;
	half3 worldNormal;
	half3 worldViewDir;
	half3 worldPos;
	fixed vface;
	fixed shadow;
	half4 result;
};

void fetchWorldNormal(inout ShadingContext ctx, in v2f i)
{
#if _NORMAL_MAP_ON
	half3 tanNormal = UnpackNormal(tex2D(_NormalMapTex, i.uv.xy));
	half3 worldNormal;
	worldNormal.x = dot(i.tanSpace0.xyz, tanNormal);
	worldNormal.y = dot(i.tanSpace1.xyz, tanNormal);
	worldNormal.z = dot(i.tanSpace2.xyz, tanNormal);
	ctx.worldNormal = normalize(worldNormal);
#else
	ctx.worldNormal = normalize(i.worldNormal);
#endif

#ifdef BACKFACE_ON
	ctx.worldNormal *= -1;
#endif

	ctx.worldPos = i.worldPosAndZ.xyz;
	ctx.worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPosAndZ.xyz);

}

void fetchShadowTerm(inout ShadingContext ctx, in v2f i)
{
#if !defined(BACKFACE_ON)
	ctx.shadow = SHADOW_ATTENUATION(i);
#else
	ctx.shadow = 1;
#endif
}

void fetchAlbedoAndDimmed(inout ShadingContext ctx, in v2f i)
{
	ctx.albedo = tex2D(_MainTex, i.uv.xy);

#if _DIM_ON
	ctx.dimmed = tex2D(_DimTex, i.uv.xy);
#else
	half3 dimmed = ctx.albedo.rgb;
	dimmed = dimmed * dimmed * 0.25;
	ctx.dimmed = half4(dimmed, ctx.albedo.a);
#endif

#if _OVERLAY_ON
	half4 overlay = tex2D(_OverlayTex, i.uv.zw);

	half t = overlay.a;
	t = (1-cos(t*3.1415926)) / 2;

	ctx.albedo.rgb = lerp(ctx.albedo.rgb, overlay.rgb, t);
	ctx.dimmed.rgb = lerp(ctx.dimmed.rgb, overlay.rgb, t);
#endif

}

void applyLightingFwdBase(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_OFF
	half ndotl = dot(ctx.worldNormal, _WorldSpaceLightPos0.xyz);
	#if _DIFFUSE_LUT_ON
		half2 screenuv = i.pos.xy * _ScreenParams.zw - i.pos.xy;
		half occl = tex2D(_MudSSAOTex, screenuv).r;
		occl = saturate(occl * occl * 4);
		occl = 1 - occl;
		ndotl = dot(ctx.worldNormal, autoLightDir());

		half lightingControl = i.vcolor.r;
		ndotl = lerp(1.0, tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r * occl, lightingControl);
	#else
		ndotl = saturate(ndotl);
		ndotl = ndotl * ndotl * ctx.shadow;
	#endif

	half3 lighting = lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb;

	#if _IRRADIANCE_ON
		half3 irrad = half3(0, 0, 0);
		#ifdef DYNAMICLIGHTMAP_ON

			irrad = DecodeRealtimeLightmap (UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.lmap.zw));

			#if DIRLIGHTMAP_COMBINED
				fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_DynamicDirectionality, unity_DynamicLightmap, i.lmap.zw);
				irrad = DecodeDirectionalLightmap (irrad, dirmap, ctx.worldNormal);
			#endif

		#elif UNITY_SHOULD_SAMPLE_SH

			#if UNITY_VERSION < 540
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad);
			#else
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad, ctx.worldPos);
			#endif
		#endif

		lighting += irrad * irrad * pow(ctx.albedo, 0.5) * (1.0 + _IrradianceBoost);
	#endif

	ctx.result.rgb += lighting;

#endif
}

void applyLightingFwdAdd(inout ShadingContext ctx, in v2f i)
{
    UNITY_LIGHT_ATTENUATION(lightShadowAndAtten, i, i.worldPosAndZ.xyz);

	half ndotl = dot(ctx.worldNormal, normalize(_WorldSpaceLightPos0.xyz - ctx.worldPos));
	#if _DIFFUSE_LUT_ON
	ndotl = tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r;
	#else
	ndotl = saturate(ndotl) * ctx.shadow;
	#endif
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb * lightShadowAndAtten;
}

void applyLightmap(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_ON

	half3 lmap = DecodeLightmap (UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lmap.xy));

	#if DIRLIGHTMAP_COMBINED
		fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, i.lmap.xy);
		lmap = DecodeDirectionalLightmap (lmap, dirmap, ctx.worldNormal);
	#endif

	half lum = Luminance(lmap) * ctx.shadow;
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, lum) * lmap;

#endif
}

void applyDarkenBackFace(inout ShadingContext ctx, in v2f i)
{
#if _DARKEN_BACKFACES_ON
#ifdef BACKFACE_ON
    	ctx.result.rgb = ctx.dimmed * (1.0 / 64.0);
#endif
#endif
}

void applyRim(inout ShadingContext ctx, in v2f i)
{
#if _RIM_ON
	half vdotl = dot(ctx.worldNormal, ctx.worldViewDir);
	vdotl = tex2D(_RimLUTTex, saturate(vdotl * 0.5 + 0.5)).r;

	ctx.result.rgb += vdotl * ctx.albedo * _RimIntensity;

#endif
}

void applyMatcap(inout ShadingContext ctx, in v2f i)
{
#if _MATCAP_ON
	half3 rx = half3(1, 0, 0);
	half3 ry = half3(0, 1, 0);
	half3 rz = UNITY_MATRIX_V[2].xyz;

	rx = cross(ry, rz);
	ry = cross(rz, rx);

	half3x3 m;
	m[0] = rx;
	m[1] = -ry;
	m[2] = rz;
	#if _MATCAP_PLANAR_ON
		half3 dir = reflect(ctx.worldViewDir, ctx.worldNormal);
		dir = normalize(mul(m, dir));
		half2 mapCapUV = saturate(dir.xy * 0.5 + 0.5);
	#else
		half3 viewNormal = mul(m, ctx.worldNormal);
		half2 mapCapUV = saturate(viewNormal.xy * 0.5 + 0.5);
	#endif

	half4 mapCap = tex2D(_MatCapTex, mapCapUV);
	mapCap = mapCap * ctx.albedo.a * _MatCapIntensity;
	#if _MATCAP_ALBEDO_ON
		mapCap.rgb *= ctx.albedo.rgb;
	#endif
	ctx.result.rgb += mapCap;
	//ctx.result.rgb = half3(mapCapUV.xy, 0);
#endif
}

void shadingContext(inout ShadingContext ctx, in v2f i, in fixed vface)
{
	ctx = (ShadingContext)0;
	ctx.vface = vface;
	fetchAlbedoAndDimmed(ctx, i);
	fetchShadowTerm(ctx, i);
	fetchWorldNormal(ctx, i);

	ctx.result = half4(0, 0, 0, ctx.albedo.a);
}


half dither(in v2f i)
{
	half d1 = Bayer(i.pos.xy + float2(UNITY_MATRIX_MV._14, UNITY_MATRIX_MV._24));
	//half d2 = InterleavedGradientNoise(i.pos.xy);
	//return (d1 + d2) * 0.5;
	return d1;
}

void fade(inout ShadingContext ctx, in v2f i)
{
	half viewZ = i.worldPosAndZ.w;
	half d = dither(i);

	half fading = _FadeOut;
	fading = fading * 2.0 - 1.0;
	clip(d - fading);

#if _TEXTURE_FADE_OUT_ON
	clip(d + ctx.albedo.a);
#endif

	half bZ = _ProjectionParams.y * 2;
	half eZ = _ProjectionParams.y * 6;
	half rZ = eZ - bZ;
	half f = (viewZ - bZ) / rZ; // do not clamp f to [0, 1]

	f = f + d * rZ;
	clip(f);
}


half4 frag_base (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

   	fade(ctx, i);

	applyLightingFwdBase(ctx, i);

	applyLightmap(ctx, i);

	applyRim(ctx, i);

	applyMatcap(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}


half4 frag_add (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

    fade(ctx, i);

    applyLightingFwdAdd(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}    
			ENDCG
		}

		Pass
		{
			Tags
			{
				"LightMode"="ForwardAdd"
			}

			ZWrite Off
			ZTest LEqual
			Blend One One
			Cull Back

			CGPROGRAM
			#include "UnityCG.cginc"

#if UNITY_VERSION < 540
#define UNITY_SHADER_NO_UPGRADE
#define unity_ObjectToWorld _Object2World 
#define unity_WorldToObject _World2Object
#define unity_WorldToLight _LightMatrix0
#define unity_WorldToCamera _WorldToCamera
#define unity_CameraToWorld _CameraToWorld
#define unity_Projector _Projector
#define unity_ProjectorDistance _ProjectorDistance
#define unity_ProjectorClip _ProjectorClip
#define unity_GUIClipTextureMatrix _GUIClipTextureMatrix 
#endif

			#include "Lighting.cginc"
#include "AutoLight.cginc"

#ifdef POINT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = (tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL);
#endif

#ifdef SPOT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); \
	fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz);
#endif

#ifdef DIRECTIONAL
	#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos)	fixed destName = 1;
#endif


#ifdef POINT_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL * texCUBE(_LightTexture0, lightCoord).w;
#endif

#ifdef DIRECTIONAL_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; \
	fixed destName = tex2D(_LightTexture0, lightCoord).w;
#endif


half3 autoLightDir()
{
    half3 camRight = UNITY_MATRIX_V[0].xyz;
    half3 camFwd = UNITY_MATRIX_V[2].xyz;
    half3 worldUp = half3(0, 1, 0);

    return normalize(camFwd);
    //return normalize(camFwd + camRight * -0.125f + worldUp * 0.5);
}

			uniform sampler2D _BayerTex;
uniform float4 _BayerTex_TexelSize;

#define F1 float
#define F2 float2
#define F3 float3
#define F4 float4
#define fract frac
#define iGlobalTime _Time.y * 16.0

F1 Noise(F2 n,F1 x){n+=x;return fract(sin(dot(n.xy,F2(12.9898, 78.233)))*43758.5453)*2.0-1.0;}

// Step 1 in generation of the dither source texture.
F1 Step1(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-12.0,t=1.0;   
    return (1.0/(a*4.0+b*4.0-c))*(
        Noise(uv+F2(-1.0,-1.0)*t,n)*a+
        Noise(uv+F2( 0.0,-1.0)*t,n)*b+
        Noise(uv+F2( 1.0,-1.0)*t,n)*a+
        Noise(uv+F2(-1.0, 0.0)*t,n)*b+
        Noise(uv+F2( 0.0, 0.0)*t,n)*c+
        Noise(uv+F2( 1.0, 0.0)*t,n)*b+
        Noise(uv+F2(-1.0, 1.0)*t,n)*a+
        Noise(uv+F2( 0.0, 1.0)*t,n)*b+
        Noise(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Step 2 in generation of the dither source texture.
F1 Step2(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-2.0,t=1.0;
    return (4.0/(a*4.0+b*4.0-c))*(
        Step1(uv+F2(-1.0,-1.0)*t,n)*a+
        Step1(uv+F2( 0.0,-1.0)*t,n)*b+
        Step1(uv+F2( 1.0,-1.0)*t,n)*a+
        Step1(uv+F2(-1.0, 0.0)*t,n)*b+
        Step1(uv+F2( 0.0, 0.0)*t,n)*c+
        Step1(uv+F2( 1.0, 0.0)*t,n)*b+
        Step1(uv+F2(-1.0, 1.0)*t,n)*a+
        Step1(uv+F2( 0.0, 1.0)*t,n)*b+
        Step1(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Used for stills.
F3 Step3(F2 uv){
    F1 a=Step2(uv,0.07);    
    #ifdef CHROMATIC
    F1 b=Step2(uv,0.11);    
    F1 c=Step2(uv,0.13);
    return F3(a,b,c);
    #else
    // Monochrome can look better on stills.
    return F3(a, a, a);
    #endif
}

// Used for temporal dither.
F3 Step3T(F2 uv){
    F1 a=Step2(uv,0.07*(fract(iGlobalTime)+1.0));
    F1 b=Step2(uv,0.11*(fract(iGlobalTime)+1.0));
    F1 c=Step2(uv,0.13*(fract(iGlobalTime)+1.0));
    return F3(a,b,c);}

F1 InterleavedGradientNoise( F2 uv )
{
	const F3 magic = F3( 0.06711056, 0.00583715, 52.9829189 );
	F1 n = fract( magic.z * fract( dot( uv, magic.xy ) ) );
	return n * 2.0 - 1.0;
}

F1 Bayer( F2 uv )
{
	F2 val = dot(tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).rg, F2(256.0 * 255.0, 255.0));
	val = val * _BayerTex_TexelSize.x * _BayerTex_TexelSize.y;
	return val * 2.0 - 1.0;
	//return (tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).r) * 2.0 - 1.0;
}
// ====

			#pragma vertex vert
#pragma fragment frag_add
#pragma multi_compile_fwdadd_fullshadows
#pragma target 3.0

#pragma shader_feature _TEXTURE_FADE_OUT_ON
#pragma shader_feature _NORMAL_MAP_ON
#pragma shader_feature _DARKEN_BACKFACES_ON
#pragma shader_feature _DIM_ON
#pragma shader_feature _OVERLAY_ON
#pragma shader_feature _DIFFUSE_LUT_ON
//#pragma enable_d3d11_debug_symbols
			/// Vertex
///
struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 vcolor : COLOR;
    float2 texcoord : TEXCOORD0;
#if _OVERLAY_ON
    float2 texcoord1 : TEXCOORD1;

	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD2;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD3;
	#endif

#else
	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD1;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD2;
	#endif

#endif

#if _NORMAL_MAP_ON
	float4 tangent : TANGENT;
#endif
};

struct v2f
{
	float4 vcolor : COLOR;
    float4 uv : TEXCOORD0;
    SHADOW_COORDS(1) // put shadows data into TEXCOORD1
    float4 worldPosAndZ : TEXCOORD2;

#if _NORMAL_MAP_ON
	float4 tanSpace0 : TEXCOORD3;
	float4 tanSpace1 : TEXCOORD4;
	float4 tanSpace2 : TEXCOORD5;
#else
	float3 worldNormal : TEXCOORD3;
#endif

#if !defined(LIGHTMAP_OFF) || !defined(DYNAMICLIGHTMAP_OFF)
	float4 lmap : TEXCOORD6;
#endif

    float4 pos : SV_POSITION;
};

v2f vert (appdata v)
{
    v2f o;
    o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
    o.vcolor = v.vcolor;
    o.uv = v.texcoord.xyxy;
#if _OVERLAY_ON
    o.uv.zw = v.texcoord1;
#endif
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);

#if _NORMAL_MAP_ON
	float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
	float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
	float3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
	o.tanSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, 0);
	o.tanSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, 0);
	o.tanSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, 0);
#else
	o.worldNormal = worldNormal;
#endif

    o.worldPosAndZ.xyz = mul(unity_ObjectToWorld, v.vertex).xyz;

#ifndef LIGHTMAP_OFF
	o.lmap = v.lmapcoord.xyxy * unity_LightmapST.xyxy + unity_LightmapST.zwzw;
#endif

#ifndef DYNAMICLIGHTMAP_OFF
	o.lmap.zw = v.dlmapcoord.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

    COMPUTE_EYEDEPTH(o.worldPosAndZ.w);
    // compute shadows data
    TRANSFER_SHADOW(o)
    return o;
}

///
/// Fragment
///
uniform sampler2D _MainTex;

uniform float _FadeOut;

#if _IRRADIANCE_ON
uniform float _IrradianceBoost;
#endif

#if _NORMAL_MAP_ON
uniform sampler2D _NormalMapTex;
#endif

#if _DIM_ON
uniform sampler2D _DimTex;
#endif

#if _OVERLAY_ON
uniform sampler2D _OverlayTex;
#endif

#if _DIFFUSE_LUT_ON
uniform sampler2D _DiffuseLUTTex;
uniform sampler2D _MudSSAOTex; // global property
#endif

#if _RIM_ON
uniform sampler2D _RimLUTTex;
uniform float _RimIntensity;
#endif

#if _MATCAP_ON
uniform sampler2D _MatCapTex;
uniform float _MatCapIntensity;
#endif

struct ShadingContext
{
	half4 albedo;
	half4 dimmed;
	half3 worldNormal;
	half3 worldViewDir;
	half3 worldPos;
	fixed vface;
	fixed shadow;
	half4 result;
};

void fetchWorldNormal(inout ShadingContext ctx, in v2f i)
{
#if _NORMAL_MAP_ON
	half3 tanNormal = UnpackNormal(tex2D(_NormalMapTex, i.uv.xy));
	half3 worldNormal;
	worldNormal.x = dot(i.tanSpace0.xyz, tanNormal);
	worldNormal.y = dot(i.tanSpace1.xyz, tanNormal);
	worldNormal.z = dot(i.tanSpace2.xyz, tanNormal);
	ctx.worldNormal = normalize(worldNormal);
#else
	ctx.worldNormal = normalize(i.worldNormal);
#endif

#ifdef BACKFACE_ON
	ctx.worldNormal *= -1;
#endif

	ctx.worldPos = i.worldPosAndZ.xyz;
	ctx.worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPosAndZ.xyz);

}

void fetchShadowTerm(inout ShadingContext ctx, in v2f i)
{
#if !defined(BACKFACE_ON)
	ctx.shadow = SHADOW_ATTENUATION(i);
#else
	ctx.shadow = 1;
#endif
}

void fetchAlbedoAndDimmed(inout ShadingContext ctx, in v2f i)
{
	ctx.albedo = tex2D(_MainTex, i.uv.xy);

#if _DIM_ON
	ctx.dimmed = tex2D(_DimTex, i.uv.xy);
#else
	half3 dimmed = ctx.albedo.rgb;
	dimmed = dimmed * dimmed * 0.25;
	ctx.dimmed = half4(dimmed, ctx.albedo.a);
#endif

#if _OVERLAY_ON
	half4 overlay = tex2D(_OverlayTex, i.uv.zw);

	half t = overlay.a;
	t = (1-cos(t*3.1415926)) / 2;

	ctx.albedo.rgb = lerp(ctx.albedo.rgb, overlay.rgb, t);
	ctx.dimmed.rgb = lerp(ctx.dimmed.rgb, overlay.rgb, t);
#endif

}

void applyLightingFwdBase(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_OFF
	half ndotl = dot(ctx.worldNormal, _WorldSpaceLightPos0.xyz);
	#if _DIFFUSE_LUT_ON
		half2 screenuv = i.pos.xy * _ScreenParams.zw - i.pos.xy;
		half occl = tex2D(_MudSSAOTex, screenuv).r;
		occl = saturate(occl * occl * 4);
		occl = 1 - occl;
		ndotl = dot(ctx.worldNormal, autoLightDir());

		half lightingControl = i.vcolor.r;
		ndotl = lerp(1.0, tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r * occl, lightingControl);
	#else
		ndotl = saturate(ndotl);
		ndotl = ndotl * ndotl * ctx.shadow;
	#endif

	half3 lighting = lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb;

	#if _IRRADIANCE_ON
		half3 irrad = half3(0, 0, 0);
		#ifdef DYNAMICLIGHTMAP_ON

			irrad = DecodeRealtimeLightmap (UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.lmap.zw));

			#if DIRLIGHTMAP_COMBINED
				fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_DynamicDirectionality, unity_DynamicLightmap, i.lmap.zw);
				irrad = DecodeDirectionalLightmap (irrad, dirmap, ctx.worldNormal);
			#endif

		#elif UNITY_SHOULD_SAMPLE_SH

			#if UNITY_VERSION < 540
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad);
			#else
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad, ctx.worldPos);
			#endif
		#endif

		lighting += irrad * irrad * pow(ctx.albedo, 0.5) * (1.0 + _IrradianceBoost);
	#endif

	ctx.result.rgb += lighting;

#endif
}

void applyLightingFwdAdd(inout ShadingContext ctx, in v2f i)
{
    UNITY_LIGHT_ATTENUATION(lightShadowAndAtten, i, i.worldPosAndZ.xyz);

	half ndotl = dot(ctx.worldNormal, normalize(_WorldSpaceLightPos0.xyz - ctx.worldPos));
	#if _DIFFUSE_LUT_ON
	ndotl = tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r;
	#else
	ndotl = saturate(ndotl) * ctx.shadow;
	#endif
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb * lightShadowAndAtten;
}

void applyLightmap(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_ON

	half3 lmap = DecodeLightmap (UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lmap.xy));

	#if DIRLIGHTMAP_COMBINED
		fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, i.lmap.xy);
		lmap = DecodeDirectionalLightmap (lmap, dirmap, ctx.worldNormal);
	#endif

	half lum = Luminance(lmap) * ctx.shadow;
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, lum) * lmap;

#endif
}

void applyDarkenBackFace(inout ShadingContext ctx, in v2f i)
{
#if _DARKEN_BACKFACES_ON
#ifdef BACKFACE_ON
    	ctx.result.rgb = ctx.dimmed * (1.0 / 64.0);
#endif
#endif
}

void applyRim(inout ShadingContext ctx, in v2f i)
{
#if _RIM_ON
	half vdotl = dot(ctx.worldNormal, ctx.worldViewDir);
	vdotl = tex2D(_RimLUTTex, saturate(vdotl * 0.5 + 0.5)).r;

	ctx.result.rgb += vdotl * ctx.albedo * _RimIntensity;

#endif
}

void applyMatcap(inout ShadingContext ctx, in v2f i)
{
#if _MATCAP_ON
	half3 rx = half3(1, 0, 0);
	half3 ry = half3(0, 1, 0);
	half3 rz = UNITY_MATRIX_V[2].xyz;

	rx = cross(ry, rz);
	ry = cross(rz, rx);

	half3x3 m;
	m[0] = rx;
	m[1] = -ry;
	m[2] = rz;
	#if _MATCAP_PLANAR_ON
		half3 dir = reflect(ctx.worldViewDir, ctx.worldNormal);
		dir = normalize(mul(m, dir));
		half2 mapCapUV = saturate(dir.xy * 0.5 + 0.5);
	#else
		half3 viewNormal = mul(m, ctx.worldNormal);
		half2 mapCapUV = saturate(viewNormal.xy * 0.5 + 0.5);
	#endif

	half4 mapCap = tex2D(_MatCapTex, mapCapUV);
	mapCap = mapCap * ctx.albedo.a * _MatCapIntensity;
	#if _MATCAP_ALBEDO_ON
		mapCap.rgb *= ctx.albedo.rgb;
	#endif
	ctx.result.rgb += mapCap;
	//ctx.result.rgb = half3(mapCapUV.xy, 0);
#endif
}

void shadingContext(inout ShadingContext ctx, in v2f i, in fixed vface)
{
	ctx = (ShadingContext)0;
	ctx.vface = vface;
	fetchAlbedoAndDimmed(ctx, i);
	fetchShadowTerm(ctx, i);
	fetchWorldNormal(ctx, i);

	ctx.result = half4(0, 0, 0, ctx.albedo.a);
}


half dither(in v2f i)
{
	half d1 = Bayer(i.pos.xy + float2(UNITY_MATRIX_MV._14, UNITY_MATRIX_MV._24));
	//half d2 = InterleavedGradientNoise(i.pos.xy);
	//return (d1 + d2) * 0.5;
	return d1;
}

void fade(inout ShadingContext ctx, in v2f i)
{
	half viewZ = i.worldPosAndZ.w;
	half d = dither(i);

	half fading = _FadeOut;
	fading = fading * 2.0 - 1.0;
	clip(d - fading);

#if _TEXTURE_FADE_OUT_ON
	clip(d + ctx.albedo.a);
#endif

	half bZ = _ProjectionParams.y * 2;
	half eZ = _ProjectionParams.y * 6;
	half rZ = eZ - bZ;
	half f = (viewZ - bZ) / rZ; // do not clamp f to [0, 1]

	f = f + d * rZ;
	clip(f);
}


half4 frag_base (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

   	fade(ctx, i);

	applyLightingFwdBase(ctx, i);

	applyLightmap(ctx, i);

	applyRim(ctx, i);

	applyMatcap(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}


half4 frag_add (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

    fade(ctx, i);

    applyLightingFwdAdd(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}
			ENDCG
		}

		Pass
		{
			Tags
			{
				"LightMode"="ForwardAdd"
			}

			ZWrite Off
			ZTest LEqual
			Blend One One
			Cull Front

		    CGPROGRAM
		    #define BACKFACE_ON
		    #include "UnityCG.cginc"

#if UNITY_VERSION < 540
#define UNITY_SHADER_NO_UPGRADE
#define unity_ObjectToWorld _Object2World 
#define unity_WorldToObject _World2Object
#define unity_WorldToLight _LightMatrix0
#define unity_WorldToCamera _WorldToCamera
#define unity_CameraToWorld _CameraToWorld
#define unity_Projector _Projector
#define unity_ProjectorDistance _ProjectorDistance
#define unity_ProjectorClip _ProjectorClip
#define unity_GUIClipTextureMatrix _GUIClipTextureMatrix 
#endif

			#include "Lighting.cginc"
#include "AutoLight.cginc"

#ifdef POINT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = (tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL);
#endif

#ifdef SPOT
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); \
	fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz);
#endif

#ifdef DIRECTIONAL
	#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos)	fixed destName = 1;
#endif


#ifdef POINT_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL * texCUBE(_LightTexture0, lightCoord).w;
#endif

#ifdef DIRECTIONAL_COOKIE
#define MGFX_LIGHT_ATTENUATION(destName, input, worldPos) \
	unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; \
	fixed destName = tex2D(_LightTexture0, lightCoord).w;
#endif


half3 autoLightDir()
{
    half3 camRight = UNITY_MATRIX_V[0].xyz;
    half3 camFwd = UNITY_MATRIX_V[2].xyz;
    half3 worldUp = half3(0, 1, 0);

    return normalize(camFwd);
    //return normalize(camFwd + camRight * -0.125f + worldUp * 0.5);
}

			uniform sampler2D _BayerTex;
uniform float4 _BayerTex_TexelSize;

#define F1 float
#define F2 float2
#define F3 float3
#define F4 float4
#define fract frac
#define iGlobalTime _Time.y * 16.0

F1 Noise(F2 n,F1 x){n+=x;return fract(sin(dot(n.xy,F2(12.9898, 78.233)))*43758.5453)*2.0-1.0;}

// Step 1 in generation of the dither source texture.
F1 Step1(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-12.0,t=1.0;   
    return (1.0/(a*4.0+b*4.0-c))*(
        Noise(uv+F2(-1.0,-1.0)*t,n)*a+
        Noise(uv+F2( 0.0,-1.0)*t,n)*b+
        Noise(uv+F2( 1.0,-1.0)*t,n)*a+
        Noise(uv+F2(-1.0, 0.0)*t,n)*b+
        Noise(uv+F2( 0.0, 0.0)*t,n)*c+
        Noise(uv+F2( 1.0, 0.0)*t,n)*b+
        Noise(uv+F2(-1.0, 1.0)*t,n)*a+
        Noise(uv+F2( 0.0, 1.0)*t,n)*b+
        Noise(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Step 2 in generation of the dither source texture.
F1 Step2(F2 uv,F1 n){
    F1 a=1.0,b=2.0,c=-2.0,t=1.0;
    return (4.0/(a*4.0+b*4.0-c))*(
        Step1(uv+F2(-1.0,-1.0)*t,n)*a+
        Step1(uv+F2( 0.0,-1.0)*t,n)*b+
        Step1(uv+F2( 1.0,-1.0)*t,n)*a+
        Step1(uv+F2(-1.0, 0.0)*t,n)*b+
        Step1(uv+F2( 0.0, 0.0)*t,n)*c+
        Step1(uv+F2( 1.0, 0.0)*t,n)*b+
        Step1(uv+F2(-1.0, 1.0)*t,n)*a+
        Step1(uv+F2( 0.0, 1.0)*t,n)*b+
        Step1(uv+F2( 1.0, 1.0)*t,n)*a+
        0.0);}

// Used for stills.
F3 Step3(F2 uv){
    F1 a=Step2(uv,0.07);    
    #ifdef CHROMATIC
    F1 b=Step2(uv,0.11);    
    F1 c=Step2(uv,0.13);
    return F3(a,b,c);
    #else
    // Monochrome can look better on stills.
    return F3(a, a, a);
    #endif
}

// Used for temporal dither.
F3 Step3T(F2 uv){
    F1 a=Step2(uv,0.07*(fract(iGlobalTime)+1.0));
    F1 b=Step2(uv,0.11*(fract(iGlobalTime)+1.0));
    F1 c=Step2(uv,0.13*(fract(iGlobalTime)+1.0));
    return F3(a,b,c);}

F1 InterleavedGradientNoise( F2 uv )
{
	const F3 magic = F3( 0.06711056, 0.00583715, 52.9829189 );
	F1 n = fract( magic.z * fract( dot( uv, magic.xy ) ) );
	return n * 2.0 - 1.0;
}

F1 Bayer( F2 uv )
{
	F2 val = dot(tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).rg, F2(256.0 * 255.0, 255.0));
	val = val * _BayerTex_TexelSize.x * _BayerTex_TexelSize.y;
	return val * 2.0 - 1.0;
	//return (tex2D(_BayerTex, uv * _BayerTex_TexelSize.xy).r) * 2.0 - 1.0;
}
// ====

			#pragma vertex vert
#pragma fragment frag_add
#pragma multi_compile_fwdadd_fullshadows
#pragma target 3.0

#pragma shader_feature _TEXTURE_FADE_OUT_ON
#pragma shader_feature _NORMAL_MAP_ON
#pragma shader_feature _DARKEN_BACKFACES_ON
#pragma shader_feature _DIM_ON
#pragma shader_feature _OVERLAY_ON
#pragma shader_feature _DIFFUSE_LUT_ON
//#pragma enable_d3d11_debug_symbols
			/// Vertex
///
struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 vcolor : COLOR;
    float2 texcoord : TEXCOORD0;
#if _OVERLAY_ON
    float2 texcoord1 : TEXCOORD1;

	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD2;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD3;
	#endif

#else
	#ifndef LIGHTMAP_OFF
	float2 lmapcoord : TEXCOORD1;
	#endif

	#ifndef DYNAMICLIGHTMAP_OFF
	float2 dlmapcoord : TEXCOORD2;
	#endif

#endif

#if _NORMAL_MAP_ON
	float4 tangent : TANGENT;
#endif
};

struct v2f
{
	float4 vcolor : COLOR;
    float4 uv : TEXCOORD0;
    SHADOW_COORDS(1) // put shadows data into TEXCOORD1
    float4 worldPosAndZ : TEXCOORD2;

#if _NORMAL_MAP_ON
	float4 tanSpace0 : TEXCOORD3;
	float4 tanSpace1 : TEXCOORD4;
	float4 tanSpace2 : TEXCOORD5;
#else
	float3 worldNormal : TEXCOORD3;
#endif

#if !defined(LIGHTMAP_OFF) || !defined(DYNAMICLIGHTMAP_OFF)
	float4 lmap : TEXCOORD6;
#endif

    float4 pos : SV_POSITION;
};

v2f vert (appdata v)
{
    v2f o;
    o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
    o.vcolor = v.vcolor;
    o.uv = v.texcoord.xyxy;
#if _OVERLAY_ON
    o.uv.zw = v.texcoord1;
#endif
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);

#if _NORMAL_MAP_ON
	float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
	float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
	float3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
	o.tanSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, 0);
	o.tanSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, 0);
	o.tanSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, 0);
#else
	o.worldNormal = worldNormal;
#endif

    o.worldPosAndZ.xyz = mul(unity_ObjectToWorld, v.vertex).xyz;

#ifndef LIGHTMAP_OFF
	o.lmap = v.lmapcoord.xyxy * unity_LightmapST.xyxy + unity_LightmapST.zwzw;
#endif

#ifndef DYNAMICLIGHTMAP_OFF
	o.lmap.zw = v.dlmapcoord.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

    COMPUTE_EYEDEPTH(o.worldPosAndZ.w);
    // compute shadows data
    TRANSFER_SHADOW(o)
    return o;
}

///
/// Fragment
///
uniform sampler2D _MainTex;

uniform float _FadeOut;

#if _IRRADIANCE_ON
uniform float _IrradianceBoost;
#endif

#if _NORMAL_MAP_ON
uniform sampler2D _NormalMapTex;
#endif

#if _DIM_ON
uniform sampler2D _DimTex;
#endif

#if _OVERLAY_ON
uniform sampler2D _OverlayTex;
#endif

#if _DIFFUSE_LUT_ON
uniform sampler2D _DiffuseLUTTex;
uniform sampler2D _MudSSAOTex; // global property
#endif

#if _RIM_ON
uniform sampler2D _RimLUTTex;
uniform float _RimIntensity;
#endif

#if _MATCAP_ON
uniform sampler2D _MatCapTex;
uniform float _MatCapIntensity;
#endif

struct ShadingContext
{
	half4 albedo;
	half4 dimmed;
	half3 worldNormal;
	half3 worldViewDir;
	half3 worldPos;
	fixed vface;
	fixed shadow;
	half4 result;
};

void fetchWorldNormal(inout ShadingContext ctx, in v2f i)
{
#if _NORMAL_MAP_ON
	half3 tanNormal = UnpackNormal(tex2D(_NormalMapTex, i.uv.xy));
	half3 worldNormal;
	worldNormal.x = dot(i.tanSpace0.xyz, tanNormal);
	worldNormal.y = dot(i.tanSpace1.xyz, tanNormal);
	worldNormal.z = dot(i.tanSpace2.xyz, tanNormal);
	ctx.worldNormal = normalize(worldNormal);
#else
	ctx.worldNormal = normalize(i.worldNormal);
#endif

#ifdef BACKFACE_ON
	ctx.worldNormal *= -1;
#endif

	ctx.worldPos = i.worldPosAndZ.xyz;
	ctx.worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPosAndZ.xyz);

}

void fetchShadowTerm(inout ShadingContext ctx, in v2f i)
{
#if !defined(BACKFACE_ON)
	ctx.shadow = SHADOW_ATTENUATION(i);
#else
	ctx.shadow = 1;
#endif
}

void fetchAlbedoAndDimmed(inout ShadingContext ctx, in v2f i)
{
	ctx.albedo = tex2D(_MainTex, i.uv.xy);

#if _DIM_ON
	ctx.dimmed = tex2D(_DimTex, i.uv.xy);
#else
	half3 dimmed = ctx.albedo.rgb;
	dimmed = dimmed * dimmed * 0.25;
	ctx.dimmed = half4(dimmed, ctx.albedo.a);
#endif

#if _OVERLAY_ON
	half4 overlay = tex2D(_OverlayTex, i.uv.zw);

	half t = overlay.a;
	t = (1-cos(t*3.1415926)) / 2;

	ctx.albedo.rgb = lerp(ctx.albedo.rgb, overlay.rgb, t);
	ctx.dimmed.rgb = lerp(ctx.dimmed.rgb, overlay.rgb, t);
#endif

}

void applyLightingFwdBase(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_OFF
	half ndotl = dot(ctx.worldNormal, _WorldSpaceLightPos0.xyz);
	#if _DIFFUSE_LUT_ON
		half2 screenuv = i.pos.xy * _ScreenParams.zw - i.pos.xy;
		half occl = tex2D(_MudSSAOTex, screenuv).r;
		occl = saturate(occl * occl * 4);
		occl = 1 - occl;
		ndotl = dot(ctx.worldNormal, autoLightDir());

		half lightingControl = i.vcolor.r;
		ndotl = lerp(1.0, tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r * occl, lightingControl);
	#else
		ndotl = saturate(ndotl);
		ndotl = ndotl * ndotl * ctx.shadow;
	#endif

	half3 lighting = lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb;

	#if _IRRADIANCE_ON
		half3 irrad = half3(0, 0, 0);
		#ifdef DYNAMICLIGHTMAP_ON

			irrad = DecodeRealtimeLightmap (UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.lmap.zw));

			#if DIRLIGHTMAP_COMBINED
				fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_DynamicDirectionality, unity_DynamicLightmap, i.lmap.zw);
				irrad = DecodeDirectionalLightmap (irrad, dirmap, ctx.worldNormal);
			#endif

		#elif UNITY_SHOULD_SAMPLE_SH

			#if UNITY_VERSION < 540
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad);
			#else
				irrad = ShadeSHPerPixel (ctx.worldNormal, irrad, ctx.worldPos);
			#endif
		#endif

		lighting += irrad * irrad * pow(ctx.albedo, 0.5) * (1.0 + _IrradianceBoost);
	#endif

	ctx.result.rgb += lighting;

#endif
}

void applyLightingFwdAdd(inout ShadingContext ctx, in v2f i)
{
    UNITY_LIGHT_ATTENUATION(lightShadowAndAtten, i, i.worldPosAndZ.xyz);

	half ndotl = dot(ctx.worldNormal, normalize(_WorldSpaceLightPos0.xyz - ctx.worldPos));
	#if _DIFFUSE_LUT_ON
	ndotl = tex2D(_DiffuseLUTTex, saturate(ndotl * 0.5 + 0.5) * ctx.shadow).r;
	#else
	ndotl = saturate(ndotl) * ctx.shadow;
	#endif
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, ndotl) * _LightColor0.rgb * lightShadowAndAtten;
}

void applyLightmap(inout ShadingContext ctx, in v2f i)
{
#ifdef LIGHTMAP_ON

	half3 lmap = DecodeLightmap (UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lmap.xy));

	#if DIRLIGHTMAP_COMBINED
		fixed4 dirmap = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, i.lmap.xy);
		lmap = DecodeDirectionalLightmap (lmap, dirmap, ctx.worldNormal);
	#endif

	half lum = Luminance(lmap) * ctx.shadow;
	ctx.result.rgb += lerp(ctx.dimmed, ctx.albedo, lum) * lmap;

#endif
}

void applyDarkenBackFace(inout ShadingContext ctx, in v2f i)
{
#if _DARKEN_BACKFACES_ON
#ifdef BACKFACE_ON
    	ctx.result.rgb = ctx.dimmed * (1.0 / 64.0);
#endif
#endif
}

void applyRim(inout ShadingContext ctx, in v2f i)
{
#if _RIM_ON
	half vdotl = dot(ctx.worldNormal, ctx.worldViewDir);
	vdotl = tex2D(_RimLUTTex, saturate(vdotl * 0.5 + 0.5)).r;

	ctx.result.rgb += vdotl * ctx.albedo * _RimIntensity;

#endif
}

void applyMatcap(inout ShadingContext ctx, in v2f i)
{
#if _MATCAP_ON
	half3 rx = half3(1, 0, 0);
	half3 ry = half3(0, 1, 0);
	half3 rz = UNITY_MATRIX_V[2].xyz;

	rx = cross(ry, rz);
	ry = cross(rz, rx);

	half3x3 m;
	m[0] = rx;
	m[1] = -ry;
	m[2] = rz;
	#if _MATCAP_PLANAR_ON
		half3 dir = reflect(ctx.worldViewDir, ctx.worldNormal);
		dir = normalize(mul(m, dir));
		half2 mapCapUV = saturate(dir.xy * 0.5 + 0.5);
	#else
		half3 viewNormal = mul(m, ctx.worldNormal);
		half2 mapCapUV = saturate(viewNormal.xy * 0.5 + 0.5);
	#endif

	half4 mapCap = tex2D(_MatCapTex, mapCapUV);
	mapCap = mapCap * ctx.albedo.a * _MatCapIntensity;
	#if _MATCAP_ALBEDO_ON
		mapCap.rgb *= ctx.albedo.rgb;
	#endif
	ctx.result.rgb += mapCap;
	//ctx.result.rgb = half3(mapCapUV.xy, 0);
#endif
}

void shadingContext(inout ShadingContext ctx, in v2f i, in fixed vface)
{
	ctx = (ShadingContext)0;
	ctx.vface = vface;
	fetchAlbedoAndDimmed(ctx, i);
	fetchShadowTerm(ctx, i);
	fetchWorldNormal(ctx, i);

	ctx.result = half4(0, 0, 0, ctx.albedo.a);
}


half dither(in v2f i)
{
	half d1 = Bayer(i.pos.xy + float2(UNITY_MATRIX_MV._14, UNITY_MATRIX_MV._24));
	//half d2 = InterleavedGradientNoise(i.pos.xy);
	//return (d1 + d2) * 0.5;
	return d1;
}

void fade(inout ShadingContext ctx, in v2f i)
{
	half viewZ = i.worldPosAndZ.w;
	half d = dither(i);

	half fading = _FadeOut;
	fading = fading * 2.0 - 1.0;
	clip(d - fading);

#if _TEXTURE_FADE_OUT_ON
	clip(d + ctx.albedo.a);
#endif

	half bZ = _ProjectionParams.y * 2;
	half eZ = _ProjectionParams.y * 6;
	half rZ = eZ - bZ;
	half f = (viewZ - bZ) / rZ; // do not clamp f to [0, 1]

	f = f + d * rZ;
	clip(f);
}


half4 frag_base (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

   	fade(ctx, i);

	applyLightingFwdBase(ctx, i);

	applyLightmap(ctx, i);

	applyRim(ctx, i);

	applyMatcap(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}


half4 frag_add (v2f i, fixed vface : VFACE) : SV_Target
{
    ShadingContext ctx;
    shadingContext(ctx, i, vface);

    fade(ctx, i);

    applyLightingFwdAdd(ctx, i);

    applyDarkenBackFace(ctx, i);

    return ctx.result;
}
			ENDCG
		}
		
		Pass
		{
			Name "META"
			Tags
			{
				"LightMode"="Meta"
			}

			Cull Off

		    CGPROGRAM
			#pragma only_renderers d3d11
#pragma vertex vert_meta
#pragma fragment frag_meta

#include "UnityCG.cginc"
#include "UnityMetaPass.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float2 texcoord : TEXCOORD0;
    float2 texcoord1 : TEXCOORD1;
    float2 texcoord2 : TEXCOORD2;
};

struct v2f_meta
{
	float2 uv		: TEXCOORD0;
	float4 pos		: SV_POSITION;
};


uniform sampler2D _MainTex;
uniform float4 _MainTex_ST;

v2f_meta vert_meta (appdata v)
{
	v2f_meta o;
	o.pos = UnityMetaVertexPosition(v.vertex, v.texcoord1.xy, v.texcoord2.xy, unity_LightmapST, unity_DynamicLightmapST);
	o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
	return o;
}


float4 frag_meta (v2f_meta i) : SV_Target
{
	UnityMetaInput o;
	UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

	o.Albedo = tex2D(_MainTex, i.uv);
	o.Albedo = o.Albedo * o.Albedo;
	o.Emission = 0;

	return UnityMetaFragment(o);
}

			ENDCG
		}

		// shadow casting support
		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }

    CustomEditor "MGFX.NPRCelShadingUI"
}