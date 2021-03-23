#if !defined(PART1_FLAT_WIREFRAME_INCLUDED)
#define PART1_FLAT_WIREFRAME_INCLUDED

	//重心坐标，xyz相加等于1，所以传递xy就够了
	#define CUSTOM_GEOMETRY_INTERPOLATORS float2 barycentricCoordinates : TEXCOORD9;


	#include "Part1_FlatAndWireframe_Core_Input.cginc" 

	float3 _WireframeColor;
	float _WireframeSmoothing;
	float _WireframeThickness;

	float3 GetAlbedoWithWireframe (v2f i) {
		float3 albedo = GetAlbedo(i);
		float3 barys;
		barys.xy = i.barycentricCoordinates;
		barys.z = 1 - barys.x - barys.y;
		float3 deltas = fwidth(barys);

		float3 smoothing = deltas * _WireframeSmoothing;
		float3 thickness = deltas * _WireframeThickness;

		barys = smoothstep(thickness, thickness +smoothing, barys);
		float minBary = min(barys.x, min(barys.y, barys.z));

		// //minBary表示 片元离最近一个顶点的距离
		// float minBary = min(barys.x, min(barys.y, barys.z));
		
		// //fwidth(minBary)相当于abs(ddx(minBary)) + abs(ddy(minBary));
		// //这一步的目的是让线框不受透视影响（理想效果是任意角度下观察，各个地方的线宽应该是一样的）
		// float delta = fwidth(minBary);
		return lerp(_WireframeColor, albedo, minBary);
	}

	#define ALBEDO_FUNCTION GetAlbedoWithWireframe

	#include "Part1_FlatAndWireframe_Core.cginc"

	struct InterpolatorsGeometry {
		InterpolatorsVertex data;
		CUSTOM_GEOMETRY_INTERPOLATORS
	};

	[maxvertexcount(3)] //triangle 明确声明参数是三角形的顶点,输出的顶点数据加入stream中
	void GeometryProgram(
		triangle InterpolatorsVertex i[3],
		inout TriangleStream<InterpolatorsGeometry> stream
		)
	{
	
		InterpolatorsGeometry g0, g1, g2;
		g0.data = i[0];
		g1.data = i[1];
		g2.data = i[2];
		g0.barycentricCoordinates = float2(1, 0);
		g1.barycentricCoordinates = float2(0, 1);
		g2.barycentricCoordinates = float2(0, 0);
		stream.Append(g0);
		stream.Append(g1);
		stream.Append(g2);
	}

#endif