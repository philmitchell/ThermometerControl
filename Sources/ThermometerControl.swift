//
//  ThermometerControl.swift
//
// Copyright (c) 2018 Phil Mitchell

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

@IBDesignable
class ThermometerControl: UIControl {

    struct Defaults {
        static let lineWidth: CGFloat = 3.0
        static let gradientStart = UIColor(red:0.51, green:0.92, blue:0.95, alpha:1.0)
        static let gradientEnd = UIColor(red:0.39, green:0.64, blue:1.00, alpha:1.0)
        static let outlineColor: UIColor = Defaults.gradientEnd
        static let baseUnit: TemperatureUnit = .celsius
        static let maximumDegrees: Double = 110
        static let minimumDegrees: Double = -30
        static let degrees: Double = 27 // current reading
        static let hashMarkColor = Defaults.gradientEnd
        static let sliderColor = UIColor.red
        static let sliderSize = CGSize(width: 120, height: 40)
        static let isContinuous = false
        static let showsWaypoints = false
        static let fontName = "DINCondensed-Bold"
    }

    /// Width of the thermometer outline
    var lineWidth: CGFloat = Defaults.lineWidth

    /// Color of the thermometer outline
    var outlineColor = Defaults.outlineColor

    /// Color of the sliding handle
    var sliderColor = Defaults.sliderColor

    /// Size of the sliding handle
    var sliderSize: CGSize = Defaults.sliderSize

    /// Start of color gradient for the thermometer bulb
    var gradientStart = Defaults.gradientStart

    /// End of color gradient for the thermometer bulb
    var gradientEnd = Defaults.gradientEnd

    /// Color of hash marks on thermometer
    var hashMarkColor = Defaults.hashMarkColor

    /// Unit of measurement (.celsius, .fahrenheit, .kelvin)
    var baseUnit: TemperatureUnit = Defaults.baseUnit

    /// Maximum temperature on thermometer
    var maximumDegrees: Double = Defaults.maximumDegrees

    /// Minimum temperature on thermometer
    var minimumDegrees: Double = Defaults.minimumDegrees

    /// Current temperature reading
    var degrees: Double = Defaults.degrees

    /// If true, delegate is called continuously during slider motion; if false, only when released.
    var isContinuous = Defaults.isContinuous

    /// Whether or not waypoints such as freezing and boiling are indicated.
    var showsWaypoints = Defaults.showsWaypoints {
        didSet {
            waypointLayer.isHidden = !showsWaypoints
        }
    }

    /// Font used for temperature scale and waypoints
    var fontName = Defaults.fontName

    private let bulbGradient = CAGradientLayer()

    private let sliderLayer = CAShapeLayer()

    private let waypointLayer = CALayer()

    // Initial touch point
    private var touchStartPoint: CGPoint? = nil

    // Location of center when touch starts
    private var centerStartPoint: CGPoint? = nil

    // The rect of the thermometer "stalk" defines our temperature scale
    private var stalkRect: CGRect = CGRect.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        _setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _setup()
    }

    private func _setup() {
        isOpaque = false
        backgroundColor = UIColor.clear
    }// _setup

    // If a gesture recognizer's touch falls within handle, ignore it
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: self)
        if let _ = sliderLayer.hitTest(point) {
            return false
        }
        return true
    }

    override func draw(_ rect: CGRect) {
        let height = rect.height
        let topPercent: CGFloat = 0.03 // rounded top
        let stalkPercent: CGFloat = 0.90 // stalk
        let stalkWidth: CGFloat = 20.0
        let bulbPercent: CGFloat = 0.07 // bottom bulb
        let bulbWidth: CGFloat = 30.0

        outlineColor.setStroke()
        UIColor.white.setFill()

        let path = UIBezierPath()

        // ROUNDED TOP
        let topHeight = topPercent * height
        let topInset = topHeight / 2
        let topX = rect.midX - (stalkWidth / 2.0)
        let topY = rect.minY + topInset
        let topRect = CGRect(x: topX, y: topY, width: stalkWidth, height: topHeight)
        let top = UIBezierPath(ovalIn: topRect)
        path.append(top)

        // STALK
        let stalkX = topX
        let stalkY = topRect.maxY - topInset
        stalkRect = CGRect(x: stalkX, y: stalkY, width: stalkWidth, height: stalkPercent * height)
        let stalk = UIBezierPath(rect: stalkRect)
        path.append(stalk)

        // STALK HASH MARKS AND WAYPOINTS
        addHashMarks(in: stalkRect)
        addWaypoints(in: stalkRect)            
        waypointLayer.isHidden = !showsWaypoints

        // BULB
        let bulbHeight = bulbPercent * height
        let bulbInset = bulbHeight / 3
        let bulbX = rect.midX - (bulbWidth / 2.0)
        let bulbY = stalkRect.maxY - bulbInset
        let bulbRect = CGRect(x: bulbX, y: bulbY, width: bulbWidth, height: bulbHeight)
        let bulb = UIBezierPath(ovalIn: bulbRect)
        path.append(bulb)

        // BULB MASK (for gradient)
        let mask = CAShapeLayer()
        let maskRect = CGRect(x: 0, y: 0, width: bulbWidth, height: bulbHeight)
        let maskPath = UIBezierPath(ovalIn: maskRect)
        mask.frame = maskRect
        mask.path = maskPath.cgPath

        // BULB GRADIENT
        bulbGradient.colors = [gradientStart.cgColor, gradientEnd.cgColor]
        bulbGradient.frame = bulbRect
        bulbGradient.mask = mask
        layer.addSublayer(bulbGradient)

        // SLIDER LAYER
        addSliderLayer()

        // PATH
        path.lineWidth = lineWidth
        path.stroke()
        path.fill()

    }// draw

    override func layoutSubviews() {
        super.layoutSubviews()
        let sliderX = stalkRect.minX + sliderSize.width / 2
        let sliderY = stalkRect.minY + heightFor(temperature: Temperature(degrees: degrees, unit: baseUnit))
        sliderLayer.position = CGPoint(x: sliderX, y: sliderY) // anchorPoint is at center
        sliderLayer.bounds = CGRect(x: 0, y: 0, width: sliderSize.width, height: sliderSize.height)
    }

    // NOTE: Set path but don't layout slider layer here, bc it will change with touches; 
    private func addSliderLayer() {
        layer.addSublayer(sliderLayer)
        sliderLayer.zPosition = 5.0
        sliderLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        sliderLayer.fillColor = sliderColor.cgColor
        let inset: CGFloat = 10.0
        let sliderRect = CGRect(x: 0, y: 0, width: sliderSize.width, height: sliderSize.height)
        let sliderPath = UIBezierPath()
        // HANDLE
        let handleRect = sliderRect.rightHalf.insetBy(dx: 0, dy: inset)
        let sliderHandlePath = UIBezierPath(roundedRect: handleRect, byRoundingCorners: [.topRight, .bottomRight], cornerRadii: CGSize(width: 6.0, height: 6.0))
        sliderPath.append(sliderHandlePath)
        // POINTER
        // Each control point lines up horizontally with its point; the larger the horizontal distance, the greater the curve
        let pointerPath = UIBezierPath()
        pointerPath.move(to: sliderRect.upperMid.offsetBy(dx: 0, dy: inset))
        pointerPath.addCurve(to: sliderRect.leftMid,
                                  controlPoint1: sliderRect.upperMid.offsetBy(dx: -sliderRect.width/4, dy: inset),
                                  controlPoint2: sliderRect.leftMid.offsetBy(dx: sliderRect.width/2, dy: 0))
        pointerPath.addCurve(to: sliderRect.lowerMid.offsetBy(dx: 0, dy: -inset),
                                  controlPoint1: sliderRect.leftMid.offsetBy(dx: sliderRect.width/2, dy: 0),
                                  controlPoint2: sliderRect.lowerMid.offsetBy(dx: -sliderRect.width/4, dy: -inset))
        pointerPath.addLine(to: sliderRect.upperMid.offsetBy(dx: 0, dy: inset))
        sliderPath.append(pointerPath)

        sliderLayer.path = sliderPath.cgPath

    }//addSliderLayer

    private func addHashMarks(in rect: CGRect) {
        let hashLayer = CAShapeLayer()
        hashLayer.strokeColor = hashMarkColor.cgColor
        hashLayer.frame = rect
        layer.addSublayer(hashLayer)
        let hashTotal = CGFloat(maximumDegrees - minimumDegrees)
        let hashMarkPath = UIBezierPath()        
        let endPoint = rect.lowerLeft
        var y: CGFloat = 0
        let startX: CGFloat = 0
        let shortX = 0.2 * rect.width
        let midX = 0.3 * rect.width
        let longX = 0.75 * rect.width
        var hashCount = 0
        while y < endPoint.y {
            hashMarkPath.move(to: CGPoint(x: startX, y: y))
            let x = hashCount % 10 == 0 ? longX : hashCount % 5 == 0 ? midX : shortX
            let degrees = degreesFor(hashCount, base: maximumDegrees)
            if hashCount % 10 == 0 {
                let textLayer = createTextLayer(parent: hashLayer)
                textLayer.frame = CGRect(x: -25, y: y-5, width: 20, height: 20)
                textLayer.string = String(describing: degrees)
            }
            hashMarkPath.addLine(to: CGPoint(x: x, y: y))
            hashCount += 1
            // NOTE: To avoid error accumulation, don't calculate y cumulatively; each calculation is relative to same start point
            y = rect.height * (CGFloat(hashCount) / hashTotal)
        }
        hashLayer.path = hashMarkPath.cgPath
    }//addHashMarks

    private func createTextLayer(parent: CALayer) -> CATextLayer {
        let layer = CATextLayer()
        layer.contentsScale = UIScreen.main.scale
        layer.font = NSString(string: fontName)
        layer.fontSize = baseUnit == .celsius ? 15.0 : 11.0
        layer.foregroundColor = UIColor.black.cgColor
        parent.addSublayer(layer)
        return layer
    }

    private func degreesFor(_ count: Int, base: Double) -> Int {
        return -1 * (count - Int(base))
    }

    private func heightFor(temperature: Temperature) -> CGFloat {
        let degrees: Double = temperature.inUnits(baseUnit)
        if degrees > maximumDegrees || degrees < minimumDegrees {
            return 0
        }
        let span = maximumDegrees - minimumDegrees
        return CGFloat((maximumDegrees - degrees) / span) * stalkRect.height
    }

    // Height is measured from top of stalkRect
    private func temperatureFor(height: CGFloat) -> Temperature {
        let span = maximumDegrees - minimumDegrees
        let deltaDegrees = Double(height / stalkRect.height) * span
        return Temperature(degrees: Double(maximumDegrees - deltaDegrees), unit: baseUnit)
    }

    private func addWaypoints(in rect: CGRect) {
        waypointLayer.frame = rect
        waypointLayer.zPosition = 10.0
        layer.addSublayer(waypointLayer)
        for waypoint in [TemperatureWaypoint.freezing, .boiling, .bodyTemperature] {
            let temperature: Temperature = waypoint.temperature.inUnits(baseUnit)
            if temperature.degrees >= minimumDegrees && temperature.degrees <= maximumDegrees {
                let textLayer = createTextLayer(parent: waypointLayer)
                textLayer.isWrapped = true
                textLayer.fontSize = 13.0
                let y = heightFor(temperature: temperature)
                let width = (layer.bounds.width - stalkRect.width) / 2 - 20
                textLayer.frame = CGRect(x: rect.width + 5, y: y-5, width: width, height: 50)
                textLayer.string = "\(waypoint.rawValue) - \(temperature)"
            }
        }
    }

    // MARK: - Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let startPoint = touch.location(in: self)
            // Ignore touches that aren't on the slider
            if let _ = sliderLayer.hitTest(startPoint) {
                touchStartPoint = startPoint
                centerStartPoint = sliderLayer.position
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let newPoint = touch.location(in: self)
            if let startPoint = touchStartPoint, let centerStart = centerStartPoint {
                let newCenter = centerStart.offsetBy(dx: 0, dy: newPoint.y - startPoint.y)
                // Don't let slider go beyond ends of thermometer stalk
                if newCenter.y >= stalkRect.minY && newCenter.y <= stalkRect.maxY {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    sliderLayer.position = newCenter
                    CATransaction.commit()
                    let height = sliderLayer.position.y - stalkRect.minY
                    let temperature = temperatureFor(height: height)
                    degrees = temperature.degrees
                    if isContinuous {
                        sendActions(for: .valueChanged)                    
                    }
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // If touch has not moved (eg., tap on handle), ignore it
        if let touch = touches.first {
            let endPoint = touch.location(in: self)
            if let startPoint = touchStartPoint, startPoint != endPoint {
                sendActions(for: .valueChanged)
            }
            resetTouches()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetTouches()
    }

    private func resetTouches() {
        touchStartPoint = nil
        centerStartPoint = nil
    }

}//TemperatureControl
