import Foundation

// Local, continuous deformation of the painted side views. The pelvis remains
// fixed here; WalkingRig supplies the shared pelvis translation to both layers.
enum WalkingUpperBody {
    static func smooth(_ value: Float) -> Float {
        let t = min(1, max(0, value))
        return t*t*(3-2*t)
    }

    static func offset(_ point: SIMD2<Float>, phase: Double, time: Double,
                       amount: Float, facing: Int) -> SIMD2<Float> {
        let t = Float(phase * 2 * .pi)
        let direction: Float = facing == 3 ? -1 : 1
        let x = point.x, y = point.y
        let torso = smooth((y-0.58)/0.22)
        // The painted profile has its head behind the walking hip. Bring the
        // chest over the support leg without cyclic bending of the torso.
        let forwardSettle: Float = facing == 3 ? 0.060 : 0.070
        var result = SIMD2<Float>(
            direction * forwardSettle * torso,
            0)

        // A subpixel waist shift, bounded in BOTH axes. Do not shear the
        // full horizontal strip (which also contains arms, hair and clothing).
        let center: Float = facing == 3 ? 0.32 : 0.77
        let waist = (1-smooth(abs(y-0.665)/0.055))
            * (1-smooth(abs(x-center)/0.075))
        result.x += direction*sin(t+0.4)*0.0008*waist

        // Keep the face and skull together, blending only across the neck.
        let neck = smooth((y-0.77)/0.08)
        let pivot = SIMD2<Float>(facing == 3 ? 0.33 : 0.74, 0.81)
        let angle = direction * (sin(2*t-0.8)*0.026 + sin(Float(time)*0.71)*0.009)
        let head = SIMD2<Float>(x-pivot.x, (y-pivot.y)*1.5)
        let turned = SIMD2<Float>(head.x*cos(angle)-head.y*sin(angle),
                                  head.x*sin(angle)+head.y*cos(angle)) - head
        result += SIMD2(turned.x, turned.y/1.5)*neck

        // The visible arm swings opposite the near leg. A soft corridor around
        // shoulder/elbow/wrist keeps the surrounding torso from following it.
        let shoulder = SIMD2<Float>(facing == 3 ? 0.375 : 0.665, 0.77)
        let wrist = SIMD2<Float>(facing == 3 ? 0.422 : 0.603, 0.505)
        let along = min(1, max(0, (shoulder.y-y)/(shoulder.y-wrist.y)))
        let centerX = shoulder.x + (wrist.x-shoulder.x)*along
        let corridor = 1-smooth((abs(x-centerX)-0.023)/0.065)
        let armMask = corridor * smooth((y-0.36)/0.15) * (1-smooth((y-0.77)/0.04))
        // Follow the actual stance/swing timing, not a sine with different
        // crossover times. When the legs pass, the arm passes its neutral pose.
        func separation(_ phase: Double) -> Float {
            (WalkCycle.foot(phase).x-WalkCycle.foot(phase+0.5).x)/Float(WalkCycle.stride)
        }
        let armAngle = -direction * separation(phase)*0.095
        let arm = SIMD2<Float>(x-shoulder.x, (y-shoulder.y)*1.5)
        let swung = SIMD2<Float>(arm.x*cos(armAngle)-arm.y*sin(armAngle),
                                 arm.x*sin(armAngle)+arm.y*cos(armAngle)) - arm
        result += SIMD2(swung.x, swung.y/1.5)*armMask
        result.x -= direction*separation(phase-0.08)*0.003*along*along*armMask
        return result*amount
    }
}
