import AppKit
import SpriteKit

// Two independently articulated legs. Positions are in texture coordinates.
struct WalkCycle {
    static let stance: Double = 0.62
    static let stride: Double = 0.105
    static let previewPeriod: Double = 2.6
    static func foot(_ phase: Double) -> SIMD2<Float> {
        let p = phase - floor(phase)
        if p < stance {
            return SIMD2(Float(stride * (0.5 - p / stance)), 0)
        }
        let u = (p - stance) / (1 - stance)
        // Hermite return: velocity matches the planted foot at toe-off and landing.
        let m = -(1 - stance) / stance
        let travel = (-2*u*u*u+3*u*u) + m*(2*u*u*u-3*u*u+u)
        return SIMD2(Float(stride * (travel - 0.5)), Float(0.025 * pow(sin(.pi*u), 2)))
    }
    static func knee(hip: SIMD2<Float>, ankle: SIMD2<Float>, upper: Float, lower: Float, direction: Float) -> SIMD2<Float> {
        let delta = ankle - hip
        let distance = max(0.0001, min(sqrt(delta.x*delta.x+delta.y*delta.y), upper+lower-0.0001))
        let unit = delta / max(0.0001,sqrt(delta.x*delta.x+delta.y*delta.y))
        let along = (upper*upper-lower*lower+distance*distance)/(2*distance)
        let bend = sqrt(max(0,upper*upper-along*along))
        let forward = SIMD2(-unit.y,unit.x)*direction
        return hip+unit*along+forward*bend
    }
}

final class WalkingRig {
    let far = SKSpriteNode(), near = SKSpriteNode()
    var body: SKTexture?
    var facing = 4
    var layerOrigin=SIMD2<Float>(0,0)
    var layerScale: Float = 1
    let columns = 36, rows = 60
    var source = [SIMD2<Float>]()
    var hip = SIMD2<Float>(0,0), knee = SIMD2<Float>(0,0), ankle = SIMD2<Float>(0,0)
    var cache = [Int:(SKTexture,SKTexture)]()
    init(parent: SKNode) {
        far.zPosition = 1; near.zPosition = 2
        parent.addChild(far); parent.addChild(near)
        for node in [near,far] {node.shader=SKShader(source:"""
        void main() {
            vec4 c = texture2D(u_texture,v_tex_coord);
            float a = smoothstep(0.90,0.98,c.a);
            gl_FragColor = vec4(c.rgb*(a/max(c.a,0.001))*u_shade,a);
        }
        """);node.shader?.uniforms=[SKUniform(name:"u_shade",float:node === far ? 0.88 : 1)] }
        far.color = .black; far.colorBlendFactor = 0.13
        for y in 0...rows { for x in 0...columns { source.append(SIMD2(Float(x)/Float(columns),Float(y)/Float(rows))) } }
    }
    func load(_ side: Int) {
        facing=side
        if side==4 {
            layerOrigin=SIMD2(0.43,0.98);layerScale=0.53
            hip=SIMD2(0.765,0.56);knee=hip+(SIMD2(0.56,0.65)-layerOrigin)*layerScale;ankle=hip+(SIMD2(0.585,0.215)-layerOrigin)*layerScale
        } else {
            layerOrigin=SIMD2(0.366,0.88);layerScale=0.673
            hip=SIMD2(0.33,0.56);knee=hip+(SIMD2(0.354,0.57)-layerOrigin)*layerScale;ankle=hip+(SIMD2(0.327,0.23)-layerOrigin)*layerScale
        }
        if let stored=cache[side] {body=stored.0;near.texture=stored.1;far.texture=stored.1;return}
        func texture(_ part:String)->SKTexture {
            let url=Bundle.main.resourceURL!.appendingPathComponent("Assets/walk-\(side==3 ? "left" : "right")-\(part).png")
            guard let image=NSImage(contentsOf:url) else {fatalError("Missing walking layer: \(url.lastPathComponent)")}
            let texture=SKTexture(image:image);texture.filteringMode = .linear;return texture
        }
        // The body asset contains no legs. A clean single-leg cutout is skinned
        // independently twice, so no old foot remains beneath the moving layers.
        let pair=(texture("body"),texture("leg"));cache[side]=pair
        body=pair.0;near.texture=pair.1;far.texture=pair.1
    }
    func layout(size:CGSize,position:CGPoint,visible:Bool) {
        for node in [near,far] {node.size=size;node.position=position;node.isHidden = !visible;node.subdivisionLevels=0}
    }
    func render(phase:Double,amount:Float) {
        let direction:Float = facing==3 ? -1 : 1
        func physical(_ p:SIMD2<Float>)->SIMD2<Float> {SIMD2(p.x,p.y*1.5)}
        func length(_ p:SIMD2<Float>)->Float {sqrt(p.x*p.x+p.y*p.y)}
        let h=physical(hip),k=physical(knee),a=physical(ankle)
        for (index,node) in [near,far].enumerated() {
            let offset=WalkCycle.foot(phase+Double(index)*0.5)*amount
            // The far hip is behind the near hip, but both feet share the ground.
            let depth:Float = index==0 ? 0 : -direction*0.022
            let newH=h+SIMD2(depth,0)
            let newA=a+SIMD2(depth+offset.x*direction,offset.y*1.5)
            let newK=WalkCycle.knee(hip:newH,ankle:newA,upper:length(k-h),lower:length(a-k),direction:direction)
            func rigid(_ p:SIMD2<Float>,_ start:SIMD2<Float>,_ end:SIMD2<Float>,_ targetStart:SIMD2<Float>,_ targetEnd:SIMD2<Float>)->SIMD2<Float> {
                let u=end-start,v=targetEnd-targetStart
                let angle=atan2(v.y,v.x)-atan2(u.y,u.x),q=p-start
                return targetStart+SIMD2(q.x*cos(angle)-q.y*sin(angle),q.x*sin(angle)+q.y*cos(angle))
            }
            let dest=source.map {uv -> SIMD2<Float> in
                let aligned=hip+(uv-layerOrigin)*layerScale
                let p=physical(aligned)
                let upper=rigid(p,h,k,newH,newK)
                let lower=rigid(p,k,a,newK,newA)
                let shoe=p+(newA-a)
                func smooth(_ x:Float)->Float {let t=min(1,max(0,x));return t*t*(3-2*t)}
                let kneeBlend=smooth((knee.y+0.025-aligned.y)/0.05)
                let ankleBlend=smooth((ankle.y+0.025-aligned.y)/0.05)
                let leg=upper*(1-kneeBlend)+lower*kneeBlend
                let q=leg*(1-ankleBlend)+shoe*ankleBlend
                return SIMD2(q.x,q.y/1.5)
            }
            node.warpGeometry=SKWarpGeometryGrid(columns:columns,rows:rows,sourcePositions:source,destinationPositions:dest)
        }
    }
}
