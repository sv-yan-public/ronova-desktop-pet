import Foundation

// Static, local tailoring of the existing artwork. The compact support keeps
// the face, shoulders, arms, waist and lower body at their original positions.
enum BustShape {
    static func project(_ point: SIMD2<Float>, view: Int) -> SIMD2<Float> {
        let centers: [SIMD2<Float>] = [
            SIMD2(0.465, 0.783), SIMD2(0.380, 0.779), SIMD2(0.581, 0.781),
            SIMD2(0.255, 0.781), SIMD2(0.814, 0.780)
        ]
        let widths: [Float] = [0.145, 0.117, 0.123, 0.085, 0.085]
        let center = centers[view]
        let delta = point-center
        let radius = SIMD2<Float>(delta.x/widths[view], delta.y/0.066)
        let distance = radius.x*radius.x + radius.y*radius.y
        guard distance < 1 else { return point }
        let weight = (1-distance)*(1-distance)
        let forward: Float = view == 3 ? -0.023 : (view == 4 ? 0.023 : 0)
        return point + SIMD2<Float>(delta.x*0.32+forward, delta.y*0.10)*weight
    }
}
