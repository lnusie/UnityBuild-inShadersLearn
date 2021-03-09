// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_META_INCLUDED
#define UNITY_STANDARD_META_INCLUDED

// Functionality for Standard shader "meta" pass
// (extracts albedo/emission for lightmapper etc.)

#include "UnityCG.cginc"
#include "UnityStandardInput.cginc"
#include "UnityMetaPass.cginc"
#include "UnityStandardCore.cginc"

float3 _Emission;

struct v2f_meta
{
    float4 pos      : SV_POSITION;
    float4 uv       : TEXCOORD0;
};

v2f_meta LightMappingVertexProgram (VertexInput v)
{
    v2f_meta o;
    o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
    o.uv = TexCoords(v);

    return o;
}
float3 GetEmission (half2 uv) {
     #if defined(_EMISSION) || defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
          #if defined(_EMISSION_MAP)
               return tex2D(_EmissionMap, uv) * _Emission;
          #else
               return _Emission;
          #endif
     #else
          return 0;
     #endif
}
// Albedo for lightmapping should basically be diffuse color.
// But rough metals (black diffuse) still scatter quite a lot of light around, so
// we want to take some of that into account too.
half3 UnityLightmappingAlbedo (half3 diffuse, half3 specular, half smoothness)
{
    half roughness = SmoothnessToRoughness(smoothness);
    half3 res = diffuse;
    res += specular * roughness * 0.5;
    return res;
}

float4 LightMappingFragmentProgram (v2f_meta i) : SV_Target
{
    // we're interested in diffuse & specular colors,
    // and surface roughness to produce final albedo.
    FragmentCommonData data = UNITY_SETUP_BRDF_INPUT (i.uv);

    UnityMetaInput o;
    UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

    o.Albedo = UnityLightmappingAlbedo (data.diffColor, data.specColor, data.smoothness);
    o.SpecularColor = data.specColor;
    o.Emission = GetEmission(i.uv.xy);
    return UnityMetaFragment(o);
}

#endif // UNITY_STANDARD_META_INCLUDED
