import ARKit
import RealityKit

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var hideMeshButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var planeDetectionButton: UIButton!
    
    let westjetTeal: UIColor = UIColor( red: CGFloat(0/255.0), green: CGFloat(170/255.0), blue: CGFloat(165/255.0), alpha: CGFloat(1.0) )
    let coachingOverlay = ARCoachingOverlayView()
    var nodes: [SphereNode] = []
    
    // Cache for 3D text geometries representing the classification values.
    var modelsForClassification: [ARMeshClassification: ModelEntity] = [:]

    lazy var greyView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return blurEffectView
    }()
    
    lazy var statusLabel: UILabel = {
        let label = UILabel(frame: CGRect.zero)
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.title2)
        label.textAlignment = .center
        label.textColor = .systemOrange
        return label
    }()
    
    lazy var lengthLabel: UILabel = {
        let label = UILabel(frame: CGRect.zero)
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.title2)
        label.textAlignment = .center
        label.textColor = .red
        label.text = "Distance: "
        return label
    }()
    
    /// - Tag: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        setupCoachingOverlay()

        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Display a debug visualization of the mesh. Display the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification

        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)
        
        view.addSubview(greyView)
        view.addSubview(statusLabel)
        view.addSubview(lengthLabel)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        greyView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 120)
        statusLabel.frame = CGRect(x: 0, y: 46, width: view.bounds.width, height: 34)
        lengthLabel.frame = CGRect(x: 0, y: 80, width: view.bounds.width, height: 34)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    /// Places virtual-text of the classification at the touch-location's real-world intersection with a mesh.
    /// Note - because classification of the tapped-mesh is retrieved asynchronously, we visualize the intersection
    /// point immediately to give instant visual feedback of the tap.
    @objc
    func handleTap(_ sender: UITapGestureRecognizer) {
        //arView.scene.removeAnchor(<#T##anchor: HasAnchoring##HasAnchoring#>)
        if nodes.count > 1 {
            nodes = []
            arView.scene.anchors.removeAll()
        }
        // 1. Perform a ray cast against the mesh.
        // Note: Ray-cast option ".estimatedPlane" with alignment ".any" also takes the mesh into account.
        let tapLocation = sender.location(in: arView)  // 2D location on the screen
        if let result = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any).first {
            // ...
            // 2. Visualize the intersection point of the ray with the ›real-world surface.
            let pos = result.worldTransform // ARRaycastResult object
            let resultAnchor = AnchorEntity(world: pos)
            resultAnchor.addChild(sphere(radius: 0.01, color: .red))
            //arView.scene.addAnchor(resultAnchor, removeAfter: 3)
            arView.scene.addAnchor(resultAnchor)
            
            let position = SCNVector3.positionFrom(matrix: result.worldTransform)
            let sphere = SphereNode(position: position)

            let lastNode = nodes.last
            nodes.append(sphere)
            if lastNode != nil {
                let distance = lastNode!.position.distance(to: sphere.position)
                lengthLabel.text = String(format: "Distance: %.1f cm", distance * 100)
                lengthLabel.textColor = .red
            }
        }
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
        }
        arView.scene.anchors.removeAll()
    }
    
    @IBAction func toggleMeshButtonPressed(_ button: UIButton) {
        let isShowingMesh = arView.debugOptions.contains(.showSceneUnderstanding)
        if isShowingMesh {
            arView.debugOptions.remove(.showSceneUnderstanding)
            button.setTitle("Show", for: [])
        } else {
            arView.debugOptions.insert(.showSceneUnderstanding)
            button.setTitle("Hide", for: [])
        }
    }
    
    /// - Tag: TogglePlaneDetection
    @IBAction func togglePlaneDetectionButtonPressed(_ button: UIButton) {
        guard let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else {
            return
        }
        if configuration.planeDetection == [] {
            configuration.planeDetection = [.horizontal, .vertical]
            button.setTitle("Stop Detection", for: [])
        } else {
            configuration.planeDetection = []
            button.setTitle("Start Detection", for: [])
        }
        arView.session.run(configuration)
    }
    
    func nearbyFaceWithClassification(to location: SIMD3<Float>, completionBlock: @escaping (SIMD3<Float>?, ARMeshClassification, ARMeshAnchor?) -> Void) {
        guard let frame = arView.session.currentFrame else {
            completionBlock(nil, .none, nil)
            return
        }
    
        var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        
        // Sort the mesh anchors by distance to the given location and filter out
        // any anchors that are too far away (4 meters is a safe upper limit).
        let cutoffDistance: Float = 4.0
        meshAnchors.removeAll { distance($0.transform.position, location) > cutoffDistance }
        meshAnchors.sort { distance($0.transform.position, location) < distance($1.transform.position, location) }

        // Perform the search asynchronously in order not to stall rendering.
        DispatchQueue.global().async {
            for anchor in meshAnchors {
                for index in 0..<anchor.geometry.faces.count {
                    // Get the center of the face so that we can compare it to the given location.
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                    
                    // Convert the face's center to world coordinates.
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldPosition = (anchor.transform * centerLocalTransform).position
                     
                    // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                    let distanceToFace = distance(centerWorldPosition, location)
                    if distanceToFace <= 0.05 {
                        // Get the semantic classification of the face and finish the search.
                        let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                        completionBlock(centerWorldPosition, classification, anchor)
                        return
                    }
                }
            }

            // Let the completion block know that no result was found.
            completionBlock(nil, .none, nil)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
        
    func model(for classification: ARMeshClassification) -> ModelEntity {
        // Return cached model if available
        if let model = modelsForClassification[classification] {
            model.transform = .identity
            return model.clone(recursive: true)
        }
        
        // Generate 3D text for the classification
        let lineHeight: CGFloat = 0.05
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
        let textMesh = MeshResource.generateText(classification.description, extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMaterial = SimpleMaterial(color: classification.color, isMetallic: true)
        let model = ModelEntity(mesh: textMesh, materials: [textMaterial])
        // Move text geometry to the left so that its local origin is in the center
        model.position.x -= model.visualBounds(relativeTo: nil).extents.x / 2
        // Add model to cache
        modelsForClassification[classification] = model
        return model
    }
    
    func sphere(radius: Float, color: UIColor) -> ModelEntity {
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
        // Move sphere up by half its diameter so that it does not intersect with the mesh
        sphere.position.y = radius
        return sphere
    }
    
    func drawABox(minPoint: SIMD3<Float>, maxPoint: SIMD3<Float>, color: UIColor) {
             
        //Bottom
        self.drawALine(SIMD3<Float>(minPoint.x, minPoint.y, minPoint.z), SIMD3<Float>(maxPoint.x, minPoint.y, minPoint.z), color)
        self.drawALine(SIMD3<Float>(maxPoint.x, minPoint.y, minPoint.z), SIMD3<Float>(maxPoint.x, maxPoint.y, minPoint.z), color)
        self.drawALine(SIMD3<Float>(maxPoint.x, maxPoint.y, minPoint.z), SIMD3<Float>(minPoint.x, maxPoint.y, minPoint.z), color)
        self.drawALine(SIMD3<Float>(minPoint.x, maxPoint.y, minPoint.z), SIMD3<Float>(minPoint.x, minPoint.y, minPoint.z), color)

        //Top
        self.drawALine(SIMD3<Float>(minPoint.x, minPoint.y, maxPoint.z), SIMD3<Float>(maxPoint.x, minPoint.y, maxPoint.z), color)
        self.drawALine(SIMD3<Float>(maxPoint.x, minPoint.y, maxPoint.z), SIMD3<Float>(maxPoint.x, maxPoint.y, maxPoint.z), color)
        self.drawALine(SIMD3<Float>(maxPoint.x, maxPoint.y, maxPoint.z), SIMD3<Float>(minPoint.x, maxPoint.y, maxPoint.z), color)
        self.drawALine(SIMD3<Float>(minPoint.x, maxPoint.y, maxPoint.z), SIMD3<Float>(minPoint.x, minPoint.y, maxPoint.z), color)

        //Sides
        self.drawALine(SIMD3<Float>(minPoint.x, minPoint.y, minPoint.z), SIMD3<Float>(minPoint.x, minPoint.y, maxPoint.z), color)
        self.drawALine(SIMD3<Float>(maxPoint.x, minPoint.y, minPoint.z), SIMD3<Float>(maxPoint.x, minPoint.y, maxPoint.z), color)
        self.drawALine(SIMD3<Float>(maxPoint.x, maxPoint.y, minPoint.z), SIMD3<Float>(maxPoint.x, maxPoint.y, maxPoint.z), color)
        self.drawALine(SIMD3<Float>(minPoint.x, maxPoint.y, minPoint.z), SIMD3<Float>(minPoint.x, maxPoint.y, maxPoint.z), color)

    }
     
    func drawALine(_ position1: SIMD3<Float>, _ position2: SIMD3<Float>, _ color: UIColor) {
        //Put line code here or replace all calls to this with the relevant function call

        let midPosition = SIMD3<Float>(x:(position1.x + position2.x) / 2,
                            y:(position1.y + position2.y) / 2,
                            z:(position1.z + position2.z) / 2)
        let anchor = AnchorEntity()
        anchor.position = midPosition

        anchor.look(at: position1, from: midPosition, relativeTo: nil)


        let meters = simd_distance(position1, position2)

        let lineMaterial = SimpleMaterial.init(color: color,
                                       roughness: 1,
                                       isMetallic: false)

        let bottomLineMesh = MeshResource.generateBox(width:0.015,
                                              height: 0.015,
                                              depth: meters)

        let bottomLineEntity = ModelEntity(mesh: bottomLineMesh,
                                   materials: [lineMaterial])

        bottomLineEntity.position = .init(0, 0, 0)
        anchor.addChild(bottomLineEntity)

        self.arView.scene.addAnchor(anchor)
    }
    
    // MARK: ARSCNViewDelegate
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        var status = "Camera Loading"
        switch camera.trackingState {
        case ARCamera.TrackingState.notAvailable:
            status = "Camera Not available"
        case ARCamera.TrackingState.limited(_):
            status = "Camera limited"
        case ARCamera.TrackingState.normal:
            status = "Camera Ready"
        }
        statusLabel.text = status
    }
}

extension SCNGeometry {
    convenience init(arGeometry: ARMeshGeometry) {
       let verticesSource = SCNGeometrySource(arGeometry.vertices, semantic: .vertex)
       let normalsSource = SCNGeometrySource(arGeometry.normals, semantic: .normal)
       let faces = SCNGeometryElement(arGeometry.faces)
       self.init(sources: [verticesSource, normalsSource], elements: [faces])
    }
}
extension SCNGeometrySource {
    convenience init(_ source: ARGeometrySource, semantic: Semantic) {
        self.init(buffer: source.buffer, vertexFormat: source.format, semantic: semantic, vertexCount: source.count, dataOffset: source.offset, dataStride: source.stride)
    }
}
extension SCNGeometryElement {
    convenience init(_ source: ARGeometryElement) {
       let pointer = source.buffer.contents()
       let byteCount = source.count * source.indexCountPerPrimitive * source.bytesPerIndex
       let data = Data(bytesNoCopy: pointer, count: byteCount, deallocator: .none)
       self.init(data: data, primitiveType: .of(source.primitiveType), primitiveCount: source.count, bytesPerIndex: source.bytesPerIndex)
    }
}
extension SCNGeometryPrimitiveType {
    static  func  of(_ type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
       switch type {
       case .line:
            return .line
       case .triangle:
            return .triangles
       @unknown default:
            return .line
       }
    }
}

extension SCNGeometry {

    class func cylinderLine(from: SCNVector3,
                              to: SCNVector3,
                        segments: Int) -> SCNNode {

        let x1 = from.x
        let x2 = to.x

        let y1 = from.y
        let y2 = to.y

        let z1 = from.z
        let z2 = to.z

        let distance =  sqrtf( (x2-x1) * (x2-x1) +
                               (y2-y1) * (y2-y1) +
                               (z2-z1) * (z2-z1) )

        let cylinder = SCNCylinder(radius: 0.005,
                                   height: CGFloat(distance))

        cylinder.radialSegmentCount = segments

        cylinder.firstMaterial?.diffuse.contents = UIColor.green

        let lineNode = SCNNode(geometry: cylinder)

        lineNode.position = SCNVector3(x: (from.x + to.x) / 2,
                                       y: (from.y + to.y) / 2,
                                       z: (from.z + to.z) / 2)

        lineNode.eulerAngles = SCNVector3(Float.pi / 2,
                                          acos((to.z-from.z)/distance),
                                          atan2((to.y-from.y),(to.x-from.x)))

        return lineNode
    }
}

extension ARMeshGeometry {
    func vertex2(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
}

extension SCNVector3 {
    func distance(to destination: SCNVector3) -> CGFloat {
        let dx = destination.x - x
        let dy = destination.y - y
        let dz = destination.z - z
        return CGFloat(sqrt(dx*dx + dy*dy + dz*dz))
    }
    
    static func positionFrom(matrix: matrix_float4x4) -> SCNVector3 {
        let column = matrix.columns.3
        return SCNVector3(column.x, column.y, column.z)
    }
}
