#include "UnityCG.cginc"

#define SHADING_QUALITY_LOW		0
#define SHADING_QUALITY_MEDIUM	1
#define SHADING_QUALITY_HIGH	2

#if UNITY_VERSION < 560
	#define UNITY_SHADOW_COORDS(x) SHADOW_COORDS(x)
#endif