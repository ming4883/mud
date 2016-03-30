using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

namespace Mud
{

	[ExecuteInEditMode]
	[AddComponentMenu ("Mud/Rendering/Features/NPREdge")]
	public class RenderFeatureNPREdge : RenderFeatureBase
	{
		public static HashID MTL_EDGE_DETECT = new HashID ("Hidden/Mud/NPREdgeDetect");
		public static HashID MTL_EDGE_DILATE = new HashID ("Hidden/Mud/NPREdgeDilate");
		public static HashID MTL_EDGE_AA = new HashID ("Hidden/Mud/NPREdgeAA");
		public static HashID MTL_EDGE_APPLY = new HashID ("Hidden/Mud/NPREdgeApply");

		[Range (1.0f / 128.0f, 2.0f)]
		public float edgeDetails = 1.0f;

		[Range(0, 1.0f)]
		public float edgeCutoffMin = 0.25f;

		[Range(0, 1.0f)]
		public float edgeCutoffMax = 0.75f;

		public bool edgeAA = false;

		public Color edgeColor = Color.black;

		[Range(0, 1.0f)]
		public float edgeAutoColoring = 0.0f;

		public override void OnEnable ()
		{
			base.OnEnable ();

			LoadMaterial (MTL_EDGE_DETECT);
			LoadMaterial (MTL_EDGE_DILATE);
			LoadMaterial (MTL_EDGE_AA);
			LoadMaterial (MTL_EDGE_APPLY);
		}

		// http://docs.unity3d.com/540/Documentation/Manual/GraphicsCommandBuffers.html
		// http://docs.unity3d.com/540/Documentation/ScriptReference/Rendering.BuiltinRenderTextureType.html
		protected override void OnSetupCameraEvents (Camera _cam)
		{
			// update material properties
			var _screen_texelSize = new Vector4 (
				1.0f / Screen.width,
				1.0f / Screen.height,
				1.0f * Screen.width,
				1.0f * Screen.height);

			var _edge_threshold = new Vector4(
				edgeDetails,
				edgeCutoffMin,
				edgeCutoffMax,
				0);

			GetMaterial(MTL_EDGE_DETECT).SetVector("_EdgeThreshold", _edge_threshold);
			GetMaterial(MTL_EDGE_APPLY).SetColor("_EdgeColor", edgeColor);
			GetMaterial(MTL_EDGE_APPLY).SetFloat("_EdgeAutoColoring", edgeAutoColoring);

			// update command buffers
			var _cmdbuf = GetCommandBufferForEvent (_cam, CameraEvent.AfterFinalPass, "NPREdge");
			_cmdbuf.Clear ();

			var _idAlbedoCopy = Shader.PropertyToID("_NPREdgeAlbedoTex");
			var _idEdgeBuf1 = Shader.PropertyToID ("_EdgeTex1");
			var _idEdgeBuf2 = Shader.PropertyToID ("_EdgeTex2");

			var _idSrcBuf = _idEdgeBuf1;
			var _idDstBuf = _idEdgeBuf2;

			//Debug.LogFormat ("_idAlbedoCopy = {0}", _idAlbedoCopy);
			_cmdbuf.GetTemporaryRT(_idAlbedoCopy, -1, -1, 0, FilterMode.Bilinear);
			_cmdbuf.GetTemporaryRT (_idEdgeBuf1, -1, -1, 0, FilterMode.Bilinear);
			_cmdbuf.GetTemporaryRT (_idEdgeBuf2, -1, -1, 0, FilterMode.Bilinear);

			_cmdbuf.SetGlobalVector ("_ScreenTexelSize", _screen_texelSize);

			_cmdbuf.Blit (BuiltinRenderTextureType.None, _idSrcBuf, GetMaterial (MTL_EDGE_DETECT));

			if (edgeAA) {

				_cmdbuf.Blit(_idSrcBuf, _idDstBuf, GetMaterial(MTL_EDGE_AA));
				Swap(ref _idSrcBuf, ref _idDstBuf);
			}

			// copy the albedo
			_cmdbuf.Blit(BuiltinRenderTextureType.GBuffer0, _idAlbedoCopy, GetMaterial(MTL_EDGE_DILATE));

			// apply edges to albedo
			_cmdbuf.Blit (_idSrcBuf, BuiltinRenderTextureType.CameraTarget, GetMaterial (MTL_EDGE_APPLY));

			_cmdbuf.ReleaseTemporaryRT (_idAlbedoCopy);
			_cmdbuf.ReleaseTemporaryRT (_idEdgeBuf1);
			_cmdbuf.ReleaseTemporaryRT (_idEdgeBuf2);
		}

	}

}