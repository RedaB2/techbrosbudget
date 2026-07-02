//
//  MoneyRainView.swift
//  techbrosbudget
//
//  Created by Reda Boutayeb on 7/1/26.
//

import SwiftUI
import Combine
import CoreMotion
import UIKit

/// A single falling dollar bill in the money-rain easter egg.
private struct DollarBill: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double
    var angularVelocity: Double
    var scale: CGFloat
    var opacity: Double = 1
    var hasBounced = false
    var restTime: Double = 0
    var age: Double = 0
}

/// Drives the dollar-bill physics with a display link and the device's
/// real gravity vector, so bills fall toward whichever way the phone tilts.
@MainActor
final class MoneyRainSimulator: ObservableObject {
    @Published fileprivate private(set) var bills: [DollarBill] = []

    private var displayLink: CADisplayLink?
    private let motionManager = CMMotionManager()
    private var bounds: CGSize = .zero
    private var lastTimestamp: CFTimeInterval?

    private static let maxBills = 90
    private static let gravityStrength: Double = 2400
    private static let emojiSize: CGFloat = 34

    func updateBounds(_ size: CGSize) {
        bounds = size
    }

    /// Spawns a burst of bills from `point` (in the overlay's coordinate space).
    /// Safe to call repeatedly while a previous burst is still falling.
    func burst(from point: CGPoint) {
        let count = Int.random(in: 6...9)
        for _ in 0..<count {
            bills.append(
                DollarBill(
                    position: CGPoint(
                        x: point.x + .random(in: -14...14),
                        y: point.y + .random(in: -10...10)
                    ),
                    velocity: CGVector(
                        dx: .random(in: -170...260),
                        dy: .random(in: -560...(-280))
                    ),
                    rotation: .random(in: -0.5...0.5),
                    angularVelocity: .random(in: -4...4),
                    scale: .random(in: 0.8...1.25)
                )
            )
        }

        if bills.count > Self.maxBills {
            bills.removeFirst(bills.count - Self.maxBills)
        }

        startIfNeeded()
    }

    private func startIfNeeded() {
        guard displayLink == nil else { return }

        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1 / 30
            motionManager.startDeviceMotionUpdates()
        }

        lastTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
        motionManager.stopDeviceMotionUpdates()
        lastTimestamp = nil
    }

    /// The device gravity vector remapped into screen coordinates (+y is down),
    /// normalized so straight down has magnitude 1.
    private var screenGravity: CGVector {
        guard let g = motionManager.deviceMotion?.gravity else {
            return CGVector(dx: 0, dy: 1)
        }

        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .effectiveGeometry.interfaceOrientation ?? .portrait

        var vector: CGVector
        switch orientation {
        case .portraitUpsideDown:
            vector = CGVector(dx: -g.x, dy: g.y)
        case .landscapeLeft:
            vector = CGVector(dx: g.y, dy: g.x)
        case .landscapeRight:
            vector = CGVector(dx: -g.y, dy: -g.x)
        default:
            vector = CGVector(dx: g.x, dy: -g.y)
        }

        // Lying flat leaves almost no in-plane gravity; blend toward straight
        // down so bills always settle instead of drifting forever.
        let magnitude = (vector.dx * vector.dx + vector.dy * vector.dy).squareRoot()
        if magnitude < 0.3 {
            vector.dy += 0.3 - magnitude
        }

        return vector
    }

    @objc private func step(_ link: CADisplayLink) {
        guard bounds != .zero else { return }

        let dt = min(lastTimestamp.map { link.timestamp - $0 } ?? 1 / 60, 1 / 30)
        lastTimestamp = link.timestamp

        let gravity = screenGravity
        let floorY = bounds.height - Self.emojiSize / 2 - 4
        let sideMargin = Self.emojiSize / 2

        for index in bills.indices {
            var bill = bills[index]
            bill.age += dt

            bill.velocity.dx += gravity.dx * Self.gravityStrength * dt
            bill.velocity.dy += gravity.dy * Self.gravityStrength * dt

            // Light air drag so bills flutter instead of plummeting.
            let drag = 1 - 0.6 * dt
            bill.velocity.dx *= drag
            bill.velocity.dy *= drag

            bill.position.x += bill.velocity.dx * dt
            bill.position.y += bill.velocity.dy * dt
            bill.rotation += bill.angularVelocity * dt

            if bill.position.x < sideMargin {
                bill.position.x = sideMargin
                bill.velocity.dx = abs(bill.velocity.dx) * 0.35
            } else if bill.position.x > bounds.width - sideMargin {
                bill.position.x = bounds.width - sideMargin
                bill.velocity.dx = -abs(bill.velocity.dx) * 0.35
            }

            if bill.position.y >= floorY {
                bill.position.y = floorY

                if !bill.hasBounced && bill.velocity.dy > 140 {
                    bill.hasBounced = true
                    bill.velocity.dy = -bill.velocity.dy * 0.38
                    bill.velocity.dx *= 0.7
                    bill.angularVelocity *= 0.6
                } else {
                    // Settled on the floor: it can still slide when tilted,
                    // but friction bleeds the motion away.
                    bill.velocity.dy = 0
                    bill.velocity.dx *= 1 - 3.0 * dt
                    bill.angularVelocity *= 1 - 4.0 * dt

                    if abs(bill.velocity.dx) < 25 {
                        bill.restTime += dt
                    }
                }
            }

            // Fade out gracefully once at rest, or after a long airborne life.
            if bill.restTime > 0.9 || bill.age > 8 {
                bill.opacity -= dt / 0.55
            }

            bills[index] = bill
        }

        bills.removeAll { $0.opacity <= 0 }

        if bills.isEmpty {
            stop()
        }
    }
}

/// Full-screen, touch-transparent overlay that renders the falling bills.
struct MoneyRainOverlay: View {
    @ObservedObject var simulator: MoneyRainSimulator

    var body: some View {
        GeometryReader { geo in
            Canvas { context, _ in
                for bill in simulator.bills {
                    var billContext = context
                    billContext.opacity = bill.opacity
                    billContext.translateBy(x: bill.position.x, y: bill.position.y)
                    billContext.rotate(by: .radians(bill.rotation))
                    billContext.draw(
                        Text(verbatim: "💵").font(.system(size: 34 * bill.scale)),
                        at: .zero
                    )
                }
            }
            .onAppear { simulator.updateBounds(geo.size) }
            .onChange(of: geo.size) { _, size in
                simulator.updateBounds(size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
