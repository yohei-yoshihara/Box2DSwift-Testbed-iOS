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

import Foundation
import QuartzCore
import Metal
import MetalKit
import simd

let VertexAttributeLocation: GLuint = 0

let maxNumberOfVertices = 65536

let MaxFramesInFlight = 3

struct Vertex {
  var pos: SIMD2<Float>
  var color: SIMD4<Float>
  
  init(x: Float, y: Float, r: Float, g: Float, b: Float, a: Float) {
    self.pos = SIMD2<Float>(x, y)
    self.color = SIMD4<Float>(r, g, b, a)
  }
  
  init(pos: SIMD2<Float>, color: SIMD4<Float>) {
    self.pos = pos
    self.color = color
  }
}

enum DrawMode {
  case lineLoop
  case triangleFan
  case lines
  case points
}

enum DrawCommand {
  case lineLoop(start: Int, count: Int)
  case triangleFan(start: Int, count: Int)
  case lines(start: Int, count: Int)
  case points(start: Int, count: Int)
}

class Renderer : NSObject {
  class WorkSet {
    var commands = [DrawCommand]()
    var numberOfVertices = 0
    var vertexBuffer: MTLBuffer
    var uniforms = Uniforms()
    var color = SIMD4<Float>(0, 0, 0, 0)
    var pointSize: Float = 0.0
    
    init(vertexBuffer: MTLBuffer) {
      self.vertexBuffer = vertexBuffer
    }
    
    func clear() {
      commands.removeAll(keepingCapacity: true)
      numberOfVertices = 0
    }
  }
  
  let inFlightSemaphore  = DispatchSemaphore(value: MaxFramesInFlight)
  var workSets = [WorkSet]()
  var currentBuffer = 0
  
  var viewportSize = vector_uint2(0, 0)
  
  var device: MTLDevice
  var pipelineState: MTLRenderPipelineState
  var commandQueue: MTLCommandQueue
  
  
  init(metalKitView: MTKView) {
    guard let device = metalKitView.device else {
      fatalError("device is nil")
    }
    self.device = device
    
    let defaultLibrary = device.makeDefaultLibrary()!
    let vertexFunction = defaultLibrary.makeFunction(name: "vertexShader")
    let fragmentFunction = defaultLibrary.makeFunction(name: "fragmentShader")
    
    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[1].format = .float4
    vertexDescriptor.attributes[1].bufferIndex = 0
    vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
    vertexDescriptor.layouts[0].stepFunction = .perVertex
    
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.label = "Pipeline"
    pipelineStateDescriptor.vertexFunction = vertexFunction
    pipelineStateDescriptor.fragmentFunction = fragmentFunction
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    
    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineStateDescriptor) else {
      fatalError("failed to create pipeline state")
    }
    self.pipelineState = pipelineState
    
    guard let commandQueue = device.makeCommandQueue() else {
      fatalError("failed to make a command queue")
    }
    self.commandQueue = commandQueue
    
    for i in 0 ..< MaxFramesInFlight {
      let size = MemoryLayout<Vertex>.stride * maxNumberOfVertices
      guard let vertexBuffer = device.makeBuffer(length: size,
                                                 options: [.storageModeShared]) else {
        fatalError("failed to make a vertex buffer")
      }
      vertexBuffer.label = "Vertex Buffer \(i)"
      vertexBuffer.contents().withMemoryRebound(to: Vertex.self, capacity: maxNumberOfVertices) { pointer in
        pointer[0].pos = SIMD2<Float>(0, 0)
        pointer[0].color = SIMD4<Float>(0, 0, 0, 0)
      }
      workSets.append(WorkSet(vertexBuffer: vertexBuffer))
    }
    
  }
  
  deinit {
  }
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    viewportSize.x = UInt32(size.width)
    viewportSize.y = UInt32(size.height)
  }
  
  func preRender(in view: MTKView) {
    inFlightSemaphore.wait()
    currentBuffer = (currentBuffer + 1) % MaxFramesInFlight
    
    workSets[currentBuffer].clear()
  }
  
  func draw(mode: DrawMode, vertices: [SIMD2<Float>]) {
    if vertices.isEmpty { return }
    
    let color = workSets[currentBuffer].color
    
    switch mode {
    case .lineLoop:
      // Metal does not support line loop, emulate with line strip
      var subvertices = [Vertex]()
      for vertex in vertices {
        subvertices.append(Vertex(pos: vertex, color: workSets[currentBuffer].color))
      }
      subvertices.append(Vertex(pos: vertices[0], color: workSets[currentBuffer].color))
      
      let start = workSets[currentBuffer].numberOfVertices
      let count = subvertices.count
      
      workSets[currentBuffer].vertexBuffer.contents().withMemoryRebound(to: Vertex.self, capacity: maxNumberOfVertices) { pointer in
        for i in 0 ..< subvertices.count {
          pointer[start + i] = subvertices[i]
        }
      }
      
      let command = DrawCommand.lineLoop(start: start, count: count)
      workSets[currentBuffer].commands.append(command)
      
      workSets[currentBuffer].numberOfVertices += count
      break
      
    case .triangleFan:
      guard vertices.count > 2 else {
        fatalError("to draw triangle fan, vertex data must have at least 3 vertices")
      }
      // Metal does not support triangle fan, emulate with triangles
      var subvertices = [Vertex]()
      subvertices.reserveCapacity((vertices.count - 2) * 3)
      let v0 = vertices[0]
      var v1 = vertices[1]
      for i in 2 ..< vertices.count {
        subvertices.append(Vertex(pos: v0, color: color))
        subvertices.append(Vertex(pos: v1, color: color))
        subvertices.append(Vertex(pos: vertices[i], color: color))
        v1 = vertices[i]
      }
      let start = workSets[currentBuffer].numberOfVertices
      let count = subvertices.count
      
      workSets[currentBuffer].vertexBuffer.contents().withMemoryRebound(to: Vertex.self, capacity: maxNumberOfVertices) { pointer in
        for i in 0 ..< subvertices.count {
          pointer[start + i] = subvertices[i]
        }
      }
      
      let command = DrawCommand.triangleFan(start: start, count: count)
      workSets[currentBuffer].commands.append(command)
      
      workSets[currentBuffer].numberOfVertices += count
      break
      
    case .lines:
      var subvertices = [Vertex]()
      subvertices.reserveCapacity(vertices.count)
      for vertex in vertices {
        subvertices.append(Vertex(pos: vertex, color: color))
      }
      let start = workSets[currentBuffer].numberOfVertices
      let count = subvertices.count
      
      workSets[currentBuffer].vertexBuffer.contents().withMemoryRebound(to: Vertex.self, capacity: maxNumberOfVertices) { pointer in
        for i in 0 ..< subvertices.count {
          pointer[start + i] = subvertices[i]
        }
      }
      
      let command = DrawCommand.lines(start: start, count: count)
      workSets[currentBuffer].commands.append(command)
      
      workSets[currentBuffer].numberOfVertices += count
      break
      
    case .points:
      guard workSets[currentBuffer].pointSize > 0 else {
        fatalError("pointSize must be more than 0 to draw points")
      }
      let sx = workSets[currentBuffer].uniforms.mvp[0].x
      let sy = workSets[currentBuffer].uniforms.mvp[1].y
      let halfX: Float = (workSets[currentBuffer].pointSize / Float(2.0)) * sx
      let halfY: Float = (workSets[currentBuffer].pointSize / Float(2.0)) * sy

      var subvertices = [Vertex]()
      for vertex in vertices {
        let v0 = SIMD2<Float>(vertex.x - halfX, vertex.y - halfY)
        let v1 = SIMD2<Float>(vertex.x + halfX, vertex.y - halfY)
        let v2 = SIMD2<Float>(vertex.x - halfX, vertex.y + halfY)
        let v3 = SIMD2<Float>(vertex.x + halfX, vertex.y + halfY)
        subvertices.append(Vertex(pos: v0, color: color))
        subvertices.append(Vertex(pos: v1, color: color))
        subvertices.append(Vertex(pos: v2, color: color))
        
        subvertices.append(Vertex(pos: v1, color: color))
        subvertices.append(Vertex(pos: v2, color: color))
        subvertices.append(Vertex(pos: v3, color: color))
      }
      let start = workSets[currentBuffer].numberOfVertices
      let count = subvertices.count
      
      workSets[currentBuffer].vertexBuffer.contents().withMemoryRebound(to: Vertex.self, capacity: maxNumberOfVertices) { pointer in
        for i in 0 ..< subvertices.count {
          pointer[start + i] = subvertices[i]
        }
      }
      
      let command = DrawCommand.points(start: start, count: count)
      workSets[currentBuffer].commands.append(command)
      
      workSets[currentBuffer].numberOfVertices += count
      break
    }
  }
  
  func postRender(in view: MTKView) {
    let commandBuffer = commandQueue.makeCommandBuffer()!
    commandBuffer.label = "Command"
    
    let renderPassDescriptor = view.currentRenderPassDescriptor!
    
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    renderEncoder.label = "RenderEncoder"
    renderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: Double(viewportSize.x), height: Double(viewportSize.y), znear: -1.0, zfar: 1.0))
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setVertexBuffer(workSets[currentBuffer].vertexBuffer,
                                  offset: 0,
                                  index: Int(VertexBuffer.rawValue))
    
    renderEncoder.setVertexBytes(&workSets[currentBuffer].uniforms,
                                 length: MemoryLayout<Uniforms>.size,
                                 index: Int(UniformsBuffer.rawValue))
    
    for command in workSets[currentBuffer].commands {
      switch command {
      case .lineLoop(start: let start, count: let count):
        renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: start, vertexCount: count)
      case .triangleFan(start: let start, count: let count):
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: start, vertexCount: count)
      case .lines(start: let start, count: let count):
        renderEncoder.drawPrimitives(type: .line, vertexStart: start, vertexCount: count)
      case .points(start: let start, count: let count):
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: start, vertexCount: count)
      }
    }
    
    renderEncoder.endEncoding()
    
    commandBuffer.present(view.currentDrawable!)
    
    commandBuffer.addCompletedHandler { commandBuffer in
      self.inFlightSemaphore.signal()
    }
    
    commandBuffer.commit()
  }
  
  func setOrtho2D(left: Float, right: Float, bottom: Float, top: Float) {
    //    let zNear: GLfloat = -1.0
    //    let zFar: GLfloat = 1.0
    //    let inv_z: GLfloat = 1.0 / (zFar - zNear)
    let inv_y: Float = 1.0 / (top - bottom)
    let inv_x: Float = 1.0 / (right - left)
    //    var mat33: [GLfloat] = [
    //      2.0 * inv_x,
    //      0.0,
    //      0.0,
    //
    //      0.0,
    //      2.0 * inv_y,
    //      0.0,
    //
    //      -(right + left) * inv_x,
    //      -(top + bottom) * inv_y,
    //      1.0
    //    ]
    let mat33: simd_float3x3 = simd_float3x3([
      SIMD3<Float>(
        Float(2.0 * inv_x),
        0.0,
        0.0
      ),
      SIMD3<Float>(
        0.0,
        2.0 * inv_y,
        0.0
      ),
      SIMD3<Float>(
        -(right + left) * inv_x,
         -(top + bottom) * inv_y,
         1.0
      )])
    
    workSets[currentBuffer].uniforms.mvp = mat33
  }
  
  func setColor(red: Float, green: Float, blue: Float, alpha: Float) {
    workSets[currentBuffer].color = SIMD4<Float>(red, green, blue, alpha)
  }
  
  func setPointSize(_ pointSize: Float) {
    workSets[currentBuffer].pointSize = pointSize
  }
  
  func enableBlend() {
    //    glEnable(GLenum(GL_BLEND))
    //    glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
  }
  
  func disableBlend() {
    //    glDisable(GLenum(GL_BLEND))
  }
  
}


