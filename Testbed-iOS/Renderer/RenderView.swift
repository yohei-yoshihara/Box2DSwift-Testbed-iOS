/**
Copyright (c) 2006-2014 Erin Catto http://www.box2d.org
Copyright (c) 2015 - Yohei Yoshihara

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
claim that you wrote the original software. If you use this software
in a product, an acknowledgment in the product documentation would be
appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be
misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.

This version of box2d was developed by Yohei Yoshihara. It is based upon
the original C++ code written by Erin Catto.
*/

import QuartzCore
import Metal
import MetalKit
import Box2D

protocol RenderViewDelegate: AnyObject {
  func simulationLoop(renderView: RenderView)
}

class RenderView: UIView, MTKViewDelegate, b2Draw {
  weak var delegate: RenderViewDelegate?
  
  var metalKitView: MTKView
  var renderer: Renderer!
  var vertexData = [SIMD2<Float>]()
  var left: b2Float = -1
  var right: b2Float = 1
  var bottom: b2Float = -1
  var top: b2Float = 1
  
  override init(frame: CGRect) {
    metalKitView = MTKView(frame: frame, device: MTLCreateSystemDefaultDevice())
    super.init(frame: frame)
    
    metalKitView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(metalKitView)
    NSLayoutConstraint.activate([
      metalKitView.topAnchor.constraint(equalTo: topAnchor),
      metalKitView.leadingAnchor.constraint(equalTo: leadingAnchor),
      bottomAnchor.constraint(equalTo: metalKitView.bottomAnchor),
      trailingAnchor.constraint(equalTo: metalKitView.trailingAnchor),
    ])
    renderer = Renderer(metalKitView: metalKitView)
    metalKitView.delegate = self
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("not supported")
  }
  
  deinit {
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    renderer.mtkView(view, drawableSizeWillChange: size)
  }
  
  func draw(in view: MTKView) {
    renderer.preRender(in: view)
    renderer.setOrtho2D(left: left, right: right, bottom: bottom, top: top)
    delegate?.simulationLoop(renderView: self)
    renderer.postRender(in: view)
  }

  func preRender() {
  }
  
  func postRender() {
  }
  
  func setOrtho2D(left: b2Float, right: b2Float, bottom: b2Float, top: b2Float) {
    self.left = left
    self.right = right
    self.bottom = bottom
    self.top = top
  }
  
  // MARK: - b2Draw
  
  /// Set the drawing flags.
  func setFlags(_ flags : UInt32) {
    m_drawFlags = flags
  }
  
  /// Get the drawing flags.
  var flags: UInt32 {
    get {
      return m_drawFlags
    }
  }
  
  /// Append flags to the current flags.
  func appendFlags(_ flags : UInt32) {
    m_drawFlags |= flags
  }
  
  /// Clear flags from the current flags.
  func clearFlags(_ flags : UInt32) {
    m_drawFlags &= ~flags
  }
  
  /// Draw a closed polygon provided in CCW order.
  func drawPolygon(_ vertices: [b2Vec2], _ color: b2Color) {
    vertexData.removeAll(keepingCapacity: true)
    for v in vertices {
      vertexData.append(SIMD2<Float>(v.x, v.y))
    }
    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.draw(mode: .lineLoop, vertices: vertexData)
  }
  
  /// Draw a solid closed polygon provided in CCW order.
  func drawSolidPolygon(_ vertices: [b2Vec2], _ color: b2Color) {
    vertexData.removeAll(keepingCapacity: true)
    for v in vertices {
      vertexData.append(SIMD2<Float>(v.x, v.y))
    }
    renderer.enableBlend()
    renderer.setColor(red: 0.5 * color.r, green: 0.5 * color.g, blue: 0.5 * color.b, alpha: 0.5)
    renderer.draw(mode: .triangleFan, vertices: vertexData)
    renderer.disableBlend()
    
    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.draw(mode: .lineLoop, vertices: vertexData)
  }
  
  /// Draw a circle.
  func drawCircle(_ center: b2Vec2, _ radius: b2Float, _ color: b2Color) {
    let k_segments = 16
    let k_increment: b2Float = b2Float(2.0 * 3.14159265) / b2Float(k_segments)
    var theta: b2Float = 0.0
    vertexData.removeAll(keepingCapacity: true)
    for _ in 0 ..< k_segments {
      let v = center + radius * b2Vec2(cosf(theta), sinf(theta))
      vertexData.append(SIMD2<Float>(v.x, v.y))
      theta += k_increment
    }
    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.draw(mode: .lineLoop, vertices: vertexData)
  }
  
  /// Draw a solid circle.
  func drawSolidCircle(_ center: b2Vec2, _ radius: b2Float, _ axis: b2Vec2, _ color: b2Color) {
    let k_segments = 16
    let k_increment: b2Float = b2Float(2.0 * 3.14159265) / b2Float(k_segments)
    var theta: b2Float = 0.0
    vertexData.removeAll(keepingCapacity: true)
    for _ in 0 ..< k_segments {
      let v = center + radius * b2Vec2(cosf(theta), sinf(theta))
      vertexData.append(SIMD2<Float>(v.x, v.y))
      theta += k_increment
    }
    
    renderer.enableBlend()
    renderer.setColor(red: 0.5 * color.r, green: 0.5 * color.g, blue: 0.5 * color.b, alpha: 0.5)
    renderer.draw(mode: .triangleFan, vertices: vertexData)
    renderer.disableBlend()

    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.draw(mode: .lineLoop, vertices: vertexData)
    
    let p = center + radius * axis
    vertexData.removeAll(keepingCapacity: true)
    vertexData.append(SIMD2<Float>(center.x, center.y))
    vertexData.append(SIMD2<Float>(p.x, p.y))
    
    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.draw(mode: .lines, vertices: vertexData)
  }
  
  /// Draw a line segment.
  func drawSegment(_ p1: b2Vec2, _ p2: b2Vec2, _ color: b2Color) {
    vertexData.removeAll(keepingCapacity: true)
    vertexData.append(SIMD2<Float>(p1.x, p1.y))
    vertexData.append(SIMD2<Float>(p2.x, p2.y))
    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.draw(mode: .lines, vertices: vertexData)
  }
  
  /// Draw a transform. Choose your own length scale.
  /// @param xf a transform.
  func drawTransform(_ xf: b2Transform) {
    let p1 = xf.p
    var p2: b2Vec2
    let k_axisScale: b2Float = 0.4
    vertexData.removeAll(keepingCapacity: true)
    vertexData.append(SIMD2<Float>(p1.x, p1.y))
    p2 = p1 + k_axisScale * xf.q.xAxis
    vertexData.append(SIMD2<Float>(p2.x, p2.y))
    renderer.setColor(red: 1, green: 0, blue: 0, alpha: 1.0)
    renderer.draw(mode: .lines, vertices: vertexData)
    
    vertexData.removeAll(keepingCapacity: true)
    vertexData.append(SIMD2<Float>(p1.x, p1.y))
    p2 = p1 + k_axisScale * xf.q.yAxis
    vertexData.append(SIMD2<Float>(p2.x, p2.y))
    renderer.setColor(red: 0, green: 1, blue: 0, alpha: 1.0)
    renderer.draw(mode: .lines, vertices: vertexData)
  }
  
  func drawPoint(_ p: b2Vec2, _ size: b2Float, _ color: b2Color) {
    vertexData.removeAll(keepingCapacity: true)
    vertexData.append(SIMD2<Float>(p.x, p.y))
    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.setPointSize(size)
    renderer.draw(mode: .points, vertices: vertexData)
    renderer.setPointSize(0)
  }
  
  func drawAABB(_ aabb: b2AABB, _ color: b2Color) {
    vertexData.removeAll(keepingCapacity: true)
    vertexData.append(SIMD2<Float>(aabb.lowerBound.x, aabb.lowerBound.y))
    vertexData.append(SIMD2<Float>(aabb.upperBound.x, aabb.lowerBound.y))
    vertexData.append(SIMD2<Float>(aabb.upperBound.x, aabb.upperBound.y))
    vertexData.append(SIMD2<Float>(aabb.lowerBound.x, aabb.upperBound.y))
    renderer.setColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    renderer.draw(mode: .lineLoop, vertices: vertexData)
  }
  
  var m_drawFlags : UInt32 = 0
}
