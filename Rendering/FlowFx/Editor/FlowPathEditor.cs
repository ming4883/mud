using UnityEditor;
using UnityEngine;

namespace MGFX.Rendering
{
	[CustomEditor(typeof(FlowPath))]
	public class FlowPathEditor : Editor
	{
		private static Color m_ConeColor = new Color(1, 0.25f, 0.25f, 0.5f);
		private static Color m_LineColor = new Color(1, 0.25f, 0.25f, 1.0f);
		private static Color m_PivotColor = new Color(1, 1, 1, 1.0f);

		private float m_HandleSize = 0.04f;
		private float m_PickSize = 0.06f;

		private int m_SelectedIndex = -1;

		public override void OnInspectorGUI()
		{
			base.DrawDefaultInspector();
		}

		public void OnEnable()
		{
			//Tools.hidden = true;
		}

		public void OnDisable()
		{
			//Tools.hidden = false;
		}

		public void OnSceneGUIPivot()
		{
			var _inst = target as FlowPath;
			var _tran = _inst.transform;

			float _scale = HandleUtility.GetHandleSize(_tran.position);

			Handles.color = m_PivotColor;

			if (Handles.Button(_tran.position, Quaternion.identity, m_HandleSize * _scale, m_PickSize * _scale, Handles.DotHandleCap))
			{
				m_SelectedIndex = -1;
			}

			Tools.hidden = m_SelectedIndex != -1;
		}

		public bool OnSceneGUIPoint(int _index, int _lastIndex)
		{
			var _inst = target as FlowPath;
			var _tran = _inst.transform;
			var _pt = _inst.points[_index];
			_pt = _tran.TransformPoint(_pt);
			float _scale = HandleUtility.GetHandleSize(_pt);

			Handles.color = m_ConeColor;

			// draw the flow direction
			if (_index != _lastIndex)
			{
				var _pt2 = _inst.points[_lastIndex];
				_pt2 = _tran.TransformPoint(_pt2);

				var _dir = _pt - _pt2;

				Handles.ConeHandleCap(0, _pt2 + _dir * 0.75f, Quaternion.FromToRotation(Vector3.forward, _dir), 0.25f * _scale, EventType.Repaint);
			}

			Handles.color = m_LineColor;

			// check for selection
			_scale = _index == 0 ? 2 * _scale : _scale;
			if (Handles.Button(_pt, Quaternion.identity, m_HandleSize * _scale, m_PickSize * _scale, Handles.DotHandleCap))
			{
				m_SelectedIndex = _index;
			}

			Tools.hidden = m_SelectedIndex != -1;

			// enable translation if selected
			if (_index == m_SelectedIndex)
			{
				EditorGUI.BeginChangeCheck();

				_pt = Handles.DoPositionHandle(_pt, _tran.rotation);

				if (EditorGUI.EndChangeCheck())
				{
					Undo.RecordObject(target, "Flow Move Point");
					_inst.points[_index] = _tran.InverseTransformPoint(_pt);
					return true;
				}
			}
			return false;
		}

		public void OnSceneGUI()
		{
			var _inst = target as FlowPath;

			int _numOfPts = _inst.points.Length;

			if (_numOfPts < 1)
				return;

			if (_inst.loop && _numOfPts > 2)
			{
				OnSceneGUIPoint(0, _numOfPts - 1);
			}
			else
			{
				OnSceneGUIPoint(0, 0);
			}

			if (_numOfPts < 2)
				return;

			var _tran = _inst.transform;

			for (int _it = 1; _it < _numOfPts; _it++)
			{
				OnSceneGUIPoint(_it, _it - 1);
			}

			OnSceneGUIPivot();
		}
	}
}