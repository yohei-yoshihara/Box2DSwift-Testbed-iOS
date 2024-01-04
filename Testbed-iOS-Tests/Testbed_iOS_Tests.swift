// Copyright (c) Yohei Yoshihara. All rights reserved.

import XCTest
import Box2D
@testable import Testbed_iOS

final class Testbed_iOS_Tests: XCTestCase {
  
  override func setUpWithError() throws {
  }
  
  override func tearDownWithError() throws {
  }
  
  func test_convertScreenToWorld_001() throws {
    let p = convertScreenToWorld(CGPoint(x: 0, y: 50),
                                 size: CGSize(width: 100, height: 200),
                                 viewCenter: b2Vec2(0, 20.0))
    XCTAssertEqual(p.x, -25.0, accuracy: 1e-3)
    XCTAssertEqual(p.y, 45.0, accuracy: 1e-3)
  }
  
  func test_convertScreenToWorld_002() throws {
    let p = convertScreenToWorld(CGPoint(x: 100, y: 50),
                                 size: CGSize(width: 100, height: 200),
                                 viewCenter: b2Vec2(0, 20.0))
    XCTAssertEqual(p.x, 25.0, accuracy: 1e-3)
    XCTAssertEqual(p.y, 45.0, accuracy: 1e-3)
  }
  
  func test_convertScreenToWorld_003() throws {
    let p = convertScreenToWorld(CGPoint(x: 0, y: 150),
                                 size: CGSize(width: 100, height: 200),
                                 viewCenter: b2Vec2(0, 20.0))
    XCTAssertEqual(p.x, -25.0, accuracy: 1e-3)
    XCTAssertEqual(p.y, -5.0, accuracy: 1e-3)
  }
  
  func test_convertScreenToWorld_004() throws {
    let p = convertScreenToWorld(CGPoint(x: 100, y: 150),
                                 size: CGSize(width: 100, height: 200),
                                 viewCenter: b2Vec2(0, 20.0))
    XCTAssertEqual(p.x, 25.0, accuracy: 1e-3)
    XCTAssertEqual(p.y, -5.0, accuracy: 1e-3)
  }
  
  func test_convertScreenToWorld_005() throws {
    let p = convertScreenToWorld(CGPoint(x: 50, y: 100),
                                 size: CGSize(width: 100, height: 200),
                                 viewCenter: b2Vec2(0, 20.0))
    XCTAssertEqual(p.x, 0.0, accuracy: 1e-3)
    XCTAssertEqual(p.y, 20.0, accuracy: 1e-3)
  }
  
  func test_convertScreenToWorld_006() throws {
    let p = convertScreenToWorld(CGPoint(x: 50, y: 140),
                                 size: CGSize(width: 100, height: 200),
                                 viewCenter: b2Vec2(0, 20.0))
    XCTAssertEqual(p.x, 0.0, accuracy: 1e-3)
    XCTAssertEqual(p.y, 0.0, accuracy: 1e-3)
  }
  
  
  func test_calcViewBounds_001() throws {
    let (lower, upper) = calcViewBounds(viewSize: CGSize(width: 100, height: 200), 
                                        viewCenter: b2Vec2(0, 20.0),
                                        extents: b2Vec2(25, 25))
    XCTAssertEqual(lower.x, -25.0, accuracy: 1e-3)
    XCTAssertEqual(lower.y, -30.0, accuracy: 1e-3)
    XCTAssertEqual(upper.x, 25.0, accuracy: 1e-3)
    XCTAssertEqual(upper.y, 70.0, accuracy: 1e-3)
  }
  
  func test_calcViewBounds_002() throws {
    let (lower, upper) = calcViewBounds(viewSize: CGSize(width: 200, height: 100),
                                        viewCenter: b2Vec2(0, 20.0),
                                        extents: b2Vec2(25, 25))
    XCTAssertEqual(lower.x, -50.0, accuracy: 1e-3)
    XCTAssertEqual(lower.y, -5.0, accuracy: 1e-3)
    XCTAssertEqual(upper.x, 50.0, accuracy: 1e-3)
    XCTAssertEqual(upper.y, 45.0, accuracy: 1e-3)
  }
}
