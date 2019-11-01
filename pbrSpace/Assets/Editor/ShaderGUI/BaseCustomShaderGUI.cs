using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
public class BaseCustomShaderGUI : ShaderGUI {

	protected Material target;
	protected MaterialEditor editor;
	protected MaterialProperty[] properties;

	static GUIContent staticLabel = new GUIContent();

	// Use this for initialization
	protected MaterialProperty FindProperty(string name)
	{
		return FindProperty(name,properties);
	}

    protected bool isInit = false;
    protected virtual void Init()
    {

    }
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        if (isInit)
        {
            isInit = true;
            Init();
        }
		this.editor = materialEditor;
		this.target = materialEditor.target as Material;	
		this.properties = properties;
		OnBaseGUI();
	}
	protected virtual void OnBaseGUI()
	{

    }
    protected virtual void DrawBaseGUI()
    {
        base.OnGUI(editor, properties);
    }
	protected static GUIContent MakeLabel (string text, string tooltip = null) {
		staticLabel.text = text;
		staticLabel.tooltip = tooltip;
		return staticLabel;
	}

	protected static GUIContent MakeLabel (
		MaterialProperty property, string tooltip = null
	) {
		staticLabel.text = property.displayName;
		staticLabel.tooltip = tooltip;
		return staticLabel;
	}

	protected void SetKeyword (string keyword, bool state) {
		if (state) {
			foreach (Material m in editor.targets) {
				m.EnableKeyword(keyword);
			}
		}
		else {
			foreach (Material m in editor.targets) {
				m.DisableKeyword(keyword);
			}
		}
	}

	protected bool IsKeywordEnabled (string keyword) {
		return target.IsKeywordEnabled(keyword);
	}

	protected void RecordAction (string label) {
		editor.RegisterPropertyChangeUndo(label);
	}
}
