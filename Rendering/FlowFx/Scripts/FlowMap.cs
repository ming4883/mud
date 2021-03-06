﻿using UnityEngine;
using System.Collections.Generic;

namespace MGFX.Rendering
{
	[ExecuteInEditMode]
	[AddComponentMenu("MGFX/FlowMap")]
	public class FlowMap : MonoBehaviour
	{
		public float minimumDistance = 1.0f;

		public Vector2 size = new Vector2(10, 10);
		public Vector2 resolution = new Vector2(512, 512);

		[RangeAttribute(0, 32)]
		public int blurSize = 2;

		[RangeAttribute(0, 16)]
		public int blurIterations = 2;

		public Texture2D AlphaMask = null;

		public string Filename = "FlowMap.png";

		[HideInInspector]
		[System.NonSerialized]
		public FlowPath.Sample[] cached;

		//[HideInInspector]
		//[System.NonSerialized]
		//public Flow[] flows;

		public void OnEnable()
		{
		}

		public void Start()
		{
		}

		public void OnDisable()
		{
		}

		private static Color m_LineColor = new Color(1.0f, 0.5f, 0.5f, 0.75f);

		public Matrix4x4 GetTextureMatrix()
		{
			Matrix4x4 _world2Local = transform.worldToLocalMatrix;

			Matrix4x4 _offset = Matrix4x4.Translate(new Vector3(0.5f * size.x, 0, 0.5f * size.y));

			Matrix4x4 _scale = Matrix4x4.identity;
			_scale.m00 = 1.0f / size.x;
			_scale.m11 = 1.0f;
			_scale.m22 = 1.0f / size.y;

			Matrix4x4 _swizzle = new Matrix4x4();
			_swizzle.SetRow(0, new Vector4(1, 0, 0, 0));
			_swizzle.SetRow(1, new Vector4(0, 0, 1, 0));
			_swizzle.SetRow(2, new Vector4(0, 1, 0, 0));
			_swizzle.SetRow(3, new Vector4(0, 0, 0, 1));

			return _swizzle * _scale * _offset * _world2Local;
		}

		public void OnDrawGizmos()
		{
			Gizmos.matrix = Matrix4x4.TRS(transform.position, transform.rotation, transform.lossyScale);
			Gizmos.color = m_LineColor;

			Vector2 _halfSize = size * 0.5f;

			Gizmos.DrawLine(new Vector3( _halfSize.x, 0, _halfSize.y), new Vector3(-_halfSize.x, 0, _halfSize.y));
			Gizmos.DrawLine(new Vector3(-_halfSize.x, 0, _halfSize.y), new Vector3(-_halfSize.x, 0,-_halfSize.y));
			Gizmos.DrawLine(new Vector3(-_halfSize.x, 0,-_halfSize.y), new Vector3( _halfSize.x, 0,-_halfSize.y));
			Gizmos.DrawLine(new Vector3( _halfSize.x, 0,-_halfSize.y), new Vector3( _halfSize.x, 0, _halfSize.y));
		}

		public List<FlowPath.Sample> GatherSamples(Vector2 _sampleSize)
		{
			var _flowPaths = GetComponentsInChildren<FlowPath>();
			var _rawSamples = new List<FlowPath.Sample>();

			foreach (var _flow in _flowPaths)
			{
				if (null == _flow || !_flow)
					continue;
				
				(_flow as FlowPath).GatherSamples(_rawSamples, _sampleSize);
			}

			KdTree.Entry[] _kdEnt = new KdTree.Entry[_rawSamples.Count];
			for (int _it = 0; _it < _rawSamples.Count; ++_it)
			{
				_kdEnt[_it] = new KdTree.Entry(_rawSamples[_it].position, _it);
			}

			KdTree _kdTree = new KdTree();
			_kdTree.build(_kdEnt);

			KdTree.RQueue _rqueue = new KdTree.RQueue();

			var _processed = new System.Collections.Generic.HashSet<int>();

			float _range = Mathf.Min(_sampleSize.x, _sampleSize.y);

			var _filteredSamples = new List<FlowPath.Sample>();

			for (int _it = 0; _it < _rawSamples.Count; ++_it)
			{
				if (_processed.Contains(_it))
					continue;

				int[] _neighbours = _kdTree.rquery(_rqueue, _rawSamples[_it].position, _range);

				if (_neighbours.Length == 1)
				{
					_filteredSamples.Add(_rawSamples[_it]);
					_processed.Add(_it);
				}
				else
				{
					Vector3 _pos = Vector3.zero;
					Vector3 _dir = Vector3.zero;

					foreach(int _id in _neighbours)
					{
						_pos += _rawSamples[_id].position;
						_dir += _rawSamples[_id].direction;
						_processed.Add(_id);
					}

					FlowPath.Sample _samp = new FlowPath.Sample();
					_samp.position = _pos * (1.0f / _neighbours.Length);
					_samp.direction = _dir * (1.0f / _neighbours.Length);

					_filteredSamples.Add(_samp);					
				}
			}

			return _filteredSamples;	
		}
	}
}