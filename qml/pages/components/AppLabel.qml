import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../lib" as AppLib

// Drop-in Label that follows the user's chosen app font (Settings page),
// instead of the fixed Silica theme font.

Label {

    property real sizeMultiplier: AppLib.FontManager.fontSizeMultiplier

    // Use this instead of font.bold
    property bool bold: false

    // Opt-in, not opt-out:
    property bool useCustomFont: false

    font.family: useCustomFont ? (bold ? AppLib.FontManager.activeBoldFontFamily : AppLib.FontManager.activeFontFamily) : Theme.fontFamily
    font.weight: useCustomFont ? (bold ? Font.Bold : AppLib.FontManager.activeFontWeight) : (bold ? Font.Bold : Font.Normal)
    lineHeight: useCustomFont ? AppLib.FontManager.lineHeightMultiplier : 1.0
}
