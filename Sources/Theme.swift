import SwiftUI

enum Theme: String, CaseIterable {
    case analog = "Classic Watch"
    case steampunk = "Steampunk"
    case digital = "Digital"
    case hourglass = "Hourglass"
    case flip = "Flip Clock"
    case word = "Word Clock"
    case railway = "Railway Clock"
    case water = "Water Clock"
    case zen = "Zen Garden"
    case solar = "Sundial"
    case cosmos = "Cosmic Orbit"
    case grandfather = "Grandfather Clock"
    case cuckoo = "Cuckoo Clock"
    case aurora = "Aurora"
    case binary = "Binary Clock"
    case chronograph = "Chronograph"
    case world = "World Clock"
    case candle = "Candle Clock"
    case stopwatch = "Time Trial"

    var isPro: Bool { ![Theme.analog, .steampunk, .digital, .hourglass, .flip, .word, .railway, .water, .zen, .solar].contains(self) }

    var icon: String {
        switch self {
        case .steampunk: return "gearshape.2"
        case .digital: return "waveform.path.ecg"
        case .analog: return "clock"
        case .hourglass: return "hourglass"
        case .flip: return "rectangle.split.2x1"
        case .word: return "textformat"
        case .railway: return "tram.fill"
        case .water: return "drop.fill"
        case .zen: return "circle.hexagongrid"
        case .cosmos: return "moon.stars"
        case .solar: return "sun.max"
        case .grandfather: return "clock.badge"
        case .cuckoo: return "bird.fill"
        case .aurora: return "lightspectrum.horizontal"
        case .binary: return "01.square"
        case .chronograph: return "stopwatch.fill"
        case .world: return "globe.americas.fill"
        case .candle: return "flame.fill"
        case .stopwatch: return "stopwatch.fill"
        }
    }

    var atmosphere: String {
        switch self {
        case .steampunk: return "Brass rhythm"
        case .digital: return "Neon precision"
        case .analog: return "Classic cadence"
        case .hourglass: return "Falling moments"
        case .flip: return "Tactile countdown"
        case .word: return "Time in plain words"
        case .railway: return "Platform precision"
        case .water: return "Flowing time"
        case .zen: return "Still garden"
        case .cosmos: return "Deep orbit"
        case .solar: return "Warm momentum"
        case .grandfather: return "Measured tradition"
        case .cuckoo: return "Playful precision"
        case .aurora: return "Polar glow"
        case .binary: return "Quiet code"
        case .chronograph: return "Instrument precision"
        case .world: return "Global rhythm"
        case .candle: return "A warm measure"
        case .stopwatch: return "Digital elapsed time"
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .steampunk: return .white
        case .digital, .analog, .hourglass, .flip, .word, .railway, .water: return .white
        case .zen: return .mint
        case .cosmos: return .indigo
        case .solar: return .orange
        case .grandfather: return .orange
        case .cuckoo: return .yellow
        case .aurora, .binary, .chronograph, .world, .candle: return .cyan
        case .stopwatch: return Color(red: 0.56, green: 0.78, blue: 0.68)
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .steampunk: return Color(red: 0.12, green: 0.08, blue: 0.05)
        case .digital: return Color(red: 0.02, green: 0.08, blue: 0.10)
        case .analog: return Color(red: 0.055, green: 0.07, blue: 0.10)
        case .hourglass: return Color(red: 0.12, green: 0.075, blue: 0.04)
        case .flip: return Color(red: 0.055, green: 0.055, blue: 0.065)
        case .word: return Color(red: 0.055, green: 0.06, blue: 0.085)
        case .railway: return Color(red: 0.075, green: 0.075, blue: 0.07)
        case .water: return Color(red: 0.025, green: 0.10, blue: 0.14)
        case .zen: return Color(red: 0.05, green: 0.13, blue: 0.11)
        case .cosmos: return Color(red: 0.04, green: 0.03, blue: 0.14)
        case .solar: return Color(red: 0.17, green: 0.07, blue: 0.02)
        case .grandfather: return Color(red: 0.10, green: 0.045, blue: 0.025)
        case .cuckoo: return Color(red: 0.095, green: 0.075, blue: 0.035)
        case .aurora: return Color(red: 0.03, green: 0.08, blue: 0.14)
        case .binary: return Color(red: 0.01, green: 0.075, blue: 0.06)
        case .chronograph: return Color(red: 0.035, green: 0.045, blue: 0.06)
        case .world: return Color(red: 0.025, green: 0.055, blue: 0.12)
        case .candle: return Color(red: 0.12, green: 0.045, blue: 0.025)
        case .stopwatch: return Color(red: 0.035, green: 0.065, blue: 0.06)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .steampunk: return .yellow
        case .digital: return .blue
        case .analog: return .cyan
        case .hourglass: return .orange
        case .flip: return .orange
        case .word: return .white
        case .railway: return .red
        case .water: return .cyan
        case .zen: return .mint
        case .cosmos: return .purple
        case .solar: return .yellow
        case .grandfather: return .orange
        case .cuckoo: return .yellow
        case .aurora: return .cyan
        case .binary: return .green
        case .chronograph: return .cyan
        case .world: return .blue
        case .candle: return .orange
        case .stopwatch: return Color(red: 0.48, green: 0.72, blue: 0.62)
        }
    }

    var alarmName: String {
        switch self {
        case .analog: return "Double watch chime"
        case .steampunk: return "Mechanical release"
        case .digital: return "Digital ready tone"
        case .hourglass: return "Sandglass shimmer"
        case .flip: return "Flip-card clack"
        case .word: return "Spoken completion"
        case .railway: return "Platform whistle"
        case .water: return "Water-drop cadence"
        case .zen: return "Meditation bowl"
        case .solar: return "Sunrise bell"
        case .cosmos: return "Orbital sweep"
        case .grandfather: return "Westminster-inspired chime"
        case .cuckoo: return "Cuckoo call"
        case .aurora: return "Polar shimmer"
        case .binary: return "Binary pulse"
        case .chronograph: return "Stopwatch finish"
        case .world: return "World time triad"
        case .candle: return "Crackle and fireworks"
        case .stopwatch: return "Digital completion tone"
        }
    }

    var completionMessage: String {
        switch self {
        case .analog: return "Right on time."
        case .steampunk: return "The mechanism is complete."
        case .digital: return "Session complete."
        case .hourglass: return "The final grain has fallen."
        case .flip: return "The last card has turned."
        case .word: return "Your focus time is complete."
        case .railway: return "You have arrived."
        case .water: return "The current has settled."
        case .zen: return "Return gently."
        case .solar: return "Your focus came full circle."
        case .cosmos: return "Orbit complete."
        case .grandfather: return "The hour is yours."
        case .cuckoo: return "Time to emerge."
        case .aurora: return "A bright finish."
        case .binary: return "Sequence complete."
        case .chronograph: return "Timing complete."
        case .world: return "One session, well traveled."
        case .candle: return "You kept the flame."
        case .stopwatch: return "You stayed with it."
        }
    }
}

struct ThemeBackdrop: View {
    let theme: Theme
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch theme {
                case .steampunk:
                    Image(systemName: "gearshape.2").font(.system(size: 170)).offset(x: -120, y: -270)
                    Image(systemName: "gearshape").font(.system(size: 120)).offset(x: 145, y: 310)
                case .digital:
                    VStack(spacing: 26) { ForEach(0..<18) { _ in Rectangle().frame(height: 1) } }
                    HStack(spacing: 30) { ForEach(0..<12) { _ in Rectangle().frame(width: 1) } }
                case .analog:
                    ForEach(0..<12) { index in Capsule().frame(width: 2, height: 24).offset(y: -300).rotationEffect(.degrees(Double(index) * 30)) }
                case .hourglass:
                    Image(systemName: "hourglass").font(.system(size: 300, weight: .ultraLight)).rotationEffect(.degrees(8))
                case .flip:
                    HStack(spacing: 18) { RoundedRectangle(cornerRadius: 24).frame(width: 150, height: 120); RoundedRectangle(cornerRadius: 24).frame(width: 150, height: 120) }.offset(x: 120, y: 360)
                case .word:
                    Text("TIME").font(.system(size: 210, weight: .black)).offset(x: 115, y: 340)
                case .railway:
                    Image(systemName: "tram.fill").font(.system(size: 175)).offset(x: 120, y: 470)
                case .water:
                    Image(systemName: "water.waves").font(.system(size: 260)).rotationEffect(.degrees(-12))
                case .zen:
                    VStack(spacing: 18) { ForEach(0..<9) { index in Capsule().frame(width: CGFloat(80 + index * 35), height: 2) } }
                        .rotationEffect(.degrees(-12))
                case .cosmos:
                    ForEach(0..<24) { index in
                        Image(systemName: index % 6 == 0 ? "sparkle" : "circle.fill")
                            .font(.system(size: index % 6 == 0 ? 14 : 3))
                            .position(x: CGFloat((index * 83) % max(1, Int(proxy.size.width))), y: CGFloat((index * 137) % max(1, Int(proxy.size.height))))
                    }
                case .solar:
                    Circle().fill(RadialGradient(colors: [.yellow.opacity(0.7), .orange.opacity(0.15), .clear], center: .center, startRadius: 5, endRadius: 220)).frame(width: 440).offset(y: -300)
                case .grandfather:
                    Capsule().stroke(lineWidth: 3).frame(width: 180, height: 720).offset(x: 145, y: 200)
                    Circle().fill().frame(width: 75).offset(x: 145, y: 310)
                case .cuckoo:
                    ForEach(0..<10) { index in Image(systemName: index.isMultiple(of: 2) ? "bird.fill" : "tree.fill").font(.system(size: 28)).position(x: CGFloat((index * 97) % max(1, Int(proxy.size.width))), y: CGFloat((index * 181) % max(1, Int(proxy.size.height)))) }
                case .aurora:
                    LinearGradient(colors: [.cyan, .mint, .purple, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .blur(radius: 70).rotationEffect(.degrees(-18)).scaleEffect(1.4)
                case .binary:
                    Text("0101 1010 0011 1100").font(.system(size: 50, weight: .black, design: .monospaced)).multilineTextAlignment(.center)
                case .chronograph:
                    Image(systemName: "stopwatch").font(.system(size: 340, weight: .ultraLight)).rotationEffect(.degrees(10))
                case .world:
                    Image(systemName: "globe.americas.fill").font(.system(size: 360)).offset(x: 120, y: 240)
                case .candle:
                    Image(systemName: "flame.fill").font(.system(size: 210)).offset(x: -135, y: 460)
                case .stopwatch:
                    RoundedRectangle(cornerRadius: 36).stroke(lineWidth: 3).frame(width: 310, height: 190)
                        .overlay(Image(systemName: "stopwatch.fill").font(.system(size: 90, weight: .ultraLight)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .foregroundStyle(theme.accentColor)
            .opacity(0.035)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
