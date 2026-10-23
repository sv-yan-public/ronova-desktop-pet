import AppKit
import SpriteKit
import AVFoundation

let names = ["front", "left", "right", "profile-left", "profile-right"]
let labels = ["立绘姿态", "左斜侧", "右斜侧", "左侧面", "右侧面"]
let defaults = UserDefaults.standard
let testing = CommandLine.arguments.contains("--qa")
let maximumPetHeight: Double = 1440
func bounded(_ v: Double, _ a: Double, _ b: Double) -> Double { min(b,max(a,v)) }

final class Settings {
    var view = defaults.integer(forKey: "view")
    var height = defaults.object(forKey:"height") as? Double ?? 480
    var period = defaults.object(forKey:"period") as? Double ?? 12
    var amplitude = defaults.object(forKey:"amplitude") as? Double ?? 0.7
    var blinkMin = defaults.object(forKey:"blinkMin") as? Double ?? 6
    var blinkMax = defaults.object(forKey:"blinkMax") as? Double ?? 12
    var top = defaults.object(forKey:"top") as? Bool ?? true
    var pass = defaults.bool(forKey:"pass")
    var paused = defaults.bool(forKey:"paused")
    var automatic = defaults.bool(forKey:"automatic")
    var wandering = defaults.bool(forKey:"wandering")
    var rest = false
    init() { view = min(4,max(0,view));height=bounded(height,240,maximumPetHeight);period=bounded(period,8,24); amplitude=bounded(amplitude,0,2.0);blinkMin=bounded(blinkMin,4,16);blinkMax=bounded(blinkMax,blinkMin+1,24) }
    func save() {
        if testing { return }
        for (k,v) in ["view":view,"height":height,"period":period,"amplitude":amplitude,"blinkMin":blinkMin,"blinkMax":blinkMax,"top":top,"pass":pass,"paused":paused,"wandering":wandering,"automatic":automatic] as [String:Any] { defaults.set(v,forKey:k) }
    }
}
let settings = Settings()

final class PetScene: SKScene {
    var pet = SKSpriteNode()
    var legRig: WalkingRig!
    let walkingCostume = SKSpriteNode()
    var gaitPhase: Double = 0
    var gaitBlend: Float = 0
    var clock: Double = 0
    var last: Double = 0
    var nextBlink: Double = 8
    var blinkEnd: Double = -1
    var greeting: Double = -100
    var manual = false
    var blinkCount = 0
    var walking = false
    var facing: Int?
    var displayView: Int { facing ?? settings.view }
    let cols = 56, rows = 84
    var source = [SIMD2<Float>]()
    var textures = [String:SKTexture]()
    var eyeBoxes: [SIMD4<Float>] = [SIMD4(0.465,0.887,0.590,0.924),SIMD4(0.366,0.895,0.470,0.929),SIMD4(0.494,0.895,0.610,0.923),SIMD4(0.293,0.903,0.347,0.928),SIMD4(0.713,0.900,0.764,0.927)]
    let faceBoxes: [SIMD4<Float>] = [SIMD4(0.460,0.855,0.612,0.929),SIMD4(0.373,0.864,0.490,0.933),SIMD4(0.486,0.860,0.615,0.931),SIMD4(0.273,0.867,0.370,0.931),SIMD4(0.696,0.867,0.794,0.931)]
    override init(size: CGSize) {
        super.init(size:size)
        backgroundColor = .clear; scaleMode = .resizeFill
        for y in 0...rows { for x in 0...cols { source.append(SIMD2(Float(x)/Float(cols),Float(y)/Float(rows))) } }
        pet.subdivisionLevels=0; addChild(pet); legRig=WalkingRig(parent:self); loadView(); nextBlink = Double.random(in:settings.blinkMin...settings.blinkMax)
        walkingCostume.zPosition=3; addChild(walkingCostume)
    }
    required init?(coder:NSCoder) { fatalError() }
    func texture(_ name:String) -> SKTexture {
        if let t=textures[name] {return t}
        let url=Bundle.main.resourceURL!.appendingPathComponent("Assets/\(name).png")
        guard let im=NSImage(contentsOf:url) else { fatalError("Missing asset \(name)") }
        let t=SKTexture(image:im);t.filteringMode = .linear;t.usesMipmaps=true; textures[name]=t; return t
    }
    func loadView() {
        let name=names[displayView]
        let bodyName = facing == nil ? name : (displayView == 3 ? "walk-left" : "walk-right")
        pet.texture=texture(facing == nil ? "Clean/"+name : bodyName)
        if facing != nil {legRig.load(displayView);pet.texture=legRig.body}
        let shader=SKShader(source:"""
        void main() {
            vec2 uv = v_tex_coord;
            float mask = smoothstep(u_box.x,u_box.x+0.004,uv.x)*(1.0-smoothstep(u_box.z-0.004,u_box.z,uv.x))*smoothstep(u_box.y,u_box.y+0.003,uv.y)*(1.0-smoothstep(u_box.w-0.003,u_box.w,uv.y));
            // Subtle eyelid narrowing between blinks, confined to the eye box.
            vec2 eyeUV = uv;
            float eyeCenter = (u_box.y+u_box.w)*0.5;
            eyeUV.y += (uv.y-eyeCenter)*u_expression*mask;
            // Use the cleaned artwork's color AND coverage. Old cutouts have
            // pinholes inside the hair that otherwise reappear as dark specks.
            vec4 base = texture2D(u_texture,eyeUV);
            // Keep Clean coverage and lower-body colors as the stable animation base.
            // Refined artwork contributes only opaque upper-body interiors; its
            // generated silhouette must never move an edge or create a pinhole.
            vec4 refined = texture2D(u_refined,eyeUV);
            float detailWeight = smoothstep(0.50,0.60,uv.y)
                * smoothstep(0.98,0.995,base.a)
                * smoothstep(0.98,0.995,refined.a);
            vec3 refinedColor = refined.rgb / max(refined.a,0.001) * base.a;
            vec4 detailed = vec4(mix(base.rgb,refinedColor,detailWeight),base.a);
            // Local face correction; retain the established artwork everywhere else.
            float faceMask = smoothstep(u_face_box.x,u_face_box.x+0.006,uv.x)
                * (1.0-smoothstep(u_face_box.z-0.006,u_face_box.z,uv.x))
                * smoothstep(u_face_box.y,u_face_box.y+0.004,uv.y)
                * (1.0-smoothstep(u_face_box.w-0.004,u_face_box.w,uv.y));
            vec4 face = texture2D(u_face,eyeUV);
            // The face outline is intentionally editable (jaw and lips); use
            // its local coverage too, so the old lip edge cannot ghost through.
            float faceAlpha = min(base.a,face.a);
            vec4 fittedFace = vec4(face.rgb/max(face.a,0.001)*faceAlpha,faceAlpha);
            detailed = mix(detailed,fittedFace,faceMask);
            vec4 closed = texture2D(u_closed,uv);
            vec4 c = mix(detailed,closed,mask*u_blink);
            // Remove nearly invisible matte residue; preserve antialiasing and premultiplication.
            float a = smoothstep(0.025,0.99,detailed.a);
            // Preserve the leg-free body's intentional opening below the waist;
            // cleanup can mistake that empty area for red cloth. Never apply
            // the old matte to the hair or to a full-body idle sprite.
            float cutout = u_body_cutout*(1.0-smoothstep(0.50,0.60,uv.y));
            a = mix(a,min(a,smoothstep(0.025,0.99,texture2D(u_cutout,uv).a)),cutout);
            // Keep the entire hip-length costume in front of the thigh. A
            // waist-only mask exposes the cutout's rear contour during strides.
            a *= mix(1.0,smoothstep(0.34,0.38,uv.y),u_foreground);
            gl_FragColor = vec4(c.rgb*(a/max(c.a,0.001)),a);
        }
        """)
        shader.uniforms=[SKUniform(name:"u_closed",texture:texture(name+"-closed")),SKUniform(name:"u_blink",float:0),SKUniform(name:"u_box",vectorFloat4:eyeBoxes[displayView]),SKUniform(name:"u_foreground",float:0),SKUniform(name:"u_expression",float:0)]
        shader.addUniform(SKUniform(name:"u_face",texture:texture("Face/"+name)))
        shader.addUniform(SKUniform(name:"u_face_box",vectorFloat4:faceBoxes[displayView]))
        shader.addUniform(SKUniform(name:"u_refined",texture:texture("Refined/"+(facing == nil ? name : bodyName+"-body"))))
        shader.addUniform(SKUniform(name:"u_body_cutout",float:facing == nil ? 0 : 1))
        shader.addUniform(SKUniform(name:"u_cutout",texture:facing == nil ? pet.texture! : texture(bodyName+"-body")))
        walkingCostume.texture=pet.texture
        walkingCostume.shader=shader.copy() as? SKShader
        walkingCostume.shader?.uniforms=shader.uniforms.map { $0.name == "u_foreground" ? SKUniform(name:"u_foreground",float:1) : $0 }
        walkingCostume.isHidden=facing == nil
        pet.shader=shader; layout(); render(clock,blink:false)
    }
    func layout() {
        let h = min(size.height-40,(size.width-120)*1.5)
        pet.size=CGSize(width:h/1.5,height:h); pet.position=CGPoint(x:size.width/2,y:size.height/2)
        walkingCostume.size=pet.size; walkingCostume.position=pet.position
        legRig?.layout(size:pet.size,position:pet.position,visible:facing != nil)
    }
    override func didChangeSize(_ oldSize:CGSize) { layout() }
    override func update(_ time:TimeInterval) {
        if manual {return}
        let dt=last==0 ? 0 : min(0.1,time-last);last=time
        if settings.paused {return}
        gaitBlend += (min(1,max(0,walking ? 1 : 0))-gaitBlend)*Float(min(1,dt*8))
        clock += dt
        if clock >= nextBlink { blinkEnd=clock+0.16;nextBlink=clock+Double.random(in:settings.blinkMin...settings.blinkMax);blinkCount += 1 }
        render(clock,blink:clock < blinkEnd)
    }
    func render(_ t:Double,blink:Bool) {
        let p=Float(t/settings.period*2 * .pi), a=Float(settings.amplitude)
        let nod=Float(max(0,1-abs(t-greeting-1.8)/1.8))
        let phase = manual ? t/WalkCycle.previewPeriod : gaitPhase
        let gait=Float(phase*2 * .pi)
        let walkPose = facing != nil
        // A profile is narrow and sits off-center in its texture. The old
        // centered hair mask incorrectly treated its torso and legs as hair.
        let profile = displayView >= 3
        let idleScale:Float = displayView == 0 ? 1 : (profile ? 0.4 : 0.65)
        let idleAmplitude = a*idleScale
        let walkAmount:Float = walkPose ? (manual ? (walking ? 1 : 0) : gaitBlend) : 0
        let pelvis=WalkCycle.pelvis(phase,amount:walkAmount)
        let clothPhase = walkPose ? gait : p
        let clothScale:Float = walkPose ? walkAmount*0.65 : a*(displayView == 0 ? 1 : (profile ? 0.25 : 0.5))
        let bodyX:Float = walkPose ? pelvis.x : sin(p)*0.010*idleAmplitude
        let bodyY:Float = walkPose ? pelvis.y : sin(p+0.5)*0.010*idleAmplitude
        let angle:Float = walkPose ? 0 : sin(p-0.35)*0.012*idleAmplitude
        let ca=cos(angle), sa=sin(angle)
        var dest=[SIMD2<Float>](); dest.reserveCapacity(source.count)
        for original in source {
            let q = BustShape.project(original,view:displayView)
            let x=q.x,y=q.y
            let upper=min(1,max(0,(y-0.12)/0.56))
            var outer=min(1,max(0,(abs(x-0.5)-0.14)/0.25))
            if displayView != 0 {
                let left:Float = profile ? (displayView == 3 ? 0.21 : 0.55) : 0.30
                let right:Float = profile ? (displayView == 3 ? 0.56 : 0.91) : 0.72
                let protected = WalkingUpperBody.smooth((x-left+0.045)/0.045)
                    * (1-WalkingUpperBody.smooth((x-right)/0.045))
                // Keep the painted body/legs rigid; only the outer hair and
                // fabric receive the local wave. Global motion is a rotation.
                outer *= 1-protected
            }
            let hairRegion=max(0,min(1,(0.86-y)*5))*min(1,max(0,(y-0.12)*5))
            let hem=max(0,1-y/0.40)*outer
            let hair=sin(clothPhase-0.8-y*2.0+x)*0.018*clothScale*outer*hairRegion
            let skirt=sin(clothPhase-1.1+x*2)*0.016*clothScale*hem
            // Floating pose: translate every vertex, including both feet.
            var dx=bodyX+hair+skirt
            var dy=bodyY + cos(clothPhase-0.8-y*2)*0.004*clothScale*outer*hairRegion - nod*0.005*upper
            if walkPose {
                let motion=WalkingUpperBody.offset(q,phase:phase,time:t,amount:walkAmount,facing:displayView)
                dx += motion.x; dy += motion.y
            }
            // Rotate in physical aspect ratio around the body center, then float.
            let rx=(x-0.5)*ca-(y-0.52)*1.5*sa
            let ry=(x-0.5)/1.5*sa+(y-0.52)*ca
            dest.append(SIMD2(0.5+rx+dx,0.52+ry+dy))
        }
        if walkPose {legRig.render(phase:phase,amount:manual ? (walking ? 1 : 0) : gaitBlend)}
        pet.warpGeometry=SKWarpGeometryGrid(columns:cols,rows:rows,sourcePositions:source,destinationPositions:dest)
        walkingCostume.warpGeometry=pet.warpGeometry
        // Preview blinks use time, not gait phase, so they don't repeat every step.
        let previewBlink = manual && walkPose && t.truncatingRemainder(dividingBy:4.7) > 2.2 && t.truncatingRemainder(dividingBy:4.7) < 2.36
        for node in [pet,walkingCostume] {
            node.shader?.uniformNamed("u_blink")?.floatValue = (blink || previewBlink || settings.rest) ? 1 : 0
            node.shader?.uniformNamed("u_expression")?.floatValue = (0.5+0.5*sin(Float(t)*1.15))*0.22*walkAmount
        }
    }
    func rescheduleBlink() {nextBlink=clock+Double.random(in:settings.blinkMin...settings.blinkMax);blinkEnd = -1}
}

final class PetView:SKView {
    weak var owner:Controller?
    var dragOffset: NSPoint?
    override var acceptsFirstResponder:Bool {true}
    override func mouseDown(with event:NSEvent) {
        if event.clickCount==2 {owner?.greet();return}
        dragOffset = event.locationInWindow
    }
    override func mouseDragged(with event:NSEvent) {
        guard let offset=dragOffset,let w=window else{return}
        let p=NSEvent.mouseLocation; w.setFrameOrigin(NSPoint(x:p.x-offset.x,y:p.y-offset.y))
    }
    override func mouseUp(with event:NSEvent) {dragOffset=nil;owner?.savePosition()}
    override func rightMouseDown(with event:NSEvent) {if let m=owner?.makeMenu(){NSMenu.popUpContextMenu(m,with:event,for:self)}}
    override func scrollWheel(with event:NSEvent) {owner?.resize(to:settings.height+Double(event.scrollingDeltaY)*2)}
}
final class PetWindow:NSPanel {override var canBecomeKey:Bool {false}}

final class Controller:NSObject,NSApplicationDelegate,NSWindowDelegate {
    var window:PetWindow!
    var view:PetView!
    var scene:PetScene!
    var status:NSStatusItem!
    var panel:NSPanel?
    var sliders:[String:NSSlider]=[:]
    var valueLabels:[String:NSTextField]=[:]
    var wakeTokens:[NSObjectProtocol]=[]
    var walkTimer:Timer?
    var walkDirection:CGFloat = 1
    var walkSpeed:CGFloat = 0
    var walkX:CGFloat?
    var turnWait:Double = 0
    var automaticMove=false
    enum Routine:String {case walk, settle, rise, hover, land}
    var routine:Routine = .walk
    var routineTime:Double = 0
    var routineDuration:Double = 25
    var routineBaseY:CGFloat = 0
    var routineLift:CGFloat = 0
    var hoverEvent:Double = 9
    var restUntil:Double = -1
    var viewBag:[Int]=[]
    var routineVisits=Set<String>()
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        window=PetWindow(contentRect:NSRect(x:120,y:100,width:340,height:500),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        window.title="Ronova";window.isOpaque=false;window.backgroundColor = .clear;window.hasShadow=false;window.hidesOnDeactivate=false;window.isReleasedWhenClosed=false
        window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];window.delegate=self
        view=PetView(frame:window.contentView!.bounds);view.owner=self;view.autoresizingMask=[.width,.height];view.allowsTransparency=true;view.preferredFramesPerSecond=30;view.ignoresSiblingOrder=true
        window.contentView=view
        scene=PetScene(size:view.bounds.size);view.presentScene(scene)
        resize(to:settings.height)
        if let point=defaults.string(forKey:"origin") {window.setFrameOrigin(NSPointFromString(point))}
        clampPosition();applyWindow();window.orderFrontRegardless(); view.isPaused=settings.paused
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        if let button=status.button {
            let icon=NSImage(contentsOf:Bundle.main.resourceURL!.appendingPathComponent("Assets/StatusHead.png"))
            icon?.size=NSSize(width:18,height:18);icon?.isTemplate=false
            button.image=icon;button.imagePosition = .imageOnly
            button.title=icon == nil ? "若" : ""
            button.setAccessibilityLabel("Ronova菜单")
        }
        status.button?.toolTip="Ronova：设置、恢复鼠标、退出";status.button?.target=self;status.button?.action=#selector(statusClick)
        let nc=NSWorkspace.shared.notificationCenter
        wakeTokens.append(nc.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main){[weak self] _ in self?.view.isPaused=true})
        wakeTokens.append(nc.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main){[weak self] _ in self?.scene.last=0;self?.view.isPaused=settings.paused})
        if CommandLine.arguments.contains("--qa-status") {
            let icon=status.button?.image
            let report:[String:Any] = ["iconLoaded":icon != nil,"width":icon?.size.width ?? 0,"height":icon?.size.height ?? 0,"whiteOriginal":icon?.isTemplate == false,"titleEmpty":status.button?.title == "","menuActionConnected":status.button?.action == #selector(statusClick)]
            let data=try! JSONSerialization.data(withJSONObject:report,options:.prettyPrinted)
            try! data.write(to:URL(fileURLWithPath:CommandLine.arguments.last!));NSApp.terminate(nil);return
        }
        if settings.automatic {startRoutine()} else if settings.wandering {updateWalkingView()}
        if !testing {walkTimer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true){[weak self] _ in self?.activityTick(1.0/30)}}
        if testing {DispatchQueue.main.asyncAfter(deadline:.now()+1){self.runQA()}}
    }
    func activityTick(_ dt:Double) {
        guard !settings.paused, !view.isPaused, view.dragOffset == nil else {
            walkSpeed=0;walkX=nil;scene.walking=false
            if view.dragOffset != nil {routineBaseY=window.frame.minY;routineLift=0}
            return
        }
        if settings.automatic {routineTick(dt)} else {walkTick(dt)}
    }
    func nextRoutineView()->Int {
        if viewBag.isEmpty {viewBag=Array(0..<5).shuffled()}
        if viewBag.last == settings.view && viewBag.count>1 {viewBag.swapAt(0,viewBag.count-1)}
        return viewBag.removeLast()
    }
    func startRoutine() {
        settings.rest=false;settings.wandering=true
        routine = .walk;routineTime=0;routineDuration=Double.random(in:20...38)
        walkSpeed=0;walkX=nil;turnWait=0;updateWalkingView()
    }
    func stopRoutine() {
        settings.automatic=false;settings.rest=false;restUntil = -1;settings.save()
    }
    func routineTick(_ dt:Double) {
        routineVisits.insert(routine.rawValue)
        routineTime += dt
        switch routine {
        case .walk:
            walkTick(dt)
            if routineTime>=routineDuration {
                routine = .settle;routineTime=0;scene.walking=false;walkSpeed=0
            }
        case .settle:
            if routineTime>=1.2 {
                let area=(window.screen ?? NSScreen.main)!.visibleFrame.insetBy(dx:8,dy:8)
                routineBaseY=window.frame.minY
                routineLift=min(32,max(0,area.maxY-window.frame.maxY))
                settings.view=walkDirection<0 ? 3 : 4
                settings.wandering=false;updateWalkingView()
                routine = .rise;routineTime=0
            }
        case .rise, .land:
            let u=min(1,routineTime/2.8), ease=u*u*(3-2*u)
            let offset=routine == .rise ? ease : 1-ease
            if let area=(window.screen ?? NSScreen.main)?.visibleFrame {
                let lower = Double(area.minY) + 8
                let upper = max(lower, Double(area.maxY - window.frame.height) - 8)
                let y=bounded(Double(routineBaseY)+Double(routineLift)*offset,lower,upper)
                automaticMove=true;window.setFrameOrigin(CGPoint(x:window.frame.minX,y:y));automaticMove=false
            }
            if u>=1 {
                if routine == .rise {
                    routine = .hover;routineTime=0;routineDuration=Double.random(in:20...34)
                    settings.view=nextRoutineView();scene.loadView()
                    hoverEvent=Double.random(in:7...11);restUntil = -1
                } else {startRoutine()}
            }
        case .hover:
            if restUntil>=0 && routineTime>=restUntil {settings.rest=false;restUntil = -1}
            if routineTime>=hoverEvent {
                if Bool.random() {scene.greeting=scene.clock}
                else {settings.rest=true;restUntil=routineTime+Double.random(in:2.5...4.5)}
                hoverEvent=routineTime+Double.random(in:9...14)
            }
            if routineTime>=routineDuration {
                settings.rest=false;routine = .land;routineTime=0
                settings.view=walkDirection<0 ? 3 : 4;scene.loadView()
            }
        }
    }
    @objc func toggleAutomatic() {
        if settings.automatic {stopRoutine()}
        else {settings.automatic=true;startRoutine()}
        settings.save()
    }
    func clampPosition() {
        let screens=NSScreen.screens.map{$0.visibleFrame}
        if !screens.contains(where:{$0.intersection(window.frame).width>80 && $0.intersection(window.frame).height>80}) {window.setFrameOrigin(NSScreen.main?.visibleFrame.origin ?? .zero)}
    }
    func updateWalkingView() {
        scene.walking=settings.wandering && !settings.rest
        scene.facing=settings.wandering ? (walkDirection < 0 ? 3 : 4) : nil
        scene.loadView()
    }
    func walkTick(_ dt:Double) {
        guard settings.wandering, !settings.paused, !settings.rest, !view.isPaused,
              view.dragOffset == nil else {walkSpeed=0;walkX=nil;scene.walking=false;return}
        guard let screen=window.screen ?? NSScreen.main else {return}
        let area=screen.visibleFrame.insetBy(dx:8,dy:8)
        let maxX=max(area.minX,area.maxX-window.frame.width)
        let maxY=max(area.minY,area.maxY-window.frame.height)
        var origin=window.frame.origin
        if let x=walkX, abs(x-origin.x)<2 {origin.x=x}
        origin.x=bounded(origin.x,area.minX,maxX)
        origin.y=bounded(origin.y,area.minY,maxY)
        if turnWait>0 {turnWait=max(0,turnWait-dt);scene.walking=false}
        else if maxX-area.minX>4 {
            scene.walking=true
            let strideSpeed=max(8,scene.pet.size.width * CGFloat(WalkCycle.stride / WalkCycle.stance / WalkCycle.previewPeriod))
            walkSpeed=min(strideSpeed,walkSpeed+CGFloat(dt)*12)
            origin.x += walkDirection*walkSpeed*CGFloat(dt)
            if origin.x<=area.minX || origin.x>=maxX {
                origin.x=bounded(origin.x,area.minX,maxX)
                walkDirection *= -1;walkSpeed=0;walkX=nil;turnWait=0.8
                updateWalkingView();scene.walking=false
            }
        } else {scene.walking=false}
        if scene.walking {
            let moved=abs(origin.x-(walkX ?? window.frame.origin.x))
            scene.gaitPhase += Double(moved/max(1,scene.pet.size.width)) / (WalkCycle.stride/WalkCycle.stance)
        }
        walkX=origin.x
        automaticMove=true;window.setFrameOrigin(origin);automaticMove=false
    }
    @objc func toggleWalk(){
        stopRoutine()
        settings.wandering.toggle();settings.rest=false;walkSpeed=0;walkX=nil;turnWait=0
        updateWalkingView();settings.save();savePosition()
    }
    func applyWindow(){window.level=settings.top ? .floating : .normal;window.ignoresMouseEvents=settings.pass}
    func savePosition(){if !testing{defaults.set(NSStringFromPoint(window.frame.origin),forKey:"origin")}}
    func windowDidMove(_ n:Notification){if !automaticMove {savePosition()}}
    func resize(to h:Double){
        settings.height=bounded(h,240,maximumPetHeight)
        let origin=window.frame.origin
        window.setFrame(NSRect(x:origin.x,y:origin.y,width:settings.height/1.5+120,height:settings.height+40),display:true)
        scene?.size=view.bounds.size;scene?.layout();settings.save()
    }
    func item(_ title:String,_ action:Selector,_ tag:Int=0,_ checked:Bool=false)->NSMenuItem {
        let i=NSMenuItem(title:title,action:action,keyEquivalent:"");i.target=self;i.tag=tag;i.state=checked ? .on : .off;return i
    }
    func makeMenu()->NSMenu {
        let m=NSMenu();m.addItem(NSMenuItem(title:"Ronova 1.3.0",action:nil,keyEquivalent:""))
        m.addItem(.separator())
        let v=NSMenuItem(title:"视角",action:nil,keyEquivalent:"");let vm=NSMenu();for i in 0..<5{vm.addItem(item(labels[i],#selector(selectView(_:)),i,settings.view==i))};v.submenu=vm;m.addItem(v)
        m.addItem(item("自然待机",#selector(natural),0,!settings.rest));m.addItem(item("闭目休息",#selector(rest),0,settings.rest));m.addItem(item("轻轻致意（双击）",#selector(greet)))
        m.addItem(item("随机生活 · 走动 / 悬浮 / 小动作",#selector(toggleAutomatic),0,settings.automatic))
        m.addItem(item(settings.wandering ? "停止走动 · 原地悬浮" : "在屏幕内走来走去",#selector(toggleWalk),0,settings.wandering))
        m.addItem(item("动作与大小设置…",#selector(showSettings)))
        m.addItem(item(settings.paused ? "恢复动作" : "暂停动作",#selector(togglePause)))
        m.addItem(item("保持置顶",#selector(toggleTop),0,settings.top));m.addItem(item("鼠标穿透",#selector(togglePass),0,settings.pass))
        m.addItem(item("恢复鼠标并移回屏幕",#selector(recover)))
        m.addItem(.separator());m.addItem(item("退出Ronova",#selector(quit)))
        return m
    }
    @objc func statusClick(){status.menu=makeMenu();status.button?.performClick(nil);status.menu=nil}
    @objc func selectView(_ item:NSMenuItem){stopRoutine();settings.view=item.tag;settings.wandering=false;updateWalkingView();settings.save();view.setNeedsDisplay(view.bounds)}
    @objc func natural(){stopRoutine();settings.wandering=false;settings.save();settings.rest=false;updateWalkingView();scene.render(scene.clock,blink:false);scene.rescheduleBlink()}
    @objc func rest(){stopRoutine();settings.rest=true;scene.walking=false;scene.render(scene.clock,blink:true)}
    @objc func greet(){stopRoutine();settings.rest=false;scene.greeting=scene.clock;if settings.paused{togglePause()}}
    @objc func togglePause(){settings.paused.toggle();view.isPaused=settings.paused;scene.last=0;settings.save()}
    @objc func toggleTop(){settings.top.toggle();applyWindow();settings.save()}
    @objc func togglePass(){settings.pass.toggle();applyWindow();settings.save()}
    @objc func recover(){settings.pass=false;applyWindow();if let s=NSScreen.main{window.setFrameOrigin(CGPoint(x:s.visibleFrame.maxX-window.frame.width-30,y:s.visibleFrame.minY+30))};window.orderFrontRegardless();settings.save();savePosition()}
    @objc func quit(){settings.save();savePosition();NSApp.terminate(nil)}
    @objc func showSettings(){
        if let p=panel {p.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);return}
        let p=NSPanel(contentRect:NSRect(x:200,y:200,width:460,height:420),styleMask:[.titled,.closable],backing:.buffered,defer:false);p.title="Ronova · 动作设置";p.isReleasedWhenClosed=false
        let content=p.contentView!
        func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat=24)->NSTextField {let l=NSTextField(wrappingLabelWithString:s);l.frame=NSRect(x:x,y:y,width:w,height:h);content.addSubview(l);return l}
        _=text("缓慢呼吸 · 独立随机眨眼",24,371,410)
        let configs:[(String,String,Double,Double,Double)]=[("height","人物高度",settings.height,240,maximumPetHeight),("period","轻晃周期（秒）",settings.period,8,24),("amplitude","晃动幅度",settings.amplitude,0,2.0),("blinkMin","眨眼最短间隔（秒）",settings.blinkMin,4,16),("blinkMax","眨眼最长间隔（秒）",settings.blinkMax,5,24)]
        for (idx,c) in configs.enumerated(){let y=CGFloat(325-idx*49);_=text(c.1,24,y,170);let sl=NSSlider(value:c.2,minValue:c.3,maxValue:c.4,target:self,action:#selector(slide(_:)));sl.identifier=NSUserInterfaceItemIdentifier(c.0);sl.frame=NSRect(x:205,y:y,width:160,height:24);sl.isContinuous=true;content.addSubview(sl);sliders[c.0]=sl;valueLabels[c.0]=text(String(format:"%.1f",c.2),378,y,65)}
        let b=NSButton(title:"更慢：18 秒 / 9–16 秒眨眼",target:self,action:#selector(slower));b.frame=NSRect(x:24,y:56,width:300,height:30);content.addSubview(b)
        _=text("拖动人物移动；滚轮缩放；右键或菜单栏白色头像操作。\n人物高度最高 1440 点，超出屏幕时可拖动查看。",24,8,420,43)
        panel=p;p.center();p.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func slide(_ s:NSSlider){
        switch s.identifier!.rawValue {
        case "height":resize(to:s.doubleValue)
        case "period":settings.period=s.doubleValue
        case "amplitude":settings.amplitude=s.doubleValue
        case "blinkMin":settings.blinkMin=s.doubleValue;settings.blinkMax=max(settings.blinkMax,settings.blinkMin+1);scene.rescheduleBlink()
        case "blinkMax":settings.blinkMax=max(s.doubleValue,settings.blinkMin+1);scene.rescheduleBlink()
        default:break
        };settings.save();refreshSliders()
    }
    func refreshSliders(){for(k,v) in ["height":settings.height,"period":settings.period,"amplitude":settings.amplitude,"blinkMin":settings.blinkMin,"blinkMax":settings.blinkMax]{sliders[k]?.doubleValue=v;valueLabels[k]?.stringValue=String(format:"%.1f",v)}}
    @objc func slower(){settings.period=18;settings.blinkMin=9;settings.blinkMax=16;scene.rescheduleBlink();settings.save();refreshSliders()}
    func runQA() {
        if CommandLine.arguments.contains("--large") { resize(to:maximumPetHeight) }
        settings.automatic=false;settings.wandering=false;scene.facing=nil;scene.walking=false
        let dir=CommandLine.arguments.last!;try? FileManager.default.createDirectory(atPath:dir,withIntermediateDirectories:true)
        scene.manual=true;settings.paused=false;view.isPaused=false;settings.amplitude=CommandLine.arguments.contains("--max") ? 2.0 : 1.3;settings.period=CommandLine.arguments.contains("--reference") ? 8 : (CommandLine.arguments.contains("--slow") ? 18 : 12);settings.blinkMin=CommandLine.arguments.contains("--slow") ? 9 : 6;settings.blinkMax=CommandLine.arguments.contains("--slow") ? 16 : 12
        var report=[String:Any]();report["transparentWindow"] = !window.isOpaque && window.backgroundColor == .clear && !window.hasShadow
        settings.pass=true;applyWindow();report["passThrough"]=window.ignoresMouseEvents
        settings.pass=false;applyWindow();report["passRecovery"] = !window.ignoresMouseEvents
        settings.top=false;applyWindow();report["normalLevel"]=window.level == .normal
        settings.top=true;applyWindow();report["floatingLevel"]=window.level == .floating
        if CommandLine.arguments.contains("--walk") {
            settings.wandering=true;updateWalkingView()
            if let area=(window.screen ?? NSScreen.main)?.visibleFrame {
                window.setFrameOrigin(CGPoint(x:area.maxX-window.frame.width-10,y:area.minY+8))
            }
            walkDirection=1;walkSpeed=0;walkX=nil;turnWait=0;updateWalkingView()
            var inside=true;var turned=false;let startDirection=walkDirection
            for _ in 0..<12000 {
                walkTick(1.0/30)
                if let area=(window.screen ?? NSScreen.main)?.visibleFrame {
                    inside = inside && area.insetBy(dx:-1,dy:-1).contains(window.frame)
                }
                if walkDirection != startDirection {turned=true}
            }
            report["walkStaysOnScreen"]=inside;report["walkTurnsAtEdge"]=turned
            let saved=window.frame.origin;settings.paused=true;walkTick(1);report["walkPauseStopsPosition"]=window.frame.origin==saved;settings.paused=false
            view.dragOffset = .zero;walkTick(1);report["walkDragStopsPosition"]=window.frame.origin==saved;view.dragOffset=nil
            settings.wandering=false;scene.facing=nil;scene.walking=false
        }
        if CommandLine.arguments.contains("--auto") {
            settings.automatic=true;startRoutine();routineVisits=[]
            var staysInside=true
            for _ in 0..<24000 {
                activityTick(1.0/30)
                if let area=(window.screen ?? NSScreen.main)?.visibleFrame {staysInside = staysInside && area.insetBy(dx:-1,dy:-1).contains(window.frame)}
            }
            report["routineVisits"]=Array(routineVisits).sorted()
            report["routineAllStages"]=routineVisits.count==5
            report["routineStaysInside"]=staysInside
            let oldTime=routineTime, oldPoint=window.frame.origin
            settings.paused=true;activityTick(1);report["routinePauseFreezes"]=routineTime==oldTime && window.frame.origin==oldPoint;settings.paused=false
            view.dragOffset = .zero;activityTick(1);report["routineDragFreezes"]=routineTime==oldTime;view.dragOffset=nil
            stopRoutine();settings.wandering=false;scene.facing=nil;scene.walking=false
        }
        var planted = true, alternating = true, continuous = true
        for i in 0..<1000 {
            let p = Double(i)/1000
            let a = WalkCycle.foot(p), b = WalkCycle.foot(p+0.5)
            alternating = alternating && !(a.y > 0.00001 && b.y > 0.00001)
            if p+0.0001 < WalkCycle.stance {
                let next = WalkCycle.foot(p+0.0001)
                let screenDrift = Double(next.x-a.x) + WalkCycle.stride/WalkCycle.stance*0.0001
                planted = planted && abs(screenDrift) < 0.000001 && a.y == 0
            }
            let next = WalkCycle.foot(p+0.001)
            continuous = continuous && abs(next.x-a.x)<0.002 && abs(next.y-a.y)<0.002
        }
        report["stanceFootLocksToGround"]=planted
        report["legsAlternateWithGroundSupport"]=alternating
        report["gaitLoopIsContinuous"]=continuous
        let h=SIMD2<Float>(0,0), a=SIMD2<Float>(0.03,-0.59)
        let k=WalkCycle.knee(hip:h,ankle:a,upper:0.3,lower:0.31,direction:1)
        func length(_ v:SIMD2<Float>)->Float {sqrt(v.x*v.x+v.y*v.y)}
        report["legBonesKeepTheirLength"] = abs(length(k-h)-0.3)<0.0001 && abs(length(a-k)-0.31)<0.0001
        let savedAmplitude=settings.amplitude
        let savedGreeting=scene.greeting
        scene.greeting = -100 // Isolate idle measurements from randomized routine greetings.
        settings.amplitude=2;scene.facing=nil;scene.walking=false
        var maxProfileStretch:Float=0
        for side in [3,4] {
            settings.view=side;scene.loadView()
            for frame in 0..<32 {
                scene.render(Double(frame)/32*settings.period,blink:false)
                let grid=scene.pet.warpGeometry as! SKWarpGeometryGrid
                for row in 11..<65 {for col in (side == 3 ? 14..<30 : 33..<50) {
                    let i=row*(scene.cols+1)+col
                    for j in [i+1,i+scene.cols+1] {
                        let before=BustShape.project(scene.source[j],view:side)-BustShape.project(scene.source[i],view:side)
                        let after=grid.destPosition(at:j)-grid.destPosition(at:i)
                        let original=length(SIMD2(before.x,before.y*1.5))
                        let deformed=length(SIMD2(after.x,after.y*1.5))
                        maxProfileStretch=max(maxProfileStretch,abs(deformed/original-1))
                    }
                }}
            }
        }
        report["maxProfileBodyStretchAtMaximumAmplitude"]=maxProfileStretch
        report["profileBodyKeepsProportionsAtMaximumAmplitude"]=maxProfileStretch<0.005
        settings.amplitude=savedAmplitude
        scene.greeting=savedGreeting
        report["assets"]=names;report["periodSeconds"]=settings.period;report["blinkRangeSeconds"]=[settings.blinkMin,settings.blinkMax]
        scene.manual=false;scene.clock=0;scene.last=0;scene.rescheduleBlink()
        var blinkTimes=[Double]();var previousCount=scene.blinkCount
        for frame in 1...3600 {scene.update(Double(frame)/30);if scene.blinkCount != previousCount {blinkTimes.append(scene.clock);previousCount=scene.blinkCount}}
        let intervals=zip(blinkTimes.dropFirst(),blinkTimes).map{$0-$1}
        report["simulatedBlinkIntervalsSeconds"]=intervals
        report["blinkIntervalsInRange"]=intervals.allSatisfy{$0 >= settings.blinkMin && $0 <= settings.blinkMax+0.034}
        let frozen=scene.clock;settings.paused=true;scene.update(121);report["pauseFreezesClock"]=scene.clock==frozen;settings.paused=false
        scene.manual=true;scene.clock=0;scene.last=0;scene.rescheduleBlink()
        scene.greeting = -100
        var index=0
        func step(){
            if index >= (CommandLine.arguments.contains("--idle-samples") ? 46 : 30) {if CommandLine.arguments.contains("--quick") { NSApp.terminate(nil);return };self.captureMovie(dir:dir){
                if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted){try? data.write(to:URL(fileURLWithPath:dir+"/checks.json"))};NSApp.terminate(nil)};return}
            let outputName:String
            if index<10 {
                settings.view=index/2;self.scene.facing=nil;self.scene.walking=false
                outputName=names[index/2]
            } else if index<14 {
                self.scene.facing=index<12 ? 3 : 4;self.scene.walking=true
                outputName=index<12 ? "walk-left" : "walk-right"
            } else if index<30 {
                self.scene.facing=index<22 ? 3 : 4;self.scene.walking=true
                outputName="gait-\(index<22 ? "left" : "right")-\((index-14)%8)"
            } else {
                settings.view=index<38 ? 3 : 4;self.scene.facing=nil;self.scene.walking=false
                outputName="idle-\(index<38 ? "left" : "right")-\((index-30)%8)"
            }
            let time=index<14 ? 0 : (index<30 ? Double((index-14)%8)/8*WalkCycle.previewPeriod : Double((index-30)%8)/8*settings.period)
            self.scene.loadView();self.scene.render(time,blink:index<14 && index%2==1)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.15){
                if let cg=self.view.texture(from:self.scene)?.cgImage(){let rep=NSBitmapImageRep(cgImage:cg);try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:dir+"/\(outputName)-\(index%2).png"))}
                index += 1;step()
            }
        };step()
    }
    func captureMovie(dir:String,completion:@escaping()->Void){
        settings.view=CommandLine.arguments.contains("--side") ? 4 : 0;scene.walking=CommandLine.arguments.contains("--walk");scene.facing=scene.walking ? 4 : nil;scene.loadView();scene.size=CGSize(width:440,height:520);window.setContentSize(scene.size);scene.layout()
        let url=URL(fileURLWithPath:dir+"/idle-\(Int(settings.period))s.mp4");try? FileManager.default.removeItem(at:url)
        guard let writer=try? AVAssetWriter(outputURL:url,fileType:.mp4) else{completion();return}
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:880,AVVideoHeightKey:1040]);input.expectsMediaDataInRealTime=false
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:880,kCVPixelBufferHeightKey as String:1040])
        writer.add(input);writer.startWriting();writer.startSession(atSourceTime:.zero)
        var frame=0
        func tick(){
            if frame>=Int(settings.period*30){input.markAsFinished();writer.finishWriting{DispatchQueue.main.async{completion()}};return}
            if !input.isReadyForMoreMediaData {DispatchQueue.main.asyncAfter(deadline:.now()+0.01){tick()};return}
            let t=Double(frame)/30;self.scene.render(t,blink:t>=min(10.2,settings.period*0.6) && t<min(10.2,settings.period*0.6)+0.16)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.035){
                if let cg=self.view.texture(from:self.scene)?.cgImage(){
                    var buf:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&buf)
                    if let pb=buf{CVPixelBufferLockBaseAddress(pb,[])
                        if let ctx=CGContext(data:CVPixelBufferGetBaseAddress(pb),width:880,height:1040,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pb),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue){ctx.setFillColor(CGColor(red:0.20,green:0.23,blue:0.28,alpha:1));ctx.fill(CGRect(x:0,y:0,width:880,height:1040));ctx.draw(cg,in:CGRect(x:0,y:0,width:880,height:1040))}
                        CVPixelBufferUnlockBaseAddress(pb,[]);adaptor.append(pb,withPresentationTime:CMTime(value:Int64(frame),timescale:30))
                    }
                };frame += 1;tick()
            }
        };tick()
    }
}
let app=NSApplication.shared
let controller=Controller();app.delegate=controller;app.run()
