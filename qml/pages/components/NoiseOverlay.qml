import QtQuick 2.0

// Subtle background grain, not sure is this looks good
Image {
    property real strength: 0.06

    source: "noise.png"
    fillMode: Image.Tile
    opacity: strength
    smooth: false
    enabled: false // purely decorative, never intercepts input
}
