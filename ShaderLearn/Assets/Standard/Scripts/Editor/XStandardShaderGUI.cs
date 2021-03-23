using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class XStandardShaderGUI : ShaderGUI
{
    enum SmoothnessSource
    {
        Uniform, Albedo, Metallic
    }

    enum RenderingMode
    {
        Opaque, Cutout, Fade, Transparent
    }

    struct RenderingSettings
    {
        public RenderQueue queue;
        public string renderType;
        public BlendMode srcBlend, dstBlend;
        public bool zWrite;

        public static RenderingSettings[] modes = {
            new RenderingSettings() {
                queue = RenderQueue.Geometry,
                renderType = "",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings() {
                queue = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true

            },
            new RenderingSettings() {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.SrcAlpha,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            },
            new RenderingSettings() {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            }
        };
    }

    static ColorPickerHDRConfig emissionConfig =
        new ColorPickerHDRConfig(0f, 99f, 1f / 99f, 3f);

    private Material target;

    private MaterialEditor editor;

    private MaterialProperty[] properties;

    bool shouldShowAlphaCutoff;

    static GUIContent staticLabel = new GUIContent();

    static GUIContent MakeLabel(
        MaterialProperty property, string tooltip = null
    )
    {
        staticLabel.text = property.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    static GUIContent MakeLabel(
        string text, string tooltip = null
    )
    {
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        this.target = materialEditor.target as Material;
        this.editor = materialEditor;
        this.properties = properties;
        DoRenderingMode();
        if (target.HasProperty("_WireframeColor"))
        {
            DoWireframe();
        }
        DoMain();
        DoSecondary();
    }

    void DoRenderingMode()
    {
        RenderingMode mode = RenderingMode.Opaque;
        shouldShowAlphaCutoff = false;
        if (IsKeywordEnabled("_RENDERING_CUTOUT"))
        {
            mode = RenderingMode.Cutout;
            shouldShowAlphaCutoff = true;
        }
        else if (IsKeywordEnabled("_RENDERING_FADE"))
        {
            mode = RenderingMode.Fade;
        }
        else if (IsKeywordEnabled("_RENDERING_TRANSPARENT"))
        {
            mode = RenderingMode.Transparent;
        }

        EditorGUI.BeginChangeCheck();
        mode = (RenderingMode)EditorGUILayout.EnumPopup(
            MakeLabel("Rendering Mode"), mode
        );
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Rendering Mode");
            SetKeyword("_RENDERING_CUTOUT", mode == RenderingMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderingMode.Fade);
            SetKeyword(   "_RENDERING_TRANSPARENT", mode == RenderingMode.Transparent);
        }

        RenderingSettings settings = RenderingSettings.modes[(int)mode];
        foreach (Material m in editor.targets)
        {
            m.renderQueue = (int)settings.queue;
            m.SetOverrideTag("RenderType", settings.renderType);
            m.SetInt("_SrcBlend", (int)settings.srcBlend);
            m.SetInt("_DstBlend", (int)settings.dstBlend);
            m.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
        }

        if (mode == RenderingMode.Fade || mode == RenderingMode.Transparent)
        {
            DoSemitransparentShadows();
        }
    }

    void DoSemitransparentShadows()
    {
        EditorGUI.BeginChangeCheck();
        bool semitransparentShadows =
            EditorGUILayout.Toggle(
                MakeLabel("Semitransp. Shadows", "Semitransparent Shadows"),
                IsKeywordEnabled("_SEMITRANSPARENT_SHADOWS")
            );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_SEMITRANSPARENT_SHADOWS", semitransparentShadows);
        }
        if (!semitransparentShadows)
        {
            shouldShowAlphaCutoff = true;
        }
    }

    void DoMain()
    {
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);

        MaterialProperty mainTex = FindProperty("_MainTex");
        editor.TexturePropertySingleLine(MakeLabel(mainTex,"Albedo (RGB)"), mainTex, FindProperty("_Color"));
        if(shouldShowAlphaCutoff)
            DoAlphaCutoff();
        DoMetallic();
        DoSmoothness();
        DoNormals();
        DoParallaxMap();
        DoOcclusion();
        DoEmission();
        DoDetailMask();
        editor.TextureScaleOffsetProperty(mainTex);
    }

    void DoMetallic()
    {
        MaterialProperty map = FindProperty("_MetallicMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Metallic (R)"), map,
            map.textureValue ? null : FindProperty("_Metallic")
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_METALLIC_MAP", map.textureValue != null);
        }
    }

    void DoSmoothness()
    {
        SmoothnessSource source = SmoothnessSource.Uniform;
        if (IsKeywordEnabled("_SMOOTHNESS_ALBEDO"))
        {
            source = SmoothnessSource.Albedo;
        }
        else if (IsKeywordEnabled("_SMOOTHNESS_METALLIC"))
        {
            source = SmoothnessSource.Metallic;
        }
        MaterialProperty slider = FindProperty("_Smoothness");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(slider, MakeLabel(slider));
        EditorGUI.indentLevel += 1;
        EditorGUI.BeginChangeCheck();
        source = (SmoothnessSource)EditorGUILayout.EnumPopup(MakeLabel("Source"), source);
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Smoothness Source");
            SetKeyword("_SMOOTHNESS_ALBEDO", source == SmoothnessSource.Albedo);
            SetKeyword(
                "_SMOOTHNESS_METALLIC", source == SmoothnessSource.Metallic
            );

        }
        EditorGUI.indentLevel -= 3;
    }

    void DoNormals()
    {
        MaterialProperty map = FindProperty("_NormalMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(map), map, map.textureValue ? FindProperty("_BumpScale") : null
        );
        if (EditorGUI.EndChangeCheck() && tex != map.textureValue)
        {
            SetKeyword("_NORMAL_MAP", map.textureValue);
        }
    }

    void DoSecondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);
        EditorGUI.BeginChangeCheck();
        MaterialProperty detailTex = FindProperty("_DetailTex");
        editor.TexturePropertySingleLine(
            MakeLabel(detailTex, "Albedo (RGB) multiplied by 2"), detailTex
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_DETAIL_ALBEDO_MAP", detailTex.textureValue);
        }
        DoSecondaryNormals();
        editor.TextureScaleOffsetProperty(detailTex);
    }

    void DoSecondaryNormals()
    {
        MaterialProperty map = FindProperty("_DetailNormalMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(map), map,
            map.textureValue ? FindProperty("_DetailBumpScale") : null
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_DETAIL_NORMAL_MAP", map.textureValue);
        }
    }

    void DoEmission()
    {
        MaterialProperty map = FindProperty("_EmissionMap");
        Texture tex = map.textureValue;
        bool enableEmission = IsKeywordEnabled("_EMISSION");
        EditorGUI.BeginChangeCheck();
        enableEmission = EditorGUILayout.Toggle("Emission", enableEmission);
        editor.TexturePropertyWithHDRColor(
            MakeLabel(map, "Emission (RGB)"), map, FindProperty("_Emission"),
            emissionConfig, false
        );
        if (EditorGUI.EndChangeCheck())
        {
            if (tex != map.textureValue)
            {
                SetKeyword("_EMISSION_MAP", map.textureValue != null);
            }
            SetKeyword("_EMISSION", enableEmission);
        }

        foreach (Material m in editor.targets)
        {
            //支持烘焙自发光
            m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.BakedEmissive;
        }

    }

    void DoOcclusion()
    {
        MaterialProperty map = FindProperty("_OcclusionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Occlusion (G)"), map,
            map.textureValue ? FindProperty("_OcclusionStrength") : null
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_OCCLUSION_MAP", map.textureValue);
        }
    }

    void DoDetailMask()
    {
        MaterialProperty mask = FindProperty("_DetailMask");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(mask, "Detail Mask (A)"), mask
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_DETAIL_MASK", mask.textureValue);
        }
    }

    void DoParallaxMap()
    {
        MaterialProperty map = FindProperty("_ParallaxMap");
        if (map == null) return;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Parallax (G)"), map,
            map.textureValue ? FindProperty("_ParallaxStrength") : null
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_PARALLAX_MAP", map.textureValue);
        }
    }

    void DoAlphaCutoff()
    {
        MaterialProperty slider = FindProperty("_Cutoff");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(slider, MakeLabel(slider));
        EditorGUI.indentLevel -= 2;
    }

    void DoWireframe()
    {
        GUILayout.Label("Wireframe", EditorStyles.boldLabel);
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(
            FindProperty("_WireframeColor"),
            MakeLabel("Color")
        );
        editor.ShaderProperty(
            FindProperty("_WireframeSmoothing"),
            MakeLabel("Smoothing", "In screen space.")
        );
        editor.ShaderProperty(
            FindProperty("_WireframeThickness"),
            MakeLabel("Thickness", "In screen space.")
        );
        EditorGUI.indentLevel -= 2;
    }

    void SetKeyword(string keyword, bool state)
    {
        if (state)
        {
            foreach (Material m in editor.targets)
            {
                m.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material m in editor.targets)
            {
                m.DisableKeyword(keyword);
            }
        }
    }

    MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, properties);
    }

    bool IsKeywordEnabled(string keyword)
    {
        return target.IsKeywordEnabled(keyword);
    }

    void RecordAction(string label)
    {
        editor.RegisterPropertyChangeUndo(label);
    }


}
