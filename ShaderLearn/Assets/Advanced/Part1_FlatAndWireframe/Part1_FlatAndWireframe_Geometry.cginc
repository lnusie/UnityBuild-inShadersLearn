#if !defined(PART1_FLAT_WIREFRAME_INCLUDED)
#define PART1_FLAT_WIREFRAME_INCLUDED

//重心坐标，xyz相加等于1，所以传递xy就够了
#define CUSTOM_GEOMETRY_INTERPOLATORS float2 barycentricCoordinates : TEXCOORD9;
	

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