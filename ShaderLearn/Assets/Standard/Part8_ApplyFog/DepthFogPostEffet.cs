using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine;
using System;

[ExecuteInEditMode]
public class DepthFogPostEffet : MonoBehaviour
{

    public Shader deferredFog;

    [NonSerialized]
    Material fogMaterial;

    [NonSerialized]
    private Camera deferredCamera;

    [NonSerialized]
    private Vector3[] frustumCorners;//从相机原点沿视锥体四个角到达远裁剪平面的四个方向

    [NonSerialized]
    private Vector4[] vectorArray = new Vector4[4];

    [ImageEffectOpaque] //不透明几何体渲染之后渲染
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fogMaterial == null)
        {
            deferredCamera = GetComponent<Camera>();
            frustumCorners = new Vector3[4];
            fogMaterial = new Material(deferredFog);
            fogMaterial.EnableKeyword("FOG_DISTANCE");
        }
        deferredCamera.CalculateFrustumCorners(
            new Rect(0,0,1,1),
            deferredCamera.farClipPlane,
            deferredCamera.stereoActiveEye,
            frustumCorners
            );
        //frustumCorners中的排序为左下，左上，右上，右下
        //用于后处理的四边形按左下，右下，左上，右上排序
        vectorArray[0] = frustumCorners[0];
        vectorArray[1] = frustumCorners[3];
        vectorArray[2] = frustumCorners[1];
        vectorArray[3] = frustumCorners[2];
        fogMaterial.SetVectorArray("_FrustumCorners", vectorArray);
        Graphics.Blit(source, destination, fogMaterial);
    }
}