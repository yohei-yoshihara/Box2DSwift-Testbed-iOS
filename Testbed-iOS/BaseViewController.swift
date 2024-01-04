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

import UIKit
import Box2D

class BaseViewController: UIViewController, SettingViewControllerDelegate, RenderViewDelegate {
  lazy var settings = Settings()
  lazy var debugDraw = RenderView(frame: .zero)
  lazy var infoView = InfoView(frame: .zero)
  lazy var settingsVC = SettingViewController()
  var stepCount = 0
  var contactListener: ContactListener!
  var world: b2World!
  var bombLauncher: BombLauncher!
  var mouseJoint: b2MouseJoint?
  var groundBody: b2Body!
  lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, 
                                                         action: #selector(onPan))
  lazy var tapGestureRecognizer = UITapGestureRecognizer(target: self, 
                                                         action: #selector(onTap))
  
  init() {
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    debugDraw.translatesAutoresizingMaskIntoConstraints = false
    debugDraw.setFlags(settings.debugDrawFlag)
    self.view.addSubview(debugDraw)
    NSLayoutConstraint.activate([
      debugDraw.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      debugDraw.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: debugDraw.bottomAnchor),
      view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: debugDraw.trailingAnchor),
    ])
    
    infoView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(infoView)
    NSLayoutConstraint.activate([
      infoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      infoView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: infoView.bottomAnchor),
      view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: infoView.trailingAnchor),
    ])
    
    let pauseButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.pause,
                                      target: self, action: #selector(onPause))
    let singleStepButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.play,
                                           target: self, action: #selector(onSingleStep))
    let flexibleButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
    self.toolbarItems = [
      flexibleButton, pauseButton,
      flexibleButton, singleStepButton,
      flexibleButton
    ]
    
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Settings", 
                                                             style: UIBarButtonItem.Style.plain,
                                                             target: self,
                                                             action: #selector(onSettings))
    
    debugDraw.addGestureRecognizer(panGestureRecognizer)
    debugDraw.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func addToolbarItems(_ additionalToolbarItems: [UIBarButtonItem]) {
    var toolbarItems = [UIBarButtonItem]()
    toolbarItems += self.toolbarItems!
    toolbarItems += additionalToolbarItems
    self.toolbarItems = toolbarItems
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // World
    let gravity = b2Vec2(0.0, -10.0)
    world = b2World(gravity: gravity)
    contactListener = ContactListener()
    world.setContactListener(contactListener)
    world.setDebugDraw(debugDraw)
    bombLauncher = BombLauncher(world: world, renderView: debugDraw, viewCenter: settings.viewCenter)
    infoView.world = world
    
    let bodyDef = b2BodyDef()
    groundBody = world.createBody(bodyDef)
    
    prepare()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    debugDraw.delegate = self
    debugDraw.backgroundColor = .blue
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    if checkBackButton(self) {
      debugDraw.delegate = nil
      world = nil
      bombLauncher = nil
      contactListener = nil
    }
  }
  
  func prepare() {
  }
  
  @objc func simulationLoop(renderView: RenderView) {
    updateCoordinate()
    debugDraw.preRender()
    
    bombLauncher.render()
    let timeStep = settings.calcTimeStep()
    settings.apply(world)
    contactListener.clearPoints()
    world.step(timeStep: timeStep, velocityIterations: settings.velocityIterations, positionIterations: settings.positionIterations)
    world.drawDebugData()
    
    if timeStep > 0.0 {
      stepCount += 1
    }
    
    infoView.updateProfile(stepCount)
    contactListener.drawContactPoints(settings, renderView: debugDraw)
    
    step()

    debugDraw.postRender()
  }
  
  func step() {
  }
  
  @objc func onPause(_ sender: UIBarButtonItem) {
    settings.pause = !settings.pause
  }
  
  @objc func onSingleStep(_ sender: UIBarButtonItem) {
    settings.pause = true
    settings.singleStep = true
  }
  
  @objc func onSettings(_ sender: UIBarButtonItem) {
    settingsVC.settings = settings
    settingsVC.settingViewControllerDelegate = self
    settingsVC.modalPresentationStyle = UIModalPresentationStyle.popover
    let popPC = settingsVC.popoverPresentationController
    popPC?.barButtonItem = sender
    popPC?.permittedArrowDirections = UIPopoverArrowDirection.any
    self.present(settingsVC, animated: true, completion: nil)
  }
  
  func didSettingsChanged(_ settings: Settings) {
    self.settings = settings
    infoView.enableProfile = settings.drawProfile
    infoView.enableStats = settings.drawStats
    debugDraw.metalKitView.preferredFramesPerSecond = Int(settings.hz)
    debugDraw.setFlags(settings.debugDrawFlag)
  }
  
  @objc func onPan(_ gr: UIPanGestureRecognizer) {
    let p = gr.location(in: debugDraw)
    let wp = convertScreenToWorld(p, size: debugDraw.bounds.size, viewCenter: settings.viewCenter)
    
    switch gr.state {
    case .began:
      let d = b2Vec2(0.001, 0.001)
      var aabb = b2AABB()
      aabb.lowerBound = wp - d
      aabb.upperBound = wp + d
      let callback = QueryCallback(point: wp)
      world.queryAABB(callback: callback, aabb: aabb)
      if callback.fixture != nil {
        let body = callback.fixture!.body
        let md = b2MouseJointDef()
        md.bodyA = groundBody
        md.bodyB = body
        md.target = wp
        md.maxForce = 1000.0 * body.mass
        mouseJoint = world.createJoint(md)
        body.setAwake(true)
      }
      else {
        bombLauncher.onPan(gr)
      }
      
    case .changed:
      if mouseJoint != nil {
        mouseJoint!.setTarget(wp)
      }
      else {
        bombLauncher.onPan(gr)
      }
      
    default:
      if mouseJoint != nil {
        world.destroyJoint(mouseJoint!)
        mouseJoint = nil
      }
      else {
        bombLauncher.onPan(gr)
      }
    }
  }
  
  @objc func onTap(_ gr: UITapGestureRecognizer) {
    bombLauncher.onTap(gr)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  func updateCoordinate() {
    let (lower, upper) = calcViewBounds(viewSize: debugDraw.bounds.size,
                                        viewCenter: settings.viewCenter,
                                        extents: Settings.extents)
    debugDraw.setOrtho2D(left: lower.x, right: upper.x, bottom: lower.y, top: upper.y)
  }
}

