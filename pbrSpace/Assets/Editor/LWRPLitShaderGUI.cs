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
        Multiply
    }


    private MaterialProperty mMainTexProperty;
    private MaterialProperty mLightTexProperty;
    private MaterialProperty mBumpMapProperty;
    private MaterialProperty mMetallicProp;
    private MaterialProperty mSmoothnessProperty;
    private MaterialProperty mColorProperty;

    private MaterialProperty mSurfaceTypeProp;
    private MaterialProperty mBlendModeProp;
    protected override void OnBaseGUI()
    {
        base.OnBaseGUI();
        mMainTexProperty = FindProperty("_MainTex");
        mLightTexProperty = FindProperty("_LightTex");
        mBumpMapProperty = FindProperty("_BumpMap");
        mMetallicProp = FindProperty("_Metallic");
        mSmoothnessProperty = FindProperty("_Smoothness");
        mColorProperty = FindProperty("_Color");


        //mSurfaceTypeProp = FindProperty("_Surface", properties);
        //mBlendModeProp = FindProperty("_Blend", properties);

        //receiveShadowsProp = FindProperty("_ReceiveShadows", properties, false);

        editor.TexturePropertySingleLine(new GUIContent("Albedo"), mMainTexProperty, mColorProperty);
        var hasMap = mLightTexProperty.textureValue != null;

        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(new GUIContent("Metallic(R) Smooth(A)"), mLightTexProperty, hasMap ? null : mMetallicProp);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_METALLICGLOSSMAP", mLightTexProperty.textureValue);
        }
        if(!hasMap)
            editor.ShaderProperty(mSmoothnessProperty,"Smoothness",3);

        editor.TexturePropertySingleLine(new GUIContent("BumpMap"), mBumpMapProperty);
    }


    void SetupMaterialBlendMode(Material material)
    {
        if (material == null)
            throw new ArgumentNullException("material");

        bool alphaClip = material.GetFloat("_AlphaClip") == 1;
        if (alphaClip)
            material.EnableKeyword("_ALPHATEST_ON");
        else
            material.DisableKeyword("_ALPHATEST_ON");

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
                case BlendMode.Multiply:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.DstColor);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetInt("_ZWrite", 0);
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    material.SetShaderPassEnabled("ShadowCaster", false);
                    break;
            }
        }
    }
}
