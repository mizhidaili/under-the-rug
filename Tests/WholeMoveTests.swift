import Foundation
import simd

@main
struct WholeMoveTests {
    static func expect(_ value: Bool, _ message: String) {
        precondition(value, message)
    }

    static func main() {
        let c = Cloth(width: 400, height: 280, columns: 12)
        let cam = Camera(size: SIMD2(1512, 982))
        c.layout(center: cam.center, angle: 0.31, drop: 0)
        // A folded/bumped rug must keep its shape while carried, too.
        for i in 0..<c.count { c.pos[i].z = Float(i % 7) * 3 }
        c.updateDerived(cam)
        let before = (0..<c.count).map { c.pos[$0] }
        let vertex = c.count / 2
        let screen = cam.project(c.pos[vertex])
        let origin = cam.unproject(screen, z: c.pos[vertex].z)
        let plane = c.pos[vertex].z + 48
        c.beginWholeMove(from: origin)
        expect(c.isMovingWhole && !c.isGrabbing, "Whole-move mode did not begin")
        let targetScreen = screen + SIMD2<Float>(180, -95)
        let target = cam.unproject(targetScreen, z: plane)
        c.moveWhole(to: target)
        let delta = target - origin
        for i in 0..<c.count {
            expect(simd_distance(c.pos[i], before[i] + delta) < 0.001, "Shape stretched")
            expect(c.vel[i] == .zero, "Drag introduced fling velocity")
        }
        expect(simd_distance(cam.project(c.pos[vertex]), targetScreen) < 0.001, "Grab point drifted from cursor")
        let held = (0..<c.count).map { c.pos[$0] }
        for _ in 0..<30 { c.step(dt: 1/60) }
        expect((0..<c.count).allSatisfy { c.pos[$0] == held[$0] }, "Gravity moved held rug")
        // Movement is measured from the original shape, avoiding cumulative drift.
        c.moveWhole(to: cam.unproject(screen, z: plane))
        expect(simd_distance(cam.project(c.pos[vertex]), screen) < 0.001, "Return path drifted")
        c.endWholeMove()
        expect(!c.isMovingWhole, "Release did not restore physics")
        let releaseZ = c.pos[vertex].z
        c.step(dt: 1/60)
        expect(c.pos[vertex].z < releaseZ, "Rug did not fall after release")
        expect((0..<c.count).allSatisfy { c.pos[$0].x.isFinite && c.pos[$0].z.isFinite }, "Unstable release")
        c.beginGrab(vertex: vertex, target: c.pos[vertex] + SIMD3(0, 0, 100))
        expect(c.isGrabbing && !c.isMovingWhole, "Ordinary corner grab broken")
        c.beginWholeMove(from: c.pos[vertex])
        expect((0..<c.count).allSatisfy { c.invMass[$0] == 1 }, "Old corner pins stayed locked")
        c.layout(center: cam.center, angle: 0, drop: 0)
        expect(!c.isMovingWhole && !c.isGrabbing, "Layout did not cancel interaction")
        print("PASS: rigid shape, cursor anchor, held stability, round-trip movement, release gravity, ordinary grab, pin cleanup")
    }
}
