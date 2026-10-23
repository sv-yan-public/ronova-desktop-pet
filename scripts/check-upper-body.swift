import Foundation
@main struct Check {
 static func main() {
  var minimumArea:Float=1
  for side in [3,4] {
   let wrist=SIMD2<Float>(side == 3 ? 0.422:0.603,0.505)
   let head=SIMD2<Float>(side == 3 ? 0.33:0.74,0.92)
   var crossings=0
   func separation(_ phase:Double)->Float {WalkCycle.foot(phase).x-WalkCycle.foot(phase+0.5).x}
   for i in 0..<1000 {
    let phase=Double(i)/1000
    if separation(phase)*separation(phase+0.001)<0 {
     crossings += 1
     let before=WalkingUpperBody.offset(wrist,phase:phase-0.01,time:1,amount:1,facing:side)
     let after=WalkingUpperBody.offset(wrist,phase:phase+0.01,time:1,amount:1,facing:side)
     precondition(abs(after.x-before.x)>0.001,"Arm stalls when legs cross")
    }
   }
   precondition(crossings==2,"Expected two leg crossings per cycle")
   for p in [wrist,head] {
    let samples=(0..<120).map { i in WalkingUpperBody.offset(p,phase:Double(i)/120,time:Double(i)/120*2.6,amount:1,facing:side) }
    let range=samples.map{$0.x}.max()!-samples.map{$0.x}.min()!
    // Arms remain visible; head movement should stay a subtle nod.
    precondition(range > (p == wrist ? 0.0125 : 0.003),"Motion is too small at \(p): \(range)")
    precondition(WalkingUpperBody.offset(p,phase:0.3,time:1,amount:0,facing:side) == .zero)
   }
   // Torso must not inherit the arm swing or a full-width waist shear.
   for y: Float in [0.64, 0.68, 0.72] {
    let p=SIMD2<Float>(side == 3 ? 0.29 : 0.80,y)
    let samples=(0..<120).map {WalkingUpperBody.offset(p,phase:Double($0)/120,time:1,amount:1,facing:side)}
    for axis in 0..<2 {
     let values=samples.map {$0[axis]}
     precondition(values.max()!-values.min()! < 0.002,"Torso follows the swing")
    }
   }
   for f in 0..<120 {
    let phase=Double(f)/120
    func warp(_ p:SIMD2<Float>)->SIMD2<Float> {p+WalkingUpperBody.offset(p,phase:phase,time:phase*2.6,amount:1,facing:side)}
    for y in 0..<84 {for x in 0..<56 {
     let p=SIMD2<Float>(Float(x)/56,Float(y)/84)
     let a=warp(p),b=warp(p+SIMD2(1.0/56,0)),c=warp(p+SIMD2(0,1.0/84)),d=warp(p+SIMD2(1.0/56,1.0/84))
     func area(_ u:SIMD2<Float>,_ v:SIMD2<Float>)->Float {u.x*v.y-u.y*v.x}
     minimumArea=min(minimumArea,area(b-a,c-a),area(d-b,c-b))
    }}
   }
  }
  precondition(minimumArea>0,"Mesh folded")
  print("Upper-body motion visible on both sides; stop blend zero; 120 phases have no folded cells. Minimum area: \(minimumArea)")
 }
}
