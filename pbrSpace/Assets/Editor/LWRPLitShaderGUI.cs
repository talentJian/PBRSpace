using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class LWRPLitShaderGUI : BaseCustomShaderGUI
{
    public enum SurfaceType
    {
        Opaque,
        Transparent
    }

    public enum BlendMode
    {
        Alpha,   // Old school alpha-blending mode, fresnel does not affect amount of transparency
        Premultiply, // Physically plausible transparency mode, implemented as alpha pre-multiply
        Additive,
        //Multiply
    }


    private MaterialProperty mMainTexProperty;
    private MaterialProperty mLightTexProperty;
    private MaterialProperty mBumpMapProperty;
    private MaterialProperty mMetallicProp;
    private MaterialProperty mSmoothnessProperty;
    private MaterialProperty mColorProperty;

    private MaterialProperty mEmissiveProperty;
    private MaterialProperty mEmissiveColorProperty;

    private MaterialProperty mSurfaceTypeProp;
    private MaterialProperty mBlendModeProp;

    private MaterialProperty mClipValueProp;
    private MaterialProperty mClipToggleProp;


    private string[] surfaceOptions = new[] {"Opaque", "Transparent"};
    private string[] blendOptions = new[] { "Alpha", "Premultiply","Additvie" };
    protected override void OnBaseGUI()
    {
        base.OnBaseGUI();
        mMainTexProperty = FindProperty("_MainTex");
        mLightTexProperty = FindProperty("_LightTex");
        mBumpMapProperty = FindProperty("_BumpMap");
        mMetallicProp = FindProperty("_Metallic");
        mSmoothnessProperty = FindProperty("_Smoothness");
        mColorProperty = FindProperty("_Color");


        mSurfaceTypeProp = FindProperty("_Surface", properties);
        mBlendModeProp = FindProperty("_Blend", properties);

        mClipToggleProp = FindProperty("_ALPHATEST_ON");
        mClipValueProp = FindProperty("_ClipValue");

        mEmissiveColorProperty = FindProperty("_EmissiveColor");

        EditorGUI.BeginChangeCheck();
        {
            
            DoPopup("Surface Type", mSurfaceTypeProp, surfaceOptions);
            if ((SurfaceType)target.GetFloat("_Surface") == SurfaceType.Transparent)
                DoPopup("BlendMode", mBlendModeProp, blendOptions);
        }
        if (EditorGUI.EndChangeCheck())
        {
            SetupMaterialBlendMode(target);
        }
        
        editor.ShaderProperty(mClipToggleProp, "AlphaTest开关");
        if (mClipToggleProp.floatValue >= 1)
        {
            editor.ShaderProperty(mClipValueProp, "Clip");
        }

        editor.TexturePropertySingleLine(new GUIContent("固有色"), mMainTexProperty, mColorProperty);
        var hasMap = mLightTexProperty.textureValue != null;

        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(new GUIContent("通道图", "Metallic (R) 自发光 (G) Smoothness (A)"), mLightTexProperty, hasMap ? null : mMetallicProp);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_METALLICGLOSSMAP", mLightTexProperty.textureValue);
        }
        if(!hasMap)
            editor.ShaderProperty(mSmoothnessProperty,"Smoothness",3);

        //EditorGUILayout.HelpBox("Metallic (R) 自发光 (G) Smoothness (A)", MessageType.Info);

        editor.TexturePropertySingleLine(new GUIContent("BumpMap"), mBumpMapProperty);

        DoEmissive();
    }


    void DoEmissive()
    {

        editor.ShaderProperty( mEmissiveColorProperty, new GUIContent("自发光颜色"));
        //控制烘焙LightMap自发光~
        EditorGUI.BeginChangeCheck();
        editor.LightmapEmissionProperty();
        if (EditorGUI.EndChangeCheck())
        {

            foreach (Material m in editor.targets)
            {
                m.globalIlluminationFlags &=
                    ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }
    }
    
    protected void DoPopup(string label, MaterialProperty property, string[] options)
    {
        if (property == null)
            throw new ArgumentNullException("property");

        EditorGUI.showMixedValue = property.hasMixedValue;

        var mode = property.floatValue;
        EditorGUI.BeginChangeCheck();
        mode = EditorGUILayout.Popup(label, (int)mode, options);
        if (EditorGUI.EndChangeCheck())
        {
            editor.RegisterPropertyChangeUndo(label);
            property.floatValue = (float)mode;
        }

        EditorGUI.showMixedValue = false;
    }

    void SetupMaterialBlendMode(Material material)
    {
        if (material == null)
            throw new ArgumentNullException("material");
        SurfaceType surfaceType = (SurfaceType)material.GetFloat("_Surface");
        if (surfaceType == SurfaceType.Opaque)
        {
            material.SetOverrideTag("RenderType", "");
            material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
            material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
            material.SetInt("_ZWrite", 1);
            material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
            material.renderQueue = -1;
            material.SetShaderPassEnabled("ShadowCaster", true);
        }
        else
        {
            BlendMode blendMode = (BlendMode)material.GetFloat("_Blend");
            switch (blendMode)
            {
                case BlendMode.Alpha:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetInt("_ZWrite", 0);
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    material.SetShaderPassEnabled("ShadowCaster", false);
                    break;
                case BlendMode.Premultiply:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetInt("_ZWrite", 0);
                    material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    material.SetShaderPassEnabled("ShadowCaster", false);
                    break;
                case BlendMode.Additive:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_ZWrite", 0);
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    material.SetShaderPassEnabled("ShadowCaster", false);
                    break;
                //case BlendMode.Multiply:
                //    material.SetOverrideTag("RenderType", "Transparent");
                //    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.DstColor);
                //    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                //    material.SetInt("_ZWrite", 0);
                //    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                //    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                //    material.SetShaderPassEnabled("ShadowCaster", false);
                //    break;
            }
        }
    }
}
